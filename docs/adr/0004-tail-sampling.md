# ADR-0004: Tail-Sampling at the Collector, Not Head-Sampling at the SDK

- **Status**: Accepted
- **Context**: trace volume / cost / signal trade-off

## Context

Distributed tracing at scale is expensive. A naive setup ("trace everything, ship to Tempo") quickly hits one of:

- Collector backpressure
- Backend storage costs > observability budget
- Network egress costs from the cluster

Two sampling strategies exist:

1. **Head-sampling (at SDK)**: decide at trace-start whether to record. Common ratio: 10%.
2. **Tail-sampling (at collector)**: record everything, decide at trace-end based on the *whole trace shape*.

## Decision

Use **tail-sampling at the OTel Collector**, not head-sampling at the SDK.

Sampling rules (in priority order):

1. **Always keep** traces with any `error=true` span — every error trace, full fidelity
2. **Always keep** traces where total latency > P99 baseline (configurable per service) — every slow trace
3. **Probability-sample** the rest — typically 5–10% of "boring success" traces

Implementation: OTel Collector `tail_sampling` processor. Reference config:

```yaml
processors:
  tail_sampling:
    decision_wait: 30s
    num_traces: 50000
    expected_new_traces_per_sec: 1000
    policies:
      - name: errors-policy
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow-policy
        type: latency
        latency: { threshold_ms: 2000 }
      - name: probabilistic-policy
        type: probabilistic
        probabilistic: { sampling_percentage: 5 }
```

## Why tail, not head

Head-sampling decides at span-start. The decision is therefore made *without* knowing:
- Whether this trace will end in error
- Whether the trace will be slow
- Whether anything interesting happened downstream

Result: head-sampling is biased toward "boring success" traces. The traces you most need (errors, slow) are sampled at the same rate as the rest, which means at 10% sampling you lose 90% of error signal.

Tail-sampling reverses this: keep 100% of error/slow, sample only the boring rest.

## Trade-offs

### Costs of tail-sampling

- **Memory**: collector buffers spans for `decision_wait` (30s) before deciding. Sized as `num_traces × avg_spans_per_trace × avg_span_size`. Plan for ~1–2 GB collector memory at typical scale.
- **Latency to backend**: traces appear in Tempo ~30s after completion (acceptable for debugging; not for live ops dashboards which use metrics).
- **Decision-wait drift**: if a service's traces span > `decision_wait`, sampling decision is incomplete. Either raise the wait, or accept that very-long traces always sample.

### Benefits

- Signal-to-noise on error investigation goes from ~10x worse than ideal to ideal
- Total trace volume drops substantially (specific reduction varies — in cuckoo-echo's local Compose run with bursty test traffic, observed ~70% volume drop without losing any error/slow trace)
- Cost-per-error-debugged drops

## Anti-patterns to avoid

- **Tail-sampling at the SDK** (some libraries support it via "buffer at exporter") — defeats purpose; SDK doesn't see other services' spans, so "error somewhere in trace" can't be detected.
- **Aggressive tail thresholds** that skip slow non-error traces — these are exactly the traces useful for performance regression investigation.
- **No per-service overrides** — the right "slow trace" threshold for `auth-service` (50ms p99) is wrong for `report-export-service` (5s p99). Configure per service via attribute matching.
- **Tail-sampling without a metrics fallback** — sampling decisions can be wrong. Always retain 100% metrics (counters, histograms) so SLO calculations are based on full traffic, not sample.

## Consequences

### Required investments

- An OTel Collector deployment topology that can hold 30s of trace buffer (sidecar isn't sufficient; needs deployment-tier collectors)
- Per-service threshold tuning for the latency-policy (start with a baseline P99, iterate)
- Monitoring of the collector itself (collector dropping spans is invisible from the application side)

### What you get

- Trace storage stays bounded
- Every error and every slow trace is in storage at full fidelity
- Investigation flow: error metric fires → click in Grafana → land in Tempo with the actual trace

## Validation

- After enabling, query Tempo for "traces with status=error" — should match Prometheus error counter, not be sampled-down.
- Inject a synthetic error in a low-traffic test and verify the trace lands in storage.
- Inject a synthetic latency injection and verify the trace lands in storage.

## Related

- [ADR-0001](0001-otel-everywhere.md) — establishes the OTLP → Collector → Backend pipeline that makes this possible
- [ADR-0003](0003-alert-layering.md) — alerts use Prometheus metrics (always 100%), not tail-sampled trace counts
