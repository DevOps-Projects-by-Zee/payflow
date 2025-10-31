#!/bin/bash

# ============================================
# PayFlow Monitoring Explorer Script
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

# Function to check if service is running
check_service() {
    local service_name=$1
    local port=$2
    local url=$3
    
    if curl -s "$url" > /dev/null 2>&1; then
        print_status "$service_name is running on port $port"
        return 0
    else
        print_error "$service_name is not responding on port $port"
        return 1
    fi
}

# Function to show service metrics
show_metrics() {
    local service=$1
    local port=$2
    
    print_info "Metrics for $service:"
    echo "----------------------------------------"
    curl -s "http://localhost:$port/metrics" | head -20
    echo "----------------------------------------"
    echo
}

# Function to show Prometheus targets
show_prometheus_targets() {
    print_info "Prometheus Targets Status:"
    echo "----------------------------------------"
    curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "jq not installed, showing raw output:"
    curl -s "http://localhost:9090/api/v1/targets" | grep -o '"job":"[^"]*"' | sort | uniq
    echo "----------------------------------------"
    echo
}

# Function to show Grafana dashboards
show_grafana_dashboards() {
    print_info "Available Grafana Dashboards:"
    echo "----------------------------------------"
    curl -s "http://admin:admin@localhost:3006/api/search?type=dash-db" | jq -r '.[] | "\(.title): \(.url)"' 2>/dev/null || echo "jq not installed, showing raw output:"
    curl -s "http://admin:admin@localhost:3006/api/search?type=dash-db" | grep -o '"title":"[^"]*"' | head -5
    echo "----------------------------------------"
    echo
}

# Function to show recent logs from Loki
show_recent_logs() {
    print_info "Recent Logs from Loki:"
    echo "----------------------------------------"
    # Query Loki for recent logs
    curl -s "http://localhost:3100/loki/api/v1/query_range?query={job=~\".*\"}&start=$(date -d '5 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ)&end=$(date -u +%Y-%m-%dT%H:%M:%SZ)" | jq -r '.data.result[].values[][1]' 2>/dev/null | head -10 || echo "No recent logs found or jq not installed"
    echo "----------------------------------------"
    echo
}

# Function to show alert status
show_alert_status() {
    print_info "Current Alert Status:"
    echo "----------------------------------------"
    curl -s "http://localhost:9093/api/v1/alerts" | jq -r '.data.alerts[] | "\(.labels.alertname): \(.state)"' 2>/dev/null || echo "jq not installed, showing raw output:"
    curl -s "http://localhost:9093/api/v1/alerts" | grep -o '"alertname":"[^"]*"' | head -5
    echo "----------------------------------------"
    echo
}

# Main monitoring explorer
main() {
    print_header "PayFlow Monitoring Stack Explorer"
    echo
    
    # Check all monitoring services
    print_info "Checking Monitoring Services Status..."
    echo
    
    check_service "Prometheus" "9090" "http://localhost:9090"
    check_service "Grafana" "3006" "http://localhost:3006"
    check_service "AlertManager" "9093" "http://localhost:9093"
    check_service "Loki" "3100" "http://localhost:3100"
    echo
    
    # Check application services
    print_info "Checking Application Services Status..."
    echo
    
    check_service "API Gateway" "3000" "http://localhost:3000/health"
    check_service "Auth Service" "3004" "http://localhost:3004/health"
    check_service "Wallet Service" "3001" "http://localhost:3001/health"
    check_service "Transaction Service" "3005" "http://localhost:3005/health"
    check_service "Notification Service" "3003" "http://localhost:3003/health"
    echo
    
    # Check infrastructure services
    print_info "Checking Infrastructure Services Status..."
    echo
    
    check_service "PostgreSQL" "5432" "http://localhost:5432" || print_warning "PostgreSQL doesn't have HTTP endpoint"
    check_service "Redis" "6379" "http://localhost:6379" || print_warning "Redis doesn't have HTTP endpoint"
    check_service "RabbitMQ Management" "15672" "http://localhost:15672"
    echo
    
    # Show monitoring information
    print_header "Monitoring Information"
    echo
    
    show_prometheus_targets
    show_grafana_dashboards
    show_alert_status
    show_recent_logs
    
    # Show service metrics
    print_header "Service Metrics Preview"
    echo
    
    show_metrics "API Gateway" "3000"
    show_metrics "Auth Service" "3004"
    show_metrics "Wallet Service" "3001"
    
    # Access URLs
    print_header "Access URLs"
    echo
    print_info "🌐 Grafana Dashboard: http://localhost:3006 (admin/admin)"
    print_info "📊 Prometheus Metrics: http://localhost:9090"
    print_info "🚨 AlertManager: http://localhost:9093"
    print_info "📝 Loki Logs: http://localhost:3100"
    print_info "🐰 RabbitMQ Management: http://localhost:15672 (payflow/payflow123)"
    print_info "💳 PayFlow Frontend: http://localhost"
    echo
    
    print_header "Quick Commands"
    echo
    print_info "View all metrics: curl http://localhost:9090/api/v1/query?query=up"
    print_info "Check service health: curl http://localhost:3000/health"
    print_info "View transaction metrics: curl http://localhost:3005/metrics"
    print_info "Check Prometheus targets: curl http://localhost:9090/api/v1/targets"
    echo
    
    print_status "Monitoring stack exploration complete!"
}

# Run the main function
main "$@"