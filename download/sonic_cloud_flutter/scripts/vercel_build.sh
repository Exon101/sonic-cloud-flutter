#!/usr/bin/env bash
# Vercel build script — installs Flutter, builds the web bundle, and leaves
# the output at build/web.
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

# ── Strip ONLY the deprecated service worker (NOT flutter.js) ────────────────
# flutter_service_worker.js is deprecated (flutter/flutter#156910) but
# flutter.js is REQUIRED — it's the Flutter web framework loader that
# main.dart.js depends on. Without it, the app hangs on the loading screen.
echo "▶ Stripping deprecated service worker (keeping flutter.js)"
rm -f build/web/flutter_service_worker.js
# DO NOT delete flutter.js — it's needed for _flutter.loader.loadEntrypoint()

# ── Fix index.html: replace SW registration with proper Flutter init ────────
# Flutter's build injects a script block that registers the service worker.
# We replace it with the modern _flutter.loader.loadEntrypoint() pattern
# that doesn't use a service worker but still properly initializes Flutter.
python3 - <<'PY'
import re
from pathlib import Path

idx = Path('build/web/index.html')
if not idx.exists():
    print(f"  WARN: {idx} not found — skipping")
    raise SystemExit(0)

html = idx.read_text()

# Match the SW registration block Flutter injects:
#   <script>
#     const serviceWorkerVersion = "..." /* ... */;
#     var scriptLoaded = false;
#     function loadMainDartJs() { ... }
#     if ('serviceWorker' in navigator) { ... } else { loadMainDartJs(); }
#   </script>
pattern = re.compile(
    r'<script>\s*'
    r'const serviceWorkerVersion.*?'
    r'loadMainDartJs\(\);\s*\}\s*</script>',
    re.DOTALL,
)

# Modern Flutter web initialization — uses _flutter.loader.loadEntrypoint()
# which is provided by flutter.js. This is the standard pattern from
# Flutter 3.x+ that doesn't require a service worker.
replacement = (
    '<script>\n'
    '    window.addEventListener(\'load\', function () {\n'
    '      _flutter.loader.loadEntrypoint({\n'
    '        onEntrypointLoaded: async function(engineInitializer) {\n'
    '          let appRunner = await engineInitializer.initializeEngine();\n'
    '          await appRunner.runApp();\n'
    '        }\n'
    '      });\n'
    '    });\n'
    '  </script>'
)

new_html, n = pattern.subn(replacement, html)
if n > 0:
    idx.write_text(new_html)
    print(f"  Replaced SW block with modern Flutter init ({n} match)")
else:
    # Check if the block is already the modern pattern
    if '_flutter.loader.loadEntrypoint' in html:
        print(f"  index.html already uses modern Flutter init (no change needed)")
    else:
        print(f"  WARNING: No SW block found and no modern init — Flutter may not load")
        # Inject a fallback: load flutter.js + init
        if 'flutter.js' not in html:
            html = html.replace('</head>', '  <script src="flutter.js" defer></script>\n</head>')
        if '_flutter.loader' not in html:
            fallback = (
                '\n  <script>\n'
                '    window.addEventListener(\'load\', function () {\n'
                '      _flutter.loader.loadEntrypoint({\n'
                '        onEntrypointLoaded: async function(engineInitializer) {\n'
                '          let appRunner = await engineInitializer.initializeEngine();\n'
                '          await appRunner.runApp();\n'
                '        }\n'
                '      });\n'
                '    });\n'
                '  </script>\n'
            )
            html = html.replace('</body>', f'{fallback}</body>')
            idx.write_text(html)
            print(f"  Injected flutter.js + modern init as fallback")

# ── Enforce full-screen CSS ──────────────────────────────────────────────────
html = idx.read_text()
fullscreen_css = """
    <style id="fullscreen-reset">
    html, body { margin:0 !important; padding:0 !important; width:100% !important; height:100% !important; overflow:hidden !important; overscroll-behavior:none !important; }
    flt-glass-pane, #flt-element { width:100vw !important; height:100vh !important; }
    </style>
"""
if 'fullscreen-reset' not in html:
    html = html.replace('</head>', f'{fullscreen_css}</head>')
    idx.write_text(html)
    print("  Injected full-screen CSS reset")
else:
    print("  Full-screen CSS already present")

# ── Verify flutter.js exists ─────────────────────────────────────────────────
flutter_js = Path('build/web/flutter.js')
if flutter_js.exists():
    print(f"  ✓ flutter.js exists ({flutter_js.stat().st_size} bytes)")
else:
    print(f"  ✗ WARNING: flutter.js NOT FOUND — app will hang on loading screen!")
PY

echo "▶ Vercel build complete: build/web"
ls -la build/web | head -20
