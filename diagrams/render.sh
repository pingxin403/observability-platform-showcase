#!/usr/bin/env bash
# render.sh — re-render all .mmd diagrams to PNG and SVG.
#
# Requires: @mermaid-js/mermaid-cli (install with `pnpm i -g` or `npm i -g`).
# On macOS, the script falls back to system Chrome if puppeteer's bundled
# Chromium is not installed.
set -euo pipefail

cd "$(dirname "$0")"

# macOS: prefer system Chrome to skip puppeteer's chromium download
if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]] && [[ "$OSTYPE" == "darwin"* ]]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  if [[ -x "$CHROME" ]]; then
    export PUPPETEER_EXECUTABLE_PATH="$CHROME"
  fi
fi

if ! command -v mmdc >/dev/null 2>&1; then
  echo "✗ mmdc not found. Install with:"
  echo "    pnpm install -g @mermaid-js/mermaid-cli"
  echo "    npm install -g @mermaid-js/mermaid-cli"
  exit 1
fi

for src in *.mmd; do
  base="${src%.mmd}"
  echo "→ rendering $base"
  mmdc -i "$src" -o "${base}.png" -b white -w 1600
  mmdc -i "$src" -o "${base}.svg" -b transparent
done

echo
echo "✓ done. Outputs:"
ls -lh ./*.png ./*.svg
