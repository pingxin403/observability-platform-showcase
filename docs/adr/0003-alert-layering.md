# ADR-0003: Three-Tier Alert Layering — Symptom / Cause / Saturation

- **Status**: Accepted
- **Context**: alerting strategy across services

## Context

Two common alerting failure modes:

1. **Alert fatigue** — every metric has an alert; on-call drowns; real signals get muted
2. **Symptom-only blindness** — only customer-visible symptoms alert; root cause hides in dashboards nobody looks at during 3am incidents

Both extremes fail. The fix is a **layered model** where each layer has a clear purpose and severity.

## Decision

Three alert tiers, each with a specific consumer and a specific routing:

### Tier 1: Symptoms (page-worthy)

What the customer experiences. Severity: `critical`. Pages on-call.

- HTTP 5xx rate > threshold
- P95/P99 latency > SLO
- Synthetic transaction (smoke test) failing
- Error-budget burn-rate (multi-window) above critical threshold

Routing: PagerDuty / OpsGenie. Designed to wake someone at 3am.

### Tier 2: Causes (warning, office-hours)

Why a symptom *might* be about to fire. Severity: `warning`. Goes to a Slack channel watched during office hours.

- Database connection pool > 80% saturated
- Kafka consumer lag growing
- Cache hit-rate dropping below baseline
- Disk usage > 75%
- Specific dependency's circuit breaker open

Routing: Slack channel. NOT a page. The point is "you have time to fix this before it becomes a Tier 1."

### Tier 3: Saturation / capacity (informational)

Slow-growing trends. Severity: `info`. Ticketed weekly, not pinged.

- Active connections at 60% of cluster capacity (will hit 80% in 2 weeks at current growth)
- Storage usage growing 5%/week — will hit 80% in N weeks
- DB index size approaching plan threshold

Routing: Jira / Linear ticket auto-creation. Triaged in capacity planning meetings.

## Why three tiers, not two

A binary "page / don't page" misses the middle case where a real issue *should* be noticed but doesn't warrant a wake-up. Without Tier 2, ops engineers either:
- Get paged for everything → fatigue
- Page only on symptoms → root-causes get found at incident time, not before

Tier 2 is the workspace for proactive operations.

## Burn-rate alerting (a specific Tier 1 pattern)

For SLO-bound services, the most useful Tier 1 alert is **multi-window burn rate**, not a fixed-threshold error rate.

A single threshold ("alert if 5xx > 1% for 5 min") is tuned wrong by definition: too tight = noise, too loose = miss long slow burns.

A multi-window burn-rate alert fires when:

- Short window (e.g. 5m) shows fast burn AND
- Medium window (e.g. 1h) shows sustained burn

This catches both "sudden spike" and "slow drip" with one rule. Implementation: see Google's SRE Workbook chapter on alerting on SLOs, or the sample in [`docs/samples/alert-rules.yml`](../samples/alert-rules.yml).

## Anti-patterns to avoid

- **Tier 1 with > 30 alerts** — you have alerts that aren't really tier-1. Demote.
- **Tier 2 with no rotation** — if the warning channel is muted, it's effectively no alert at all.
- **Per-host alerts** — alert on the service's symptom, not on a specific instance. "Pod X has high CPU" is a Tier 3 capacity note; "service Y has high latency" is a Tier 1 symptom.
- **Alerts without runbooks** — every Tier 1 alert needs a `runbook_url` annotation pointing at a documented response procedure. If you can't write the runbook, the alert is too vague.

## Consequences

- Ops on-call rotation gets a manageable Tier 1 alert load (target: < 2 pages/week)
- A Slack channel exists for "things going wrong slowly" that ops engineers actually watch
- Capacity is planned in advance, not discovered at outage time

## Validation

- Random sample of 10 production incidents in the last quarter: did Tier 1 fire? Was Tier 2 firing already? Was the gap between Tier 2 firing and Tier 1 firing big enough to act?
- Alert volume audit: total Tier 1 / Tier 2 / Tier 3 firings per week. Trend over time. If Tier 1 is rising, alerts are misclassified.

## Related

- [ADR-0001](0001-otel-everywhere.md) — where the metrics come from
- Sample rules: [`alert-rules.yml`](../samples/alert-rules.yml)
