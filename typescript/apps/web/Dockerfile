# syntax=docker/dockerfile:1

# ==============================================================================
# Web App Dockerfile - Using turbo prune for optimized monorepo builds
# Build from monorepo root: docker build -f apps/web/Dockerfile .
# ==============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Base image with pnpm
# -----------------------------------------------------------------------------
FROM node:22-alpine AS base

RUN apk update && apk add --no-cache libc6-compat

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable && corepack prepare pnpm@10.24.0 --activate

WORKDIR /app

# -----------------------------------------------------------------------------
# Stage 2: Prune monorepo for this app
# -----------------------------------------------------------------------------
FROM base AS pruner

RUN pnpm add -g turbo@^2

COPY . .

# Generate pruned monorepo with only web's dependencies
RUN turbo prune web --docker

# -----------------------------------------------------------------------------
# Stage 3: Install dependencies & build
# -----------------------------------------------------------------------------
FROM base AS builder

# Copy pruned lockfile and package.jsons (changes less often)
COPY --from=pruner /app/out/json/ .

# Install dependencies using pruned lockfile
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# Copy pruned source code
COPY --from=pruner /app/out/full/ .

# Build argument for client-side env vars (baked into build)
ARG VITE_SERVER_URL
ENV VITE_SERVER_URL=$VITE_SERVER_URL

# Optional: Enable turbo remote caching for faster builds
# ARG TURBO_TEAM
# ENV TURBO_TEAM=$TURBO_TEAM
# ARG TURBO_TOKEN
# ENV TURBO_TOKEN=$TURBO_TOKEN

# Build the web app
RUN pnpm turbo build --filter=web

# -----------------------------------------------------------------------------
# Stage 4: Production dependencies only
# -----------------------------------------------------------------------------
FROM base AS prod-deps

# Copy pruned lockfile and package.jsons
COPY --from=pruner /app/out/json/ .

# Install production dependencies with hoisting for easier module resolution
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --prod --shamefully-hoist

# -----------------------------------------------------------------------------
# Stage 5: Production image
# -----------------------------------------------------------------------------
FROM node:22-alpine AS runner

WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 web

# Copy production node_modules (needed for react-router-serve runtime)
COPY --from=prod-deps --chown=web:nodejs /app/node_modules ./node_modules
COPY --from=prod-deps --chown=web:nodejs /app/apps/web/node_modules ./apps/web/node_modules

# Copy built application
COPY --from=builder --chown=web:nodejs /app/apps/web/build ./apps/web/build
COPY --from=builder --chown=web:nodejs /app/apps/web/package.json ./apps/web/

USER web

WORKDIR /app/apps/web

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Health check for k8s readiness/liveness probes
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["npx", "react-router-serve", "./build/server/index.js"]
