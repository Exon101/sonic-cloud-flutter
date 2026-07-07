#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — iOS deploy helper (macOS only).
#
# Targets:
#   ./scripts/deploy_ios.sh install      # build + install on connected iOS device
#   ./scripts/deploy_ios.sh firebase     # build release IPA + upload to Firebase
#   ./scripts/deploy_ios.sh testflight   # build + upload to TestFlight
#   ./scripts/deploy_ios.sh appstore     # build + upload to App Store
#
# Required environment variables (see .env.example):
#   APPLE_ID / TEAM_ID / MATCH_GIT_URL / MATCH_PASSWORD
#   FIREBASE_APP_ID_IOS / FIREBASE_TOKEN
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname)" != "Darwin" ]; then
  echo "Error: iOS builds require macOS" >&2; exit 1
fi

TARGET="${1:-help}"

case "$TARGET" in
  install)
    echo "▶ Building and installing on connected iOS device…"
    flutter run --release
    ;;

  firebase)
    echo "▶ Building release IPA + uploading to Firebase App Distribution…"
    if [ -z "${FIREBASE_APP_ID_IOS:-}" ]; then
      echo "Error: FIREBASE_APP_ID_IOS not set" >&2; exit 1
    fi
    flutter build ipa --release --no-codesign
    if ! command -v firebase >/dev/null 2>&1; then
      echo "Error: firebase CLI not installed. Run: npm i -g firebase-tools" >&2
      exit 1
    fi
    IPA_PATH=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
    [ -z "$IPA_PATH" ] && { echo "Error: no .ipa found in build/ios/ipa/" >&2; exit 1; }
    firebase appdistribution:distribute "$IPA_PATH" \
      --app "$FIREBASE_APP_ID_IOS" \
      --token "$FIREBASE_TOKEN" \
      --groups "internal-testers"
    ;;

  testflight)
    echo "▶ Uploading to TestFlight via fastlane…"
    if command -v bundle >/dev/null 2>&1; then
      bundle exec fastlane ios beta
    else
      fastlane ios beta
    fi
    ;;

  appstore)
    echo "▶ Uploading to App Store via fastlane…"
    if command -v bundle >/dev/null 2>&1; then
      bundle exec fastlane ios appstore
    else
      fastlane ios appstore
    fi
    ;;

  help|*)
    cat <<USAGE
Usage: $0 <target>

Targets:
  install    Build & install on connected iOS device (flutter run --release)
  firebase   Build IPA + upload to Firebase App Distribution
  testflight Build IPA + upload to TestFlight (via fastlane)
  appstore   Build IPA + upload to App Store (via fastlane)

Required env vars (see .env.example):
  APPLE_ID, TEAM_ID, MATCH_GIT_URL, MATCH_PASSWORD,
  FIREBASE_APP_ID_IOS, FIREBASE_TOKEN
USAGE
    exit 1
    ;;
esac
