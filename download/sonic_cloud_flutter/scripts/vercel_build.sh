#!/usr/bin/env bash
# Vercel build script — installs Flutter, builds the web bundle.
set -euo pipefail

echo "▶ Vercel build starting"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK…"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version
flutter pub get
# Use --no-wasm to force dart2js (CanvasKit) instead of dart2wasm.
# dart2wasm has rendering issues on some Vercel deployments.
flutter build web --release --no-pwa --no-wasm

# Strip ONLY the deprecated service worker file (NOT flutter.js!)
echo "▶ Stripping deprecated service worker"
rm -f build/web/flutter_service_worker.js

# Ensure full-screen CSS is present
python3 - <<'PY'
from pathlib import Path
idx = Path('build/web/index.html')
if not idx.exists():
    raise SystemExit(0)
html = idx.read_text()
css = '<style id="fullscreen-reset">html,body{margin:0!important;padding:0!important;width:100%!important;height:100%!important;overflow:hidden!important;overscroll-behavior:none!important;}flt-glass-pane,#flt-element{width:100vw!important;height:100vh!important;}</style>'
if 'fullscreen-reset' not in html:
    html = html.replace('</head>', f'{css}</head>')
    idx.write_text(html)
    print("  Injected full-screen CSS")
else:
    print("  Full-screen CSS already present")

# Verify flutter.js exists
if Path('build/web/flutter.js').exists():
    print("  ✓ flutter.js exists")
else:
    print("  ✗ WARNING: flutter.js NOT FOUND!")
PY

echo "▶ Build complete"
ls build/web | head -20
