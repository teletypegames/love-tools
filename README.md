# love-tools

CI/CD templates for [LÖVE](https://love2d.org) (Love2D/Lua) game
projects, in the same spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `love`, `web`, `export`, `binaries`, `watch`, `clean`).
- `example-woodpecker.yaml` — a one-line marker (`platform: love`): the
  full pipeline (version → export → binaries → upload → publish) is served by the update server's Woodpecker
  configuration extension — preview it with
  `curl "https://teletypegames.org/build/config?platform=love"`.
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run Löve** (`love .`, default build task,
  `Cmd+Shift+B`), **Build & Run Löve**, **Build .love package** and
  **Make build**.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (the package is built as `dist/$(PROJECT).love`).
2. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` (a one-line marker — the
   pipeline itself is served by the update server; add `name:` when the
   software name differs from the repo name) and add the
   `application_token` secret in Woodpecker (an ApplicationToken with
   the `update` + `upload` scopes, created in the admin).
3. Copy `example-tasks.json` to `.vscode/tasks.json`.

The served pipeline uploads `$(PROJECT)-$(VERSION).love.zip`,
`$(PROJECT)-$(VERSION).html.zip`, the versioned `metadata.json` and
the fused binary zips (`-win-x64.zip`, `-mac-universal.zip`,
`-linux-x64.zip`) via `/build/upload`, then triggers `/build/publish`
with `platform=love`. The API's `BinaryAttachment` concern picks up
the `<name>-<version>-<slug>.zip` files automatically and registers
them as `win_x64` / `mac_universal` / `linux_x64` release assets.

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
`git.teletypegames.org/build/love-builder`, and pre-fetches love.js to
`/opt/lovejs.zip` plus the official LÖVE dist files to
`/opt/love-dist/` — the Makefile uses the cached copies when present
and only falls back to downloading from GitHub outside the image:

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletypegames.org/build/love-builder:latest .
docker push git.teletypegames.org/build/love-builder:latest
```

Rebuild the image to pick up a newer love.js snapshot or LÖVE
release (bump `LOVE_VERSION` in the Dockerfile and the Makefile
together).

Detailed documentation lives on the wiki: `/development/love`.
