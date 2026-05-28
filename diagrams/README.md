# Diagrams

Standalone diagram for this observability showcase. Mermaid source + 1600px PNG + transparent SVG.

| File | Topic |
|---|---|
| `observability-pipeline` | OTel SDK → Collector (tail-sampling) → Prometheus / Tempo / Loki → three-tier alerting |

Cross-shared with [`cuckoo-echo-showcase`'s diagram-04](https://github.com/pingxin403/cuckoo-echo-showcase/blob/main/diagrams/04-observability-pipeline.png) — keep them in sync if either source `.mmd` is edited.

## Re-render

```bash
./render.sh   # requires @mermaid-js/mermaid-cli (pnpm i -g, npm i -g)
```

On macOS the script auto-falls-back to system Chrome to skip puppeteer's chromium download. Set `PUPPETEER_EXECUTABLE_PATH` manually if the auto-detection misses.
