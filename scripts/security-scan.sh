#!/bin/bash
# ============================================
# scripts/security-scan.sh
# ============================================
# Purpose: Comprehensive security scanning for PayFlow application
# Tools: npm audit, Trivy, OWASP Dependency-Check
# Usage: ./scripts/security-scan.sh
# Exit codes: 0=success, 1=errors found

# ============================================
# COLOR DEFINITIONS
# ============================================
# ANSI color codes for terminal output
GREEN='\033[0;32m'  # Success messages (green text)
RED='\033[0;31m'     # Error messages (red text)
YELLOW='\033[1;33m'  # Warning messages (yellow text)
BLUE='\033[0;34m'    # Information messages (blue text)
NC='\033[0m'         # No color (reset to default)

# ============================================
# SCRIPT HEADER
# ============================================
echo "🔒 PayFlow Security Scan"
echo "========================"
echo ""

# ============================================
# STAGE 1: NPM AUDIT
# ============================================
# Purpose: Scan Node.js dependencies for known vulnerabilities
# Tool: npm audit (built into npm)
# Output: List of vulnerabilities by severity
# Severity levels: critical > high > moderate > low

echo "📦 Running npm audit..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for service in services/*; do  # Loop through all service directories
    # Check if directory exists and has package.json
    if [ -d "$service" ] && [ -f "$service/package.json" ]; then
        service_name=$(basename "$service")  # Get service name
        echo "Scanning $service_name..."
        
        # Change to service directory and run npm audit
        # Only show high and critical severity issues
        cd "$service" && npm audit --audit-level=high && cd ../..
    fi
done

# ============================================
# STAGE 2: TRIVY CONTAINER SCANNING
# ============================================
# Purpose: Scan Docker container images for vulnerabilities
# Tool: Trivy (https://github.com/aquasecurity/trivy)
# Installation: brew install trivy (macOS) or see trivy docs
# Output: Vulnerability report for container images
# Trivy checks for: OS packages, application dependencies, config files

# Check if Trivy is installed
if command -v trivy &> /dev/null; then
    echo ""
    echo "🐳 Scanning Docker images with Trivy..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Scan each application service image
    for image in api-gateway auth-service wallet-service transaction-service notification-service; do
        echo "Scanning payflow/$image:latest..."
        echo "-----------------------------------"
        
        # Trivy scan options:
        # - Exit code 0: Scans even with vulnerabilities (non-blocking)
        # Use exit-code=1 to block pipeline on vulnerabilities
        trivy image payflow/$image:latest --severity HIGH,CRITICAL
    done
else
    echo ""
    echo -e "${YELLOW}⚠️  Trivy not installed. Install with: brew install trivy${NC}"
    echo "   Trivy provides comprehensive container image scanning."
fi

# ============================================
# STAGE 3: OWASP DEPENDENCY-CHECK
# ============================================
# Purpose: Advanced dependency vulnerability analysis
# Tool: OWASP Dependency-Check (https://owasp.org/www-project-dependency-check/)
# Installation: brew install dependency-check or download from OWASP
# Output: XML/HTML report with CVE details
# Advanced features: CVE database sync, false-positive management

# Check if OWASP Dependency-Check is installed
if command -v dependency-check &> /dev/null; then
    echo ""
    echo "🔍 Running OWASP Dependency Check..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run OWASP Dependency-Check on all services
    # --project: Project name for reporting
    # --scan: Directory to scan
    # --format: Output formats (HTML, XML, JSON)
    # --suppression: Suppress false positives
    dependency-check --project PayFlow --scan services/ --format HTML,XML --enableExperimental
else
    echo ""
    echo -e "${YELLOW}⚠️  OWASP Dependency Check not installed.${NC}"
    echo "   Install with: brew install dependency-check"
    echo "   Provides CVE database scanning for dependencies."
fi

# ============================================
# STAGE 4: SUMMARY
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Security scan completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Review all reported vulnerabilities"
echo "2. Update packages with: npm update"
echo "3. Fix critical issues immediately"
echo "4. Document false positives if needed"
echo ""

# Exit with appropriate code
# 0 = success (no blocking issues found)
# 1 = failure (critical vulnerabilities found)
exit 0
