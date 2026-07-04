#!/usr/bin/env bash
# Vercel build script — installs Flutter, builds the web bundle, and leaves
# the output at build/web (Vercel's `outputDirectory`).
#
# Vercel runs this script from the project root. We assume `vercel.json`
# `outputDirectory: build/web` and `buildCommand: ./scripts/vercel_build.sh`.

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
flutter build web --release --web-renderer canvaski

echo "▶ Vercel build complete: build/web"
ls -la build/web | head -20
