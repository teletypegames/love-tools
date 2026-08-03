# CI builder image for Love2D projects: packaging tools + luac syntax check,
# with love.js and the official LÖVE dist files pre-fetched so the pipeline
# does not hit GitHub on every run (the Makefile falls back to curl elsewhere).
#
# squashfs-tools + binutils are needed for the linux AppImage fusing:
# the AppImage runtime is glibc-linked so it cannot be executed on alpine —
# the Makefile computes the squashfs offset with readelf and repacks with
# mksquashfs instead.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f builder.Dockerfile \
#     -t git.teletypegames.org/internal/love-builder:latest .
#   docker push git.teletypegames.org/internal/love-builder:latest

FROM alpine:3.22

ARG LOVE_VERSION=11.5

RUN apk add --no-cache make zip unzip curl git lua5.4 squashfs-tools binutils \
 && ln -sf /usr/bin/lua5.4 /usr/bin/lua \
 && ln -sf /usr/bin/luac5.4 /usr/bin/luac

RUN curl -sSL https://github.com/2dengine/love.js/archive/refs/heads/master.zip \
      -o /opt/lovejs.zip

RUN mkdir -p /opt/love-dist \
 && cd /opt/love-dist \
 && curl -sSLO https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-win64.zip \
 && curl -sSLO https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-macos.zip \
 && curl -sSLO https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-x86_64.AppImage

WORKDIR /workspace

CMD ["/bin/sh"]
