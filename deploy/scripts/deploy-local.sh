#!/usr/bin/env bash
# ============================================================
# 🖥️  LOCAL DEVELOPMENT — ONE COMMAND
# ============================================================
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
ok()  { echo -e "${GREEN}✅ $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

command -v docker >/dev/null 2>&1 || { echo "❌ Install Docker first"; exit 1; }

if [ ! -f "../backend/rojgarnext/.env" ]; then
  log "Creating .env from template..."
  cp ../backend/rojgarnext/.env.example ../backend/rojgarnext/.env
  echo "⚠️  Edit ../backend/rojgarnext/.env with your values!"
fi

log "Starting local dev environment..."
docker compose -f docker-compose.dev.yml up -d --build

log "Waiting for services..."
sleep 15

log "Health check..."
curl -sf http://localhost:8000/api/v1/health && ok "Backend healthy" || true
curl -sf http://localhost:8080 >/dev/null && ok "Frontend healthy" || true

echo ""
echo "============================================================"
ok "🚀 LOCAL DEV ENVIRONMENT READY"
echo "============================================================"
echo "   🌐 Web App      →  http://localhost:8080"
echo "   📚 API Docs     →  http://localhost:8000/docs"
echo "   🗄️  Mongo         →  localhost:27017"
echo "   ⚡ Redis        →  localhost:6379"
echo "   📱 Android      →  flutter run -d <device-id>"
echo ""
echo "   Logs: docker compose -f docker-compose.dev.yml logs -f"
echo "   Stop: docker compose -f docker-compose.dev.yml down"
echo "============================================================"