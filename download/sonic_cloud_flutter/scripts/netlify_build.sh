#!/usr/bin/env bash
# Netlify build script — installs Flutter SDK, builds the web bundle.
#
# Netlify runs this from the project root. Output: build/web (matches the
# `publish` setting in netlify.toml).

set -euo pipefail

echo "▶ Netlify build starting"

# ── Install Flutter if not already cached ────────────────────────────────────
FLUTTER_DIR="/opt/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter stable…"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version

# ── Build ────────────────────────────────────────────────────────────────────
flutter pub get
flutter build web --release --web-renderer canvaski

echo "▶ Netlify build complete: build/web"
ls -la build/web | head -20
