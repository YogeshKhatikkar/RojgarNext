#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}🚀 $1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
print_step() { echo -e "${CYAN}▶ $1${NC}"; }

# ================= START WITH DOCKER =================
start_with_docker() {
    print_header "Starting RojgarNext with Docker"
    
    # Check Docker
    print_step "Checking Docker..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running!"
        exit 1
    fi
    print_success "Docker is running"
    
    # Create directories
    print_step "Creating directories..."
    mkdir -p backend/rojgarnext/uploads
    mkdir -p backend/rojgarnext/secure
    mkdir -p backend/rojgarnext/models
    print_success "Directories created"
    
    # Check .env
    if [ ! -f backend/rojgarnext/.env ]; then
        print_warning ".env file not found. Creating default..."
        cat > backend/rojgarnext/.env << 'EOF'
MONGO_URI=mongodb://mongodb:27017/rojgarnext
DATABASE_NAME=rojgarnext
ENVIRONMENT=production
REDIS_URL=redis://redis:6379
SECRET_KEY=your-secret-key-change-in-production-minimum-32-chars
JWT_SECRET_KEY=your-jwt-secret-key-change-in-production
SESSION_SECRET_KEY=your-session-secret-key-change-in-production
OPENAI_API_KEY=dummy-key-for-testing
APP_BASE_URL=http://localhost:8000
CORS_ORIGINS=["http://localhost","http://localhost:8000","http://localhost:3000"]
MOBILE_OTP_BYPASS=true
EOF
        print_warning "Default .env created. Please update with your credentials."
    fi
    
    # Stop existing
    print_step "Stopping existing containers..."
    docker-compose down 2>/dev/null || true
    
    # Build and start
    print_step "Building and starting containers..."
    print_info "⏳ This may take 5-10 minutes on first run..."
    docker-compose up -d --build
    
    # Wait for services
    print_step "Waiting for services to be ready..."
    
    # Check backend health
    MAX_RETRIES=30
    RETRY=0
    while [ $RETRY -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_success "Backend is healthy"
            break
        else
            RETRY=$((RETRY+1))
            print_info "Waiting for backend... ($RETRY/$MAX_RETRIES)"
            sleep 2
        fi
    done
    
    # Print summary
    echo ""
    print_header "🎉 RojgarNext is running!"
    echo -e "${GREEN}📍 Frontend:${NC} http://localhost"
    echo -e "${GREEN}📍 Backend API:${NC} http://localhost:8000"
    echo -e "${GREEN}📍 API Docs:${NC} http://localhost:8000/docs"
    echo -e "${GREEN}📍 MongoDB:${NC} localhost:27017"
    echo -e "${GREEN}📍 Redis:${NC} localhost:6379"
    echo ""
    echo -e "${YELLOW}📋 View logs:${NC} docker-compose logs -f"
    echo -e "${YELLOW}🛑 Stop:${NC} ./stop.sh"
    echo -e "${PURPLE}========================================${NC}"
}

# ================= MAIN =================
case "${1:-}" in
    --docker|"")
        start_with_docker
        ;;
    --dev)
        print_header "Starting in Development Mode"
        docker-compose up -d
        echo -e "${GREEN}✅ Development mode started${NC}"
        ;;
    --prod)
        export COMPOSE_FILE=docker-compose.prod.yml
        start_with_docker
        ;;
    --help|-h)
        echo "Usage: ./start.sh [OPTION]"
        echo "  (no option)  Start with Docker"
        echo "  --dev        Development mode with hot-reload"
        echo "  --prod       Production mode"
        echo "  --help       Show this help"
        ;;
    *)
        print_error "Unknown option: $1"
        exit 1
        ;;
esac

exit 0