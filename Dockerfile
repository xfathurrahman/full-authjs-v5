# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=20.11.0
FROM node:${NODE_VERSION}-slim as base

LABEL fly_launch_runtime="Next.js/Prisma"
LABEL maintainer="contact@fathur.dev"
LABEL version="1.0.0"
LABEL description="Docker image for lppm-uty app."

# Next.js/Prisma app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# Install pnpm
ARG BUN_VERSION=1.0.26
RUN npm install -g bun@$BUN_VERSION

# Install dependencies needed by sharp
RUN apt-get update -qq && apt-get install -y \
    libvips-dev

# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build node modules and sharp dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential node-gyp openssl pkg-config python-is-python3 libvips-dev

# Install node modules including sharp
COPY --link bun.lockb package.json ./
RUN bun install --frozen-lockfile

# Generate Prisma Client
COPY --link prisma .
RUN bunx prisma generate

# Copy application code
COPY --link . .

# Build application
RUN bun run build

# Remove development dependencies
RUN rm -rf node_modules && \
    bun install --frozen-lockfile --production

# Final stage for app image
FROM base

# Install runtime dependencies needed for sharp
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y openssl libvips && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy built application
COPY --from=build /app /app

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000

CMD [ "bun", "run", "start" ]
