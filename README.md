# observability-platform-showcase

> Public docs-only mirror of observability practices applied across my microservice projects.
> 微服务可观测性实践的公开文档橱窗。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Source: across multiple repos — by invitation](https://img.shields.io/badge/source-across%20repos%20%E2%80%94%20by%20invitation-lightgrey)](#source-access--%E6%BA%90%E7%A0%81%E8%AE%BF%E9%97%AE)

---

## What this repo is / 这是什么

This repository is a **documentation showcase** of how I instrument, alert on, and operate microservice observability — covering metrics, logs, traces, and the operational glue that makes the three pillars actually useful in practice.

It contains:
- ADRs for non-obvious choices (tail-sampling, alert layering, structured-logging contracts, SLO formalization)
- Sanitized sample alert rules (Prometheus)
- A reading order for evaluators

It does **not** contain production dashboards, real alert thresholds tuned to a specific tenant, or company-internal runbooks. Those live in private repos (sample exists in `cuckoo-echo`'s private repo) and are shared on request.

本仓库是我在微服务项目里的**可观测性实践**的公开文档橱窗，包含 ADR、示例告警规则与阅读顺序。**不含生产 dashboard / 调过的真实阈值 / 内部 runbook**——这些位于私库（如 cuckoo-echo），按需开放。

---

## Companion showcases / 配套橱窗

This is one corner of a three-repo showcase triangle covering my main practice areas:

- [**cuckoo-echo-showcase**](https://github.com/pingxin403/cuckoo-echo-showcase) — multi-tenant AI customer-service SaaS architecture
- [**cicd-platform-showcase**](https://github.com/pingxin403/cicd-platform-showcase) — CI/CD & release governance (this showcase's SLO definitions feed cicd-platform-showcase's canary gating in ADR-0004)
- **You are here** — observability platform (this repo)

All three are docs-only and intentionally cross-reference where decisions span domains.

---

## Project context / 项目背景

This showcase aggregates practices from:

- **cuckoo-echo** (private) — multi-tenant AI customer-service platform, where the full Langfuse + Prometheus + OpenTelemetry + ELK stack was wired up and 15 production runbooks were written
- **[cuckoo](https://github.com/pingxin403/cuckoo)** (public) — polyglot monorepo, where the same patterns are applied at smaller scale and visible in source

Together they cover: OTel SDK instrumentation, Prometheus + Grafana metrics, Loki log aggregation, Jaeger / Tempo distributed tracing, structured logging contracts, multi-window burn-rate SLO alerting, and tail-sampling for cost control.

---

## Capability map / 实践覆盖

| Pillar | Practice | Status here |
|---|---|---|
| Metrics | Prometheus + Grafana — RED + USE + custom SLO metrics | [ADR-0003](docs/adr/0003-alert-layering.md), sample [`alert-rules.yml`](docs/samples/alert-rules.yml) |
| Logs | Structured (JSON) via structlog / logback-encoder; sensitive-data masking | [ADR-0002](docs/adr/0002-structured-logging-contract.md) |
| Traces | OTel SDK → OTel Collector → Tempo / Jaeger; trace-id propagation across HTTP, gRPC, async (Kafka) | [ADR-0001](docs/adr/0001-otel-everywhere.md) |
| Sampling | Tail-sampling at collector tier — keep error spans, sample success spans | [ADR-0004](docs/adr/0004-tail-sampling.md) |
| Alerting | Multi-window burn-rate (30m/6h/3d) + per-tier symptoms (api / data / queue) | ADR-0003 |
| SLO | Explicit SLI definition per service + error-budget tracking + budget-driven release gates | covered in ADR-0003 |

---

## Architecture decisions / 架构决策

| ID | Decision | Why it matters |
|---|---|---|
| [ADR-0001](docs/adr/0001-otel-everywhere.md) | **OTel SDK in all services**, not vendor SDKs | Avoids lock-in; enables sampling decisions to live at the collector tier |
| [ADR-0002](docs/adr/0002-structured-logging-contract.md) | **JSON-only logs, masked sensitive fields, trace-id required** | Logs become a queryable dataset, not a stream of strings |
| [ADR-0003](docs/adr/0003-alert-layering.md) | **Three-tier alert layering: symptom / cause / saturation** | Avoids "alert fatigue" while keeping diagnostics in reach |
| [ADR-0004](docs/adr/0004-tail-sampling.md) | **Tail-sampling at collector**, not head-sampling at SDK | Keeps 100% of error/slow traces while cutting volume ~70% |

---

## Sample artefacts / 示例资源

- [`docs/samples/alert-rules.yml`](docs/samples/alert-rules.yml) — Prometheus alert rules (multi-window burn-rate + per-tier symptoms)
- More samples (Grafana dashboard JSON, OTel Collector config) live in private repos and are shared on request

---

## Suggested reading order / 建议阅读顺序

For a 10-minute walkthrough:

1. [`docs/adr/0001-otel-everywhere.md`](docs/adr/0001-otel-everywhere.md) — instrumentation foundation
2. [`docs/adr/0003-alert-layering.md`](docs/adr/0003-alert-layering.md) — alert philosophy (the most underrated piece of observability)
3. [`docs/samples/alert-rules.yml`](docs/samples/alert-rules.yml) — the philosophy as code
4. [`docs/adr/0004-tail-sampling.md`](docs/adr/0004-tail-sampling.md) — cost control without losing signal
5. [`docs/adr/0002-structured-logging-contract.md`](docs/adr/0002-structured-logging-contract.md) — the data contract that makes logs useful

---

## Source access / 源码访问

Real implementations live in:

- **[cuckoo](https://github.com/pingxin403/cuckoo)** — public — `monitoring/` directory, `apps/*/observability/` per service
- **cuckoo-echo** (private) — `monitoring/` (Prometheus / Loki / Tempo configs), `monitoring/dashboards/` (Grafana JSON), `shared/logging.py` (structlog setup), `shared/tracing.py` (OTel init), 15 runbooks under `docs/runbooks/`

If you are evaluating this body of work, open an issue here or reach me directly. I'll grant time-boxed read access to the relevant private repo.

---

## Disclaimer / 免责声明

- **Single-author body of work.** Patterns described come from real implementations; no claim of "operated by a 24/7 SRE rotation across multiple regions for years."
- **No production thresholds shared verbatim.** The sample `alert-rules.yml` uses indicative thresholds (5% error rate, 5s P95). Real systems require thresholds tuned to that system's traffic pattern and SLOs — apply ADR-0003's framework, not the literal numbers.
- **Cost claims** (e.g. "tail-sampling reduces volume ~70%") come from a specific dataset in cuckoo-echo's local Docker Compose run; real reductions vary by traffic shape.

---

## License

[MIT](LICENSE) — applies to documentation in this showcase repository.

<!-- TODO: add a "from-zero-to-instrumented" walkthrough once a fresh greenfield service is onboarded -->
<!-- TODO: link companion cicd-platform-showcase once cross-references are warranted -->
