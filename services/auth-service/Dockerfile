# ============================================
# PayFlow Auth Service - Optimized Multi-Stage Build
# Target: <100MB (reduced from 184MB)
# ============================================

# #### Stage 1: Install Dependencies ####
# #### Why: Separate layer for dependencies - rarely changes ####
FROM node:18-alpine AS deps
WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./

# Install ONLY production dependencies
# --ignore-scripts: Skip lifecycle scripts (faster install)
RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

# #### Stage 2: Production Image ####
# #### Why: Final image only contains what's needed ####
FROM node:18-alpine AS production

WORKDIR /app

# Create non-root user for security
# Why: Security best practice, minimal size impact (~1MB)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies from deps stage
# Why: Avoids re-downloading dependencies on code changes
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3004

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3004/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "server.js"]
