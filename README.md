# love-tools

CI/CD templates for [LÖVE](https://love2d.org) (Love2D/Lua) game
projects, in the same spirit as [tic80-tools](../tic80-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `love`, `web`, `export`, `watch`, `clean`) plus the
  Woodpecker pipeline targets (`ci-version`, `ci-export`, `ci-upload`,
  `ci-update`).
- `example-woodpecker.yaml` — Woodpecker pipeline: version → export
  (`.love` package + love.js web build) → upload (scp to the droparea)
  → update (calls the teletypegames `/update` endpoint with
  `platform=love`).
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run Löve** (`love .`, default build task,
  `Cmd+Shift+B`), **Build & Run Löve**, **Build .love package** and
  **Make build**.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (the package is built as `dist/$(PROJECT).love`).
2. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` and add the
   `droparea_ssh_password` / `update_secret_key` secrets in Woodpecker.
3. Copy `example-tasks.json` to `.vscode/tasks.json`.

The pipeline uploads `$(PROJECT)-$(VERSION).love.zip`,
`$(PROJECT)-$(VERSION).html.zip` and the versioned `metadata.json` to
the droparea, then triggers `/update` twice: once with `platform=love`
(desktop package) and once with `platform=love-web` (web build).

## Builder image

`builder.Dockerfile` bakes the pipeline's export-step dependencies
(zip/unzip/curl/make + `luac` for the syntax check) into
`git.teletype.hu/internal/love-builder`, and pre-fetches love.js to
`/opt/lovejs.zip` — the Makefile uses the cached copy when present
and only falls back to downloading from GitHub outside the image:

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletype.hu/internal/love-builder:latest .
docker push git.teletype.hu/internal/love-builder:latest
```

Rebuild the image to pick up a newer love.js snapshot.

Detailed documentation lives on the wiki: `/development/love`.
