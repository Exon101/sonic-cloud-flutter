#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — Web deploy helper.
#
# Targets:
#   ./scripts/deploy_web.sh docker     # build & run Docker container locally
#   ./scripts/deploy_web.sh vercel     # deploy web bundle + /api functions to Vercel
#   ./scripts/deploy_web.sh netlify    # deploy web bundle only to Netlify (no /api)
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
    # Vercel needs the build script to run from the project root.
    # `vercel.json` already wires up the Flutter build + the /api functions.
    echo "▶ Deploying to Vercel (web bundle + /api serverless functions)…"
    if [ -n "${VERCEL_TOKEN:-}" ]; then
      vercel deploy --prod --yes \
        ${VERCEL_SCOPE:+--scope "$VERCEL_SCOPE"} \
        --token "$VERCEL_TOKEN"
    else
      vercel --prod
    fi
    ;;

  netlify)
    if ! command -v netlify >/dev/null 2>&1; then
      echo "Error: netlify CLI not installed. Run: npm i -g netlify-cli" >&2
      exit 1
    fi
    ensure_web_build
    echo "▶ Deploying build/web to Netlify (no /api functions)…"
    netlify deploy --prod --dir=build/web
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
  vercel     Deploy to Vercel (Flutter web bundle + /api serverless functions)
  netlify    Deploy web bundle only to Netlify (no /api functions)
  preview    Serve build/web locally on :8080 via python3 http.server
USAGE
    exit 1
    ;;
esac
