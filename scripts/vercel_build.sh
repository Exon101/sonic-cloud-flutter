#!/usr/bin/env bash
set -euo pipefail

echo "▶ Sonic Cloud — Vercel build starting"

# Install Flutter if not available
if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK…"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version

# Install dependencies
flutter pub get

# Build web app
flutter build web --release

echo "▶ Vercel build complete: build/web"
ls -la build/web | head -10
