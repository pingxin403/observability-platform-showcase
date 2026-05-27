# ADR-0001: OpenTelemetry SDK in Every Service, Not Vendor SDKs

- **Status**: Accepted
- **Context**: instrumentation choice for distributed tracing, metrics, and (eventually) logs

## Context

Three viable instrumentation strategies:

1. **Vendor-specific SDK per service** (Datadog APM, New Relic agent, Lightstep client)
2. **OpenTelemetry SDK in services + OTel Collector as middleware**
3. **No instrumentation, debug from logs** (don't laugh — many small projects live here)

Vendor SDKs are easiest day-1 but bake the vendor into application code. Switching costs grow with every new service.

## Decision

Instrument every service with the **OpenTelemetry SDK** (Python: `opentelemetry-instrumentation-fastapi` etc.; Java: `opentelemetry-javaagent.jar` for auto-instrumentation; Go: `go.opentelemetry.io/otel`).

Services emit OTLP (OpenTelemetry protocol) to a local collector sidecar / DaemonSet. The collector handles:
- Sampling decisions (see [ADR-0004](0004-tail-sampling.md))
- Routing to backends (Tempo for traces, Prometheus for metrics, Loki for logs)
- Batching and retry on backend failure

```
service ── OTLP ──> OTel Collector ──┬──> Tempo / Jaeger    (traces)
                                     ├──> Prometheus        (metrics)
                                     └──> Loki              (logs)
```

## Why OTel + Collector, not vendor SDKs

- **Vendor freedom**: switch backends by updating collector config, not application code
- **Cross-language consistency**: the same trace semantics across Go / Java / Python / TS, important for tracing across language boundaries (Java service → Go service over gRPC)
- **Sampling at the right tier**: SDK-tier sampling forces premature decisions (more in ADR-0004)
- **Free auto-instrumentation**: HTTP, gRPC, DB clients, Kafka — all auto-instrumented by upstream OTel libraries
- **Open standard**: schema (`HTTP_REQUEST_METHOD`, `RPC_GRPC_STATUS_CODE` etc.) lets dashboards work across services without per-service mapping

## Consequences

### Required investments

- A collector deployment topology decision: sidecar (per pod), DaemonSet (per node), or central deployment. Default: DaemonSet for the common case.
- Service developers must understand `tracer.start_as_current_span(...)` for hand-instrumented spans (most spans should be auto-instrumented; manual is for business operations like "checkout flow")
- Every service must propagate W3C `traceparent` header — auto for HTTP/gRPC, manual for Kafka (set as message header)

### What you get

- Cross-service flame graphs out of the box
- Free distributed tracing for every HTTP / gRPC / DB call
- Vendor migration is a Helm upgrade, not a project

### Edge cases handled

- **Async work** (Kafka consumer, scheduled jobs): explicitly extract `traceparent` from message header / scheduler context, otherwise spans become orphans
- **Background workers** that fan out to many traces: use a "linked span" pattern (`SpanLink`) instead of trying to attribute every fan-out to one trace
- **Sensitive data in span attributes**: scrub at the collector (processor pipeline), not in app code, so the rule lives in one place

## Anti-patterns to avoid

- **Mixing vendor SDK and OTel SDK in the same service** — sampling decisions conflict, traces split. Pick one per service.
- **OTel SDK without a Collector** — works but loses sampling-at-tier benefit and burdens app code with retry logic.
- **Hand-instrumenting things auto-instrumentation already covers** — wastes dev time and risks duplicate spans.

## Validation

- A request that traverses 3 services should produce 1 trace with N child spans, not N traces.
- Killing the trace backend should not crash apps (collector buffers, app keeps working).
- Switching backends (Tempo → Jaeger) should require zero application redeploys.

## Related

- [ADR-0002](0002-structured-logging-contract.md) — log lines must carry the same trace_id for cross-pillar correlation
- [ADR-0004](0004-tail-sampling.md) — what the collector does with traces before they reach storage
