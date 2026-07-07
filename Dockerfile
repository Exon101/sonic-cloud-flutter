# ─────────────────────────────────────────────────────────────────────────────
# Sonic Cloud — Flutter web builder + static file server.
#
# Two-stage build:
#   1. `builder` stage: installs Flutter SDK, runs `flutter build web`, leaves
#      the optimized bundle in /app/build/web.
#   2. `runtime` stage: serves that bundle with nginx:alpine.
#
# Final image size: ~25 MB. Listens on port 8080.
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: build ───────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

# Required for Flutter on Linux
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      clang \
      cmake \
      git \
      ninja-build \
      pkg-config \
      libgtk-3-dev \
      liblzma-dev \
      libstdc++-12-dev \
      curl \
      unzip \
 && rm -rf /var/lib/apt/lists/*

# Install Flutter stable
ARG FLUTTER_VERSION=stable
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-warm the Flutter tool
RUN flutter precache --web

WORKDIR /app

# Cache pub get
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy the rest and build
COPY . .
RUN flutter build web --release

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM nginx:alpine AS runtime

# Copy custom nginx config (SPA fallback + asset cache headers)
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Copy the built web bundle
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O- http://localhost:8080/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
