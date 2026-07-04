#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — Web deploy helper.
#
# Targets:
#   ./scripts/deploy_web.sh docker     # build & run Docker container locally
#   ./scripts/deploy_web.sh vercel     # deploy to Vercel (requires `npm i -g vercel`)
#   ./scripts/deploy_web.sh netlify    # deploy to Netlify (requires `npm i -g netlify-cli`)
#   ./scripts/deploy_web.sh firebase   # deploy to Firebase Hosting (requires `firebase` CLI)
#   ./scripts/deploy_web.sh preview    # serve build/web locally on :8080
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-help}"

ensure_web_build() {
  if [ ! -d "build/web" ] || [ ! -f "build/web/index.html" ]; then
    echo "▶ build/web not found — building…"
    ./scripts/build.sh web
  fi
}

case "$TARGET" in
  docker)
    echo "▶ Building Docker image…"
    docker build -t sonic-cloud:latest .
    echo "▶ Running container on http://localhost:8080 (Ctrl-C to stop)…"
    docker run --rm -p 8080:8080 sonic-cloud:latest
    ;;

  vercel)
    if ! command -v vercel >/dev/null 2>&1; then
      echo "Error: vercel CLI not installed. Run: npm i -g vercel" >&2
      exit 1
    fi
    echo "▶ Deploying to Vercel…"
    vercel --prod
    ;;

  netlify)
    if ! command -v netlify >/dev/null 2>&1; then
      echo "Error: netlify CLI not installed. Run: npm i -g netlify-cli" >&2
      exit 1
    fi
    ensure_web_build
    echo "▶ Deploying build/web to Netlify…"
    netlify deploy --prod --dir=build/web
    ;;

  firebase)
    if ! command -v firebase >/dev/null 2>&1; then
      echo "Error: firebase CLI not installed. Run: npm i -g firebase-tools" >&2
      exit 1
    fi
    ensure_web_build
    echo "▶ Deploying build/web to Firebase Hosting…"
    firebase deploy --only hosting --public build/web
    ;;

  preview)
    ensure_web_build
    echo "▶ Serving build/web on http://localhost:8080 (Ctrl-C to stop)…"
    if command -v python3 >/dev/null 2>&1; then
      (cd build/web && python3 -m http.server 8080)
    else
      echo "Error: python3 not available" >&2
      exit 1
    fi
    ;;

  help|*)
    cat <<USAGE
Usage: $0 <target>

Targets:
  docker     Build and run the Docker image on http://localhost:8080
  vercel     Deploy to Vercel (requires 'vercel' CLI)
  netlify    Deploy to Netlify (requires 'netlify' CLI)
  firebase   Deploy to Firebase Hosting (requires 'firebase' CLI)
  preview    Serve build/web locally on :8080 via python3 http.server
USAGE
    exit 1
    ;;
esac
