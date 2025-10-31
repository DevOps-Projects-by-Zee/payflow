# ============================================
# PayFlow Frontend - Ultra Minimal Build
# ============================================
# Purpose: Build and serve the React frontend application
# Target: <50MB final image

# #### Build Stage ####
FROM node:18-alpine AS builder

WORKDIR /app

# #### Copy package files first for better caching ####
COPY package*.json ./

# #### Install dependencies with cache mounts for speed ####
# #### Using npm install with cache for faster builds ####
RUN --mount=type=cache,target=/root/.npm \
    npm install

# #### Copy source code ####
COPY . .

# #### Set build arguments and environment variables ####
ARG REACT_APP_API_URL=https://api.payflow.local/api
ENV REACT_APP_API_URL=$REACT_APP_API_URL

# #### Build the optimized production React app ####
RUN npm run build

# ============================================
# Production Stage - Ultra Minimal ####
# #### Using nginx:alpine (~23MB) with optimized config ####
FROM nginx:alpine

# #### Remove default nginx files to save space and install wget for healthcheck ####
RUN rm -rf /usr/share/nginx/html/* \
    /etc/nginx/conf.d/default.conf \
    && apk --no-cache add ca-certificates wget

# #### Copy built React app ####
COPY --from=builder /app/build /usr/share/nginx/html

# #### Copy custom nginx configuration ####
COPY nginx.conf /etc/nginx/conf.d/default.conf

# #### Expose port 80 ####
EXPOSE 80

# #### Health check endpoint ####
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# #### Start nginx in foreground ####
CMD ["nginx", "-g", "daemon off;"]
