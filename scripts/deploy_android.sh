#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — Android deploy helper.
#
# Targets:
#   ./scripts/deploy_android.sh install    # install debug APK on connected device
#   ./scripts/deploy_android.sh firebase   # build release APK + upload to Firebase App Distribution
#   ./scripts/deploy_android.sh playstore  # build release AAB + upload to Google Play (production)
#
# Required environment variables (see .env.example):
#   ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#   FIREBASE_APP_ID_ANDROID / FIREBASE_TOKEN
#   PLAY_STORE_JSON_KEY
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-help}"

case "$TARGET" in
  install)
    echo "▶ Building debug APK and installing on connected device…"
    flutter build apk --debug
    if ! command -v adb >/dev/null 2>&1; then
      echo "Error: adb not found. Add Android platform-tools to PATH." >&2
      exit 1
    fi
    adb install -r build/app/outputs/flutter-apk/app-debug.apk
    ;;

  firebase)
    echo "▶ Uploading release APK to Firebase App Distribution…"
    if [ -z "${FIREBASE_APP_ID_ANDROID:-}" ]; then
      echo "Error: FIREBASE_APP_ID_ANDROID not set" >&2; exit 1
    fi
    if [ -z "${FIREBASE_TOKEN:-}" ]; then
      echo "Error: FIREBASE_TOKEN not set" >&2; exit 1
    fi
    if ! command -v firebase >/dev/null 2>&1; then
      echo "Error: firebase CLI not installed. Run: npm i -g firebase-tools" >&2
      exit 1
    fi
    ./scripts/build.sh apk-release
    firebase appdistribution:distribute \
      build/app/outputs/flutter-apk/app-release.apk \
      --app "$FIREBASE_APP_ID_ANDROID" \
      --token "$FIREBASE_TOKEN" \
      --groups "internal-testers"
    ;;

  playstore)
    echo "▶ Uploading release AAB to Google Play (production)…"
    if [ -z "${PLAY_STORE_JSON_KEY:-}" ]; then
      echo "Error: PLAY_STORE_JSON_KEY not set" >&2; exit 1
    fi
    if ! command -v bundle >/dev/null 2>&1 && ! command -v fastlane >/dev/null 2>&1; then
      echo "Error: need either 'bundle' (Ruby+Bundler) or 'fastlane' on PATH" >&2
      exit 1
    fi
    if command -v bundle >/dev/null 2>&1; then
      bundle exec fastlane android playstore
    else
      fastlane android playstore
    fi
    ;;

  help|*)
    cat <<USAGE
Usage: $0 <target>

Targets:
  install     Build debug APK and install on connected Android device
  firebase    Build release APK + upload to Firebase App Distribution
  playstore   Build release AAB + upload to Google Play (production track)

Required env vars (see .env.example):
  ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS,
  ANDROID_KEY_PASSWORD, FIREBASE_APP_ID_ANDROID, FIREBASE_TOKEN,
  PLAY_STORE_JSON_KEY
USAGE
    exit 1
    ;;
esac
