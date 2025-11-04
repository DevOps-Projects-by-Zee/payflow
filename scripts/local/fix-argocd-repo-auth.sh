#!/bin/bash
# ============================================
# Fix ArgoCD Repository Authentication
# ============================================
# Purpose: Add GitHub repository credentials to ArgoCD
#
# This script helps fix the "Repository not found" error in ArgoCD
# by adding repository credentials for private repos or verifying public repo access
#
# Usage:
#   ./scripts/fix-argocd-repo-auth.sh
#
# Options:
#   1. Make repo public (easiest - no credentials needed)
#   2. Add GitHub token for private repo

set -e

export KUBECONFIG=~/.kube/microk8s-config

echo "🔧 ArgoCD Repository Authentication Fix"
echo "====================================="
echo ""

# Check if ArgoCD is running
if ! kubectl get namespace argocd &> /dev/null; then
  echo "❌ ArgoCD namespace not found. Please install ArgoCD first."
  exit 1
fi

echo "📋 Repository: https://github.com/DevOps-Projects-by-Zee/payflow.git"
echo ""

# Test repository access
echo "🔍 Testing repository access..."
REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/DevOps-Projects-by-Zee/payflow")

if [ "$REPO_STATUS" = "200" ]; then
  echo "✅ Repository is accessible (public)"
  echo ""
  echo "💡 If ArgoCD still shows errors:"
  echo "   1. Go to ArgoCD UI: https://argocd.gameapp.games or http://argocd.payflow.local"
  echo "   2. Settings → Repositories"
  echo "   3. Click 'Connect Repo'"
  echo "   4. Add: https://github.com/DevOps-Projects-by-Zee/payflow.git"
  echo "   5. Leave credentials empty (public repo)"
  exit 0
elif [ "$REPO_STATUS" = "404" ]; then
  echo "❌ Repository not found (404)"
  echo ""
  echo "💡 Possible issues:"
  echo "   1. Repository doesn't exist at this path"
  echo "   2. Repository is private and requires authentication"
  echo "   3. Repository name or organization is incorrect"
  echo ""
  echo "🔧 Solutions:"
  echo ""
  echo "Option 1: Make Repository Public (Easiest)"
  echo "  1. Go to: https://github.com/DevOps-Projects-by-Zee/payflow/settings"
  echo "  2. Scroll to 'Danger Zone'"
  echo "  3. Click 'Change visibility' → 'Make public'"
  echo "  4. Wait 1-2 minutes, then ArgoCD should work"
  echo ""
  echo "Option 2: Add GitHub Token for Private Repo"
  echo "  1. Create GitHub Personal Access Token:"
  echo "     https://github.com/settings/tokens"
  echo "     → Generate new token (classic)"
  echo "     → Select 'repo' scope"
  echo "  2. Run this script with token:"
  echo "     GITHUB_TOKEN=your_token ./scripts/fix-argocd-repo-auth.sh"
  echo ""
  
  # If token provided, create secret
  if [ -n "$GITHUB_TOKEN" ]; then
    echo "🔑 Creating repository secret with provided token..."
    
    # Get GitHub username (optional)
    GITHUB_USER="${GITHUB_USERNAME:-DevOps-Projects-by-Zee}"
    
    kubectl create secret generic argocd-repo-credentials \
      --from-literal=type=git \
      --from-literal=url=https://github.com/DevOps-Projects-by-Zee/payflow.git \
      --from-literal=password="$GITHUB_TOKEN" \
      --from-literal=username="$GITHUB_USER" \
      -n argocd \
      --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl label secret argocd-repo-credentials argocd.argoproj.io/secret-type=repository -n argocd --overwrite
    
    echo "✅ Repository secret created"
    echo ""
    echo "🔄 Restarting ArgoCD application controller to pick up credentials..."
    kubectl rollout restart deployment argocd-application-controller -n argocd
    kubectl rollout status deployment argocd-application-controller -n argocd --timeout=120s
    
    echo ""
    echo "✅ Done! Check ArgoCD UI - the repository should now work."
  else
    echo "⚠️  No token provided. Choose one of the options above."
    exit 1
  fi
else
  echo "⚠️  Unexpected status code: $REPO_STATUS"
  echo "   Repository may require authentication or doesn't exist"
  exit 1
fi

