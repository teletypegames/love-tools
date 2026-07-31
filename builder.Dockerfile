# CI builder image for Love2D projects: packaging tools + luac syntax check,
# with love.js pre-fetched to /opt/lovejs.zip so `make web` does not hit
# GitHub on every pipeline run (the Makefile falls back to curl elsewhere).
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f builder.Dockerfile \
#     -t git.teletype.hu/internal/love-builder:latest .
#   docker push git.teletype.hu/internal/love-builder:latest

FROM alpine:3.22

RUN apk add --no-cache make zip unzip curl git lua5.4 \
 && ln -sf /usr/bin/lua5.4 /usr/bin/lua \
 && ln -sf /usr/bin/luac5.4 /usr/bin/luac

RUN curl -sSL https://github.com/2dengine/love.js/archive/refs/heads/master.zip \
      -o /opt/lovejs.zip

WORKDIR /workspace

CMD ["/bin/sh"]
