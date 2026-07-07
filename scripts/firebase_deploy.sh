#!/usr/bin/env bash
set -euo pipefail

echo "▶ Sonic Cloud — Firebase deploy"

# Check if firebase CLI is installed
if ! command -v firebase >/dev/null 2>&1; then
  echo "Installing Firebase CLI…"
  npm install -g firebase-tools
fi

# Check if logged in
if ! firebase projects:list 2>/dev/null | grep -q "sonic-cloud"; then
  echo "Please login: firebase login"
  echo "Then run: firebase use sonic-cloud-app"
  exit 1
fi

# Build web app
export PATH="/tmp/flutter/bin:$PATH"
flutter build web --release

# Install functions dependencies
cd functions && npm install && cd ..

# Deploy everything
firebase deploy

echo "✓ Deployed to Firebase!"
echo "  Hosting: https://sonic-cloud-app.web.app"
echo "  API: https://us-central1-sonic-cloud-app.cloudfunctions.net/apiHealth"
