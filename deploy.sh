#!/bin/bash
set -e

echo "🚀 Starting RojgarNext Production Deployment"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment
if [ -f .env.production ]; then
    source .env.production
fi

# Create secrets directory
mkdir -p secrets

# Create secret files (replace with actual values)
echo "${MONGO_ROOT_USER:-admin}" > secrets/mongo_root_user.txt
echo "${MONGO_ROOT_PASSWORD:-password123}" > secrets/mongo_root_password.txt
echo "${POSTGRES_USER:-rojgarnext}" > secrets/postgres_user.txt
echo "${POSTGRES_PASSWORD:-password123}" > secrets/postgres_password.txt
echo "${MINIO_ROOT_USER:-minioadmin}" > secrets/minio_root_user.txt
echo "${MINIO_ROOT_PASSWORD:-minioadmin123}" > secrets/minio_root_password.txt

# Deploy function
deploy() {
    echo -e "${GREEN}🐳 Building Docker images...${NC}"
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    echo -e "${GREEN}🚀 Starting services...${NC}"
    docker-compose -f docker-compose.prod.yml up -d
    
    echo -e "${GREEN}✅ Deployment complete!${NC}"
}

# Health check
health_check() {
    echo -e "${YELLOW}🏥 Running health checks...${NC}"
    
    if curl -s http://localhost:8000/health > /dev/null; then
        echo -e "${GREEN}✅ Backend is healthy${NC}"
    else
        echo -e "${RED}❌ Backend health check failed${NC}"
        exit 1
    fi
    
    if curl -s http://localhost > /dev/null; then
        echo -e "${GREEN}✅ Frontend is healthy${NC}"
    else
        echo -e "${RED}❌ Frontend health check failed${NC}"
        exit 1
    fi
}

# Main execution
case "${1:-}" in
    deploy)
        deploy
        ;;
    health)
        health_check
        ;;
    *)
        echo "Usage: $0 {deploy|health}"
        exit 1
esac