#!/usr/bin/env bash
# ============================================================
# 🌐 BUILD FLUTTER WEB
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../frontend/rojgarnext"

command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter not installed"; exit 1; }

flutter pub get

API_URL="${API_BASE_URL:-https://api.rojgarnext.com}"

flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=API_BASE_URL=$API_URL

echo "✅ Web build complete: build/web/"
du -sh build/web