# -----------------------------------------
# Makefile – Love2D project builder
# -----------------------------------------

PROJECT = love2ddemo

BIN_DIR     = bin
DIST_DIR    = dist
WEB_DIR     = $(DIST_DIR)/web
LOVE_NAME   = $(PROJECT).love
OUTPUT_LOVE = $(DIST_DIR)/$(LOVE_NAME)
OUTPUT_ZIP      = $(PROJECT)-$(VERSION).love.zip
OUTPUT_WEB_ZIP  = $(PROJECT)-$(VERSION).html.zip

VERSION_FILE = .version

# The love-builder CI image pre-fetches love.js here; local builds fall
# back to downloading it from GitHub.
LOVEJS_URL   = https://github.com/2dengine/love.js/archive/refs/heads/master.zip
LOVEJS_CACHE = /opt/lovejs.zip

all: build

build:
	@mkdir -p $(BIN_DIR)
	@echo "==> Checking Love2D syntax"
	luac -p *.lua 2>/dev/null || true

love:
	@mkdir -p $(DIST_DIR)
	@echo "==> Building .love package"
	zip -r $(OUTPUT_LOVE) . \
		--exclude "*.git*" \
		--exclude "$(BIN_DIR)/*" \
		--exclude "$(DIST_DIR)/*" \
		--exclude "Makefile" \
		--exclude ".version" \
		--exclude "metadata.json" \
		--exclude "*.zip"

web: love
	@mkdir -p $(WEB_DIR)
	@if [ -f $(LOVEJS_CACHE) ]; then \
		echo "==> Using cached love.js ($(LOVEJS_CACHE))"; \
		cp $(LOVEJS_CACHE) $(DIST_DIR)/lovejs.zip; \
	else \
		echo "==> Downloading love.js (2dengine)"; \
		curl -sSL $(LOVEJS_URL) -o $(DIST_DIR)/lovejs.zip; \
	fi
	unzip -o $(DIST_DIR)/lovejs.zip -d $(DIST_DIR)/lovejs-src
	rm -f $(DIST_DIR)/lovejs.zip
	@echo "==> Assembling web bundle"
	cp -r $(DIST_DIR)/lovejs-src/*/. $(WEB_DIR)/
	rm -rf $(DIST_DIR)/lovejs-src
	cp $(OUTPUT_LOVE) $(WEB_DIR)/$(LOVE_NAME)
	@echo "==> Patching player.js"
	sed -i.bak "s|uri = 'nogame\.love'|uri = '$(LOVE_NAME)'|g" $(WEB_DIR)/player.js && rm $(WEB_DIR)/player.js.bak
	@echo "==> Patching index.html"
	sed -i.bak 's|<base href="/play/">|<base href="/file/$(PROJECT)-$(VERSION)/">|g' $(WEB_DIR)/index.html && rm $(WEB_DIR)/index.html.bak
	@echo "==> Web build ready in $(WEB_DIR)"

export: love web
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@echo "==> Packaging Love2D for $(VERSION)"
	zip -r $(OUTPUT_ZIP) $(OUTPUT_LOVE)
	@echo "==> Packaging web build for $(VERSION)"
	cd $(WEB_DIR) && zip -r ../../$(OUTPUT_WEB_ZIP) .
	@echo "==> Cleaning temporary files"
	rm -f $(OUTPUT_LOVE)
	rm -rf $(WEB_DIR)

watch:
	fswatch -o . --include="\.lua$$" | while read; do make build; done

clean:
	rm -rf $(BIN_DIR) $(DIST_DIR)

ci-version:
	@if [ -f metadata.json ]; then \
		VERSION=$$(jq -r '.version' metadata.json); \
	else \
		VERSION=$$(git rev-parse --short HEAD); \
	fi; \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ]; then \
		VERSION="dev-$$VERSION-$$BRANCH"; \
	fi; \
	echo $$VERSION > $(VERSION_FILE)

ci-export:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) export VERSION=$$VERSION

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	FILE_LOVE="$(PROJECT)-$$VERSION.love.zip"; \
	FILE_WEB="$(PROJECT)-$$VERSION.html.zip"; \
	META_SRC="metadata.json"; \
	META_DST="$(PROJECT)-$$VERSION.metadata.json"; \
	cp $$META_SRC $$META_DST; \
	sshpass -p "$(DROPAREA_SSH_PASSWORD)" scp -o StrictHostKeyChecking=no -P $(DROPAREA_PORT) \
		$$FILE_LOVE $$FILE_WEB $$META_DST \
		$(DROPAREA_USER)@$(DROPAREA_HOST):$(DROPAREA_TARGET_PATH)/

ci-update:
	@VERSION=$$(cat $(VERSION_FILE)); \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=love&version=$$VERSION"; \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=love-web&version=$$VERSION"

.PHONY: all build love web export watch clean ci-version ci-export ci-upload ci-update