# This dockerfile should be built with `make docker-build` from the stash root.

# Build Frontend
FROM node:20-bullseye-slim AS frontend
RUN apt-get update \
 && apt-get install -y --no-install-recommends make git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
## cache node_modules separately
COPY ./ui/v2.5/package.json ./ui/v2.5/yarn.lock /stash/ui/v2.5/
WORKDIR /stash
COPY Makefile /stash/
COPY ./graphql /stash/graphql/
COPY ./ui /stash/ui/
RUN make pre-ui
RUN make generate-ui
ARG GITHASH
ARG STASH_VERSION
RUN BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S") make ui-only

# Build Backend
FROM golang:1.22.8-bullseye AS backend
RUN apt-get update \
 && apt-get install -y --no-install-recommends make build-essential ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /stash
COPY ./go* ./*.go Makefile gqlgen.yml .gqlgenc.yml /stash/
COPY ./graphql /stash/graphql/
COPY ./scripts /stash/scripts/
COPY ./pkg /stash/pkg/
COPY ./cmd /stash/cmd/
COPY ./internal /stash/internal/
# needed for generate-login-locale
COPY ./ui /stash/ui/
RUN make generate-backend generate-login-locale
COPY --from=frontend /stash /stash/
ARG GITHASH
ARG STASH_VERSION
RUN make flags-release flags-pie stash

# Final Runnable Image (Debian Bookworm-slim)
FROM debian:bookworm-slim

# 安装运行时依赖 + Intel QSV/VAAPI 驱动和库
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      vips-tools \
      ffmpeg \
      intel-media-va-driver-non-free \
      libmfx1 \
      libva2 \
      libva-drm2 \
      libdrm2 \
      vainfo \
 && rm -rf /var/lib/apt/lists/*

# 拷贝 Stash 二进制
COPY --from=backend /stash/stash /usr/bin/stash

ENV STASH_CONFIG_FILE=/root/.stash/config.yml
EXPOSE 9999
ENTRYPOINT ["stash"]
