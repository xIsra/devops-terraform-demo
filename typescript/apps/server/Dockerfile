# syntax=docker/dockerfile:1

# ==============================================================================
# Server App Dockerfile - Using turbo prune for optimized monorepo builds
# Build from monorepo root: docker build -f apps/server/Dockerfile .
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

# Generate pruned monorepo with only server's dependencies
RUN turbo prune server --docker

# -----------------------------------------------------------------------------
# Stage 3: Install dependencies
# -----------------------------------------------------------------------------
FROM base AS builder

# Copy pruned lockfile and package.jsons (changes less often)
COPY --from=pruner /app/out/json/ .

# Install dependencies using pruned lockfile
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# Copy pruned source code
COPY --from=pruner /app/out/full/ .

# Optional: Enable turbo remote caching for faster builds
# ARG TURBO_TEAM
# ENV TURBO_TEAM=$TURBO_TEAM
# ARG TURBO_TOKEN
# ENV TURBO_TOKEN=$TURBO_TOKEN

# Build the server (tsdown bundles workspace deps via noExternal)
RUN pnpm turbo build --filter=server

# -----------------------------------------------------------------------------
# Stage 4: Production dependencies
# -----------------------------------------------------------------------------
FROM base AS prod-deps

# Copy pruned lockfile and package.jsons
COPY --from=pruner /app/out/json/ .

# Install production dependencies only
# Use shamefully-hoist to put all packages in root node_modules for easier resolution
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --prod --shamefully-hoist

# -----------------------------------------------------------------------------
# Stage 5: Production image
# -----------------------------------------------------------------------------
FROM node:22-alpine AS runner

WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 server

# Copy production node_modules (pnpm structure with .pnpm store and symlinks)
# Need to preserve the full pnpm structure for symlinks to work
COPY --from=prod-deps --chown=server:nodejs /app/node_modules ./node_modules
COPY --from=prod-deps --chown=server:nodejs /app/apps/server/node_modules ./apps/server/node_modules

# Copy packages directory (needed for workspace symlinks to resolve)
COPY --from=builder --chown=server:nodejs /app/packages ./packages

# Copy the bundled output (tsdown bundles workspace deps via noExternal)
COPY --from=builder --chown=server:nodejs /app/apps/server/dist ./dist


USER server

# Environment variables (set defaults, override at runtime)
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Health check for k8s readiness/liveness probes
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["node", "dist/index.mjs"]
