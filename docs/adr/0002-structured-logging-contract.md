# ADR-0002: JSON-Only Logs with Sensitive-Data Masking and Required trace_id

- **Status**: Accepted
- **Context**: logging contract for all services

## Context

Logs are the cheapest pillar of observability — every service emits them. But "we have logs" is not the same as "we have a queryable log dataset." Three failure modes:

1. **Free-form text logs** — `print("user 12345 paid 199")` is unparseable in aggregate
2. **No trace correlation** — logs and traces are two separate worlds, debugging requires manual correlation
3. **PII / secrets in logs** — silent compliance time-bomb

## Decision

Every service must log via a structured-logging library (`structlog` for Python, logback-encoder for Java, `slog` for Go ≥1.21) and conform to the following contract:

### 1. JSON-only output

No "human-friendly" formatter in non-dev environments. If a developer can't read JSON in dev, install a `jq` formatter on stdout — don't change the production log shape.

### 2. Required fields

Every log line MUST include:
- `timestamp` — ISO-8601 with timezone, milliseconds
- `level` — `debug` / `info` / `warning` / `error`
- `service` — service name (bound at app startup)
- `trace_id` — current OTel trace id, or `null` if not in a traced context
- `message` — short event name; structured fields go in additional keys

### 3. Field naming convention

- snake_case (cross-language consistent)
- Numerics as numbers, not strings
- Identifiers as strings even if numeric (`user_id: "12345"` not `user_id: 12345`)
- Durations in `_ms` (milliseconds), not `_s` or `_ns`

### 4. Sensitive-data masking

A list of regex patterns automatically redacts:
- email addresses → `<email_redacted>`
- credit-card numbers → `<cc_redacted>`
- bearer tokens / API keys → `<token_redacted>`
- specific field names always masked: `password`, `secret`, `token`, `api_key`, `ssn`, `phone`

Reference impl in `cuckoo-echo`'s `shared/logging.py:mask_sensitive()`.

### 5. No `print()`, no naked `logging.getLogger()`

Pre-commit hook + CI lint rule forbid:
- `print(...)` in any non-script production code
- `import logging; logger = logging.getLogger(...)` — must use the structlog wrapper

## Why this works

- **Logs become a queryable dataset** — Loki / Elasticsearch / Cloud Logging can filter by structured field, not regex grep
- **Trace ↔ log correlation is automatic** — click a span in Tempo, get all logs for that trace
- **PII is masked at write time, not query time** — no compliance review of "did we accidentally log a credit card"
- **Cross-language uniformity** — same field names across Go / Java / Python services, so dashboards work everywhere

## Consequences

### Required investments

- A `setup_logging(level, service_name)` factory per language, called at app startup
- A masking rule list maintained centrally (per regulation as needed)
- A linter / pre-commit rule per language to enforce no-print
- Education for new contributors: "structured logs aren't optional"

### What you get

- Logs become first-class observability data, not afterthought
- Compliance posture improves passively
- Incident response gets faster — log + trace + metric all carry the same correlation id

## Anti-patterns to avoid

- **String-formatted structured logs**: `logger.info(f"user {user_id} did X")` defeats the entire point. Use kwargs: `logger.info("user_action", user_id=user_id, action="X")`.
- **Logging the entire request object**: it's tempting and convenient; it's also how secrets leak. Log specific fields you actually need.
- **DEBUG level in production**: the contract is the same regardless of level, but high-volume DEBUG logs at production rate cost money. Default INFO; gate DEBUG behind a flag.

## Validation

- `grep -E "^[^#]*print\(" -r app/` returns zero matches.
- A random log line, parsed as JSON, passes a JSON-schema validation against the required-fields list.
- A request with a `traceparent` header produces logs whose `trace_id` matches the header's trace ID.
- Synthetic input containing an email / token produces a log with masked output.

## Related

- [ADR-0001](0001-otel-everywhere.md) — where trace_id comes from
- [ADR-0003](0003-alert-layering.md) — log-based alerts (rare, but needed for some "failure to log" anti-symptoms)
