@echo off
echo ========================================
echo 🚀 Starting RojgarNext Application
echo ========================================

echo Checking Docker status...
docker ps > nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running!
    echo Please start Docker Desktop first.
    pause
    exit /b 1
)

echo ✅ Docker is running
echo.

echo Creating directories...
if not exist "backend\rojgarnext\uploads" mkdir backend\rojgarnext\uploads
if not exist "backend\rojgarnext\secure" mkdir backend\rojgarnext\secure
if not exist "backend\rojgarnext\models" mkdir backend\rojgarnext\models

echo.
echo 🔨 Building and starting containers...
docker compose -f docker-compose.simple.yml up -d --build

echo.
echo ========================================
echo 🎉 RojgarNext is running!
echo ========================================
echo 📍 Frontend: http://localhost
echo 📍 Backend API: http://localhost:8000
echo 📍 API Docs: http://localhost:8000/docs
echo.
echo 📋 To view logs: docker compose -f docker-compose.simple.yml logs -f
echo 🛑 To stop: docker compose -f docker-compose.simple.yml down
echo ========================================
pause