# ============================================
# PayFlow API Gateway - Optimized Multi-Stage Build
# Target: <60MB (reduced from 235MB)
# ============================================

# #### Stage 1: Dependencies ####
# #### Install production dependencies only ####
FROM node:18-alpine AS deps
WORKDIR /app

# #### Copy package files for better caching ####
COPY package*.json ./

# #### Install only production dependencies ####
RUN npm ci --only=production --ignore-scripts

# #### Stage 2: Final Production Image ####
FROM node:18-alpine AS production

WORKDIR /app

# #### Create non-root user for security ####
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# #### Copy only production dependencies from deps stage ####
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# #### Copy application code ####
COPY --chown=nodejs:nodejs . .

# #### Switch to non-root user ####
USER nodejs

# #### Expose port ####
EXPOSE 3000

# #### Health check ####
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# #### Start application ####
CMD ["node", "server.js"]
