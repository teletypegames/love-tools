# love-tools

CI/CD templates for [LÖVE](https://love2d.org) (Love2D/Lua) game
projects, in the same spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `love`, `web`, `export`, `binaries`, `watch`, `clean`)
  plus the Woodpecker pipeline targets (`ci-version`, `ci-export`,
  `ci-binaries`, `ci-upload`, `ci-publish`).
- `example-woodpecker.yaml` — Woodpecker pipeline: version → export
  (`.love` package + love.js web build) → binaries (fused desktop
  builds) → upload (HTTP POST to `/build/upload`) → update (calls the
  teletypegames `/build/publish` endpoint with `platform=love`).
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run Löve** (`love .`, default build task,
  `Cmd+Shift+B`), **Build & Run Löve**, **Build .love package** and
  **Make build**.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (the package is built as `dist/$(PROJECT).love`).
2. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` and add the
   `update_secret_key` secret in Woodpecker.
3. Copy `example-tasks.json` to `.vscode/tasks.json`.

The pipeline uploads `$(PROJECT)-$(VERSION).love.zip`,
`$(PROJECT)-$(VERSION).html.zip`, the versioned `metadata.json` and
the fused binary zips (`-win-x64.zip`, `-mac-universal.zip`,
`-linux-x64.zip`) via `/build/upload`, then triggers `/build/publish` twice: once
with `platform=love` (desktop package) and once with
`platform=love-web` (web build). The API's `BinaryAttachment` concern
picks up the `<name>-<version>-<slug>.zip` files automatically and
registers them as `win_x64` / `mac_universal` / `linux_x64` release
assets.

## Native (fused) binaries

`make binaries VERSION=x.y` builds desktop packages from the official
LÖVE $(LOVE_VERSION) release artifacts — no compilation involved:

- **win-x64** — `love.exe` + the `.love` concatenated (the standard
  LÖVE fusing mechanism), zipped together with the dlls.
- **mac-universal** — the `.love` dropped into the official
  `love.app` (a universal x86_64+arm64 bundle), `Info.plist` patched
  to the project name/identifier. Unsigned — Gatekeeper will warn on
  first launch.
- **linux-x64** — the official AppImage taken apart, the `.love`
  fused into `bin/love`, then reassembled. The AppImage runtime is
  glibc-linked and cannot be executed on alpine, so the Makefile
  computes the squashfs offset with `readelf` and repacks with
  `mksquashfs` instead of running `--appimage-extract`.

## Builder image

`builder.Dockerfile` bakes the pipeline's export-step dependencies
(zip/unzip/curl/make + `luac` for the syntax check, squashfs-tools +
binutils for the AppImage fusing) into
`git.teletypegames.org/internal/love-builder`, and pre-fetches love.js to
`/opt/lovejs.zip` plus the official LÖVE dist files to
`/opt/love-dist/` — the Makefile uses the cached copies when present
and only falls back to downloading from GitHub outside the image:

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletypegames.org/internal/love-builder:latest .
docker push git.teletypegames.org/internal/love-builder:latest
```

Rebuild the image to pick up a newer love.js snapshot or LÖVE
release (bump `LOVE_VERSION` in the Dockerfile and the Makefile
together).

Detailed documentation lives on the wiki: `/development/love`.
