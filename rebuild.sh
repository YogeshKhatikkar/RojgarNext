#!/bin/bash

echo "========================================"
echo "🔄 Rebuilding RojgarNext Application"
echo "========================================"

# Stop and remove containers
docker-compose down -v

# Remove old images
docker rmi rojgarnext_backend rojgarnext_nginx 2>/dev/null

# Remove builder volume
docker volume rm rojgarnext_flutter_build_output 2>/dev/null

# Rebuild and start
docker-compose up -d --build

echo ""
echo "✅ Rebuild complete!"
echo "📍 Frontend: http://localhost"
echo "📍 Backend API: http://localhost:8000"