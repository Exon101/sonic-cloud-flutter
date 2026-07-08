#!/usr/bin/env bash
# Vercel build script — installs Flutter, builds the web bundle, strips the
# deprecated service worker, and leaves the output at build/web.
#
# Vercel runs this from the project's rootDirectory (set to
# download/sonic_cloud_flutter/ in the Vercel project settings).

set -euo pipefail

echo "▶ Vercel build starting"

# ── Install Flutter ─────────────────────────────────────────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK…"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version

# ── Build ────────────────────────────────────────────────────────────────────
flutter pub get
flutter build web --release --no-pwa || flutter build web --release

# ── Strip the deprecated service worker (Flutter regenerates it at build ─────
# time even if removed from web/index.html — see flutter/flutter#156910).
echo "▶ Stripping deprecated service worker from build output"
rm -f build/web/flutter_service_worker.js
rm -f build/web/flutter.js

# Remove the SW registration block from the built index.html. Flutter injects
# this block during build; we use a Python one-liner so we don't depend on
# sed dialect differences across CI environments.
python3 - <<'PY'
import re
from pathlib import Path

idx = Path('build/web/index.html')
if not idx.exists():
    print(f"  WARN: {idx} not found — skipping SW strip")
    raise SystemExit(0)

html = idx.read_text()
# Match the SW registration block Flutter injects:
#   <script>
#     const serviceWorkerVersion = "..." /* ... */;
#     var scriptLoaded = false;
#     function loadMainDartJs() { ... }
#     if ('serviceWorker' in navigator) { ... } else { loadMainDartJs(); }
#   </script>
# Replace with a minimal block that just loads main.dart.js on load.
pattern = re.compile(
    r'<script>\s*'
    r'const serviceWorkerVersion.*?'
    r'loadMainDartJs\(\);\s*\}\s*</script>',
    re.DOTALL,
)
replacement = (
    '<script>\n'
    '    var scriptLoaded = false;\n'
    '    function loadMainDartJs() {\n'
    '      if (scriptLoaded) { return; }\n'
    '      scriptLoaded = true;\n'
    '      var s = document.createElement("script");\n'
    '      s.src = "main.dart.js";\n'
    '      s.type = "application/javascript";\n'
    '      document.body.append(s);\n'
    '    }\n'
    '    window.addEventListener("load", loadMainDartJs);\n'
    '  </script>'
)
new_html, n = pattern.subn(replacement, html)
if n > 0:
    idx.write_text(new_html)
    print(f"  Stripped SW block from build/web/index.html ({n} match)")
else:
    print(f"  No SW block found in build/web/index.html (already clean)")

# ── Enforce full-screen CSS ──────────────────────────────────────────────────
# Flutter's build process may strip or override the margin:0 on <body>. This
# step ensures the full-screen reset is always present in the built output.
html = idx.read_text()
fullscreen_css = """
    <style id="fullscreen-reset">
    html, body { margin:0 !important; padding:0 !important; width:100% !important; height:100% !important; overflow:hidden !important; overscroll-behavior:none !important; }
    flt-glass-pane, #flt-element { width:100vw !important; height:100vh !important; }
    </style>
"""
if 'fullscreen-reset' not in html:
    # Inject right before </head>
    html = html.replace('</head>', f'{fullscreen_css}</head>')
    idx.write_text(html)
    print("  Injected full-screen CSS reset into build/web/index.html")
else:
    print("  Full-screen CSS reset already present")
PY

echo "▶ Vercel build complete: build/web"
ls -la build/web | head -20
