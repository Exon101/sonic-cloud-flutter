#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — universal build script.
#
# Usage:
#   ./scripts/build.sh web        # build web bundle
#   ./scripts/build.sh apk        # build Android APK (debug)
#   ./scripts/build.sh apk-release
#   ./scripts/build.sh aab        # build Android App Bundle (release)
#   ./scripts/build.sh ios        # build iOS (no codesign)
#   ./scripts/build.sh macos      # build macOS app
#   ./scripts/build.sh windows    # build Windows .exe
#   ./scripts/build.sh linux      # build Linux binary
#   ./scripts/build.sh all        # build web + apk + (if on macOS) ios + macos
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not on PATH" >&2
  exit 1
fi

TARGET="${1:-help}"

build_web() {
  echo "▶ Building web…"
  flutter build web --release --web-renderer canvaski
  echo "✓ Web bundle: build/web"
}

build_apk_debug() {
  echo "▶ Building Android APK (debug)…"
  flutter build apk --debug
  echo "✓ APK: build/app/outputs/flutter-apk/app-debug.apk"
}

build_apk_release() {
  echo "▶ Building Android APK (release)…"
  flutter build apk --release
  echo "✓ APK: build/app/outputs/flutter-apk/app-release.apk"
}

build_aab() {
  echo "▶ Building Android App Bundle (release)…"
  flutter build appbundle --release
  echo "✓ AAB: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  echo "▶ Building iOS (no codesign)…"
  flutter build ios --release --no-codesign
  echo "✓ Runner.app: build/ios/iphoneos/Runner.app"
}

build_macos() {
  echo "▶ Building macOS…"
  flutter build macos --release
  echo "✓ App: build/macos/Build/Products/Release/Sonic Cloud.app"
}

build_windows() {
  echo "▶ Building Windows…"
  flutter build windows --release
  echo "✓ EXE: build/windows/x64/runner/Release/sonic_cloud.exe"
}

build_linux() {
  echo "▶ Building Linux…"
  flutter build linux --release
  echo "✓ Binary: build/linux/x64/release/bundle/sonic_cloud"
}

case "$TARGET" in
  web)            build_web ;;
  apk)            build_apk_debug ;;
  apk-release)    build_apk_release ;;
  aab)            build_aab ;;
  ios)            build_ios ;;
  macos)          build_macos ;;
  windows)        build_windows ;;
  linux)          build_linux ;;
  all)
    build_web
    build_apk_release
    build_aab
    if [ "$(uname)" = "Darwin" ]; then
      build_ios
      build_macos
    fi
    ;;
  help|*)
    cat <<USAGE
Usage: $0 <target>

Targets:
  web            Flutter web bundle (build/web)
  apk            Android APK (debug)
  apk-release    Android APK (release)
  aab            Android App Bundle (release, for Play Store)
  ios            iOS app (no codesign — use fastlane/match for signing)
  macos          macOS .app bundle
  windows        Windows .exe + bundled DLLs
  linux          Linux binary bundle
  all            web + apk-release + aab (+ ios + macos on macOS)
USAGE
    exit 1
    ;;
esac
