#!/bin/bash
# ============================================
# scripts/cleanup.sh - Cleanup Script
# ============================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🧹 PayFlow Cleanup"
echo "=================="
echo ""

read -p "This will remove all containers, volumes, and data. Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "🗑️  Stopping and removing containers..."
docker-compose down -v

echo "🧹 Removing logs..."
rm -rf logs/*.log

echo "🗑️  Removing old backups (>30 days)..."
find backups/ -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true

echo "🧹 Cleaning Docker system..."
docker system prune -f

echo -e "${GREEN}✅ Cleanup completed!${NC}"
