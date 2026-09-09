#!/bin/bash

echo ""
echo "========================================"
echo "🛑 Stopping RojgarNext Application"
echo "========================================"

# Stop Docker containers
if docker-compose ps > /dev/null 2>&1; then
    echo "Stopping Docker containers..."
    docker-compose down -v
    echo "✅ Docker containers stopped"
fi

# Stop local backend
if pgrep -f "uvicorn app.main:app" > /dev/null 2>&1; then
    echo "Stopping local backend..."
    pkill -f "uvicorn app.main:app" 2>/dev/null
    echo "✅ Backend stopped"
fi

# Stop local frontend
if pgrep -f "flutter run" > /dev/null 2>&1; then
    echo "Stopping local frontend..."
    pkill -f "flutter run" 2>/dev/null
    echo "✅ Frontend stopped"
fi

echo ""
echo "✅ All services stopped"
echo "========================================"