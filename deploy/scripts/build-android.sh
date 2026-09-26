#!/usr/bin/env bash
# ============================================================
# 📱 BUILD ANDROID APK + AAB
# Usage:
#   ./build-android.sh apk        → universal APK
#   ./build-android.sh split      → per-ABI APKs
#   ./build-android.sh aab        → Play Store bundle
#   ./build-android.sh all        → everything
# ============================================================
set -euo pipefail

MODE="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../frontend/rojgarnext"

command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter not installed"; exit 1; }

# Check signing config
if [ ! -f "android/key.properties" ]; then
  echo "⚠️  android/key.properties not found"
  echo "   Copy android/key.properties.example and fill it in"
  echo "   To generate keystore:"
  echo "     keytool -genkey -v -keystore android/app/rojgarnext-release-key.jks \\"
  echo "       -keyalg RSA -keysize 2048 -validity 10000 -alias rojgarnext"
  exit 1
fi

flutter pub get

API_URL="${API_BASE_URL:-https://api.rojgarnext.com}"
FLAVOR="${FLAVOR:-prod}"

case "$MODE" in
  apk)
    flutter build apk --release --flavor $FLAVOR --dart-define=API_BASE_URL=$API_URL
    echo "✅ APK: build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
    ;;
  split)
    flutter build apk --release --split-per-abi --flavor $FLAVOR --dart-define=API_BASE_URL=$API_URL
    echo "✅ Split APKs in: build/app/outputs/flutter-apk/"
    ls -la build/app/outputs/flutter-apk/*.apk
    ;;
  aab)
    flutter build appbundle --release --flavor $FLAVOR --dart-define=API_BASE_URL=$API_URL
    echo "✅ AAB: build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
    ;;
  all)
    flutter build apk --release --split-per-abi --flavor $FLAVOR --dart-define=API_BASE_URL=$API_URL
    flutter build appbundle --release --flavor $FLAVOR --dart-define=API_BASE_URL=$API_URL
    echo "✅ All Android artifacts built!"
    ;;
  *) echo "Usage: $0 [apk|split|aab|all]"; exit 1 ;;
esac