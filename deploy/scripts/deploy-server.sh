#!/usr/bin/env bash
# ============================================================
# 🚀 DEPLOY TO SERVER — Zero Downtime
# ============================================================
set -euo pipefail

ENV="${1:-production}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"; }
ok()  { echo -e "${GREEN}✅ $*${NC}"; }
fail(){ echo -e "${RED}❌ $*${NC}"; exit 1; }

# Pre-deploy backup
log "Creating backup..."
bash "$SCRIPT_DIR/backup.sh" || true

# Build & deploy
log "Building images..."
docker compose -f docker-compose.prod.yml build --parallel

log "Rolling update (zero downtime)..."
docker compose -f docker-compose.prod.yml up -d --remove-orphans --scale backend=3

# Health check
log "Health check..."
for i in {1..30}; do
  if curl -sf http://localhost/api/v1/health >/dev/null 2>&1; then
    ok "Backend healthy after ${i}s"
    break
  fi
  [ $i -eq 30 ] && fail "Health check failed"
  sleep 1
done

# Cleanup
docker image prune -f >/dev/null
docker builder prune -f --filter "until=72h" >/dev/null

echo ""
echo "============================================================"
ok "🎉 DEPLOYMENT SUCCESSFUL — $ENV"
echo "============================================================"
docker compose -f docker-compose.prod.yml ps