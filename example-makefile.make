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

# -----------------------------------------
# Native (fused) binaries from the official LÖVE releases.
# The love-builder CI image pre-fetches the dist files to /opt/love-dist;
# local builds fall back to downloading them from GitHub.
# win: love.exe + .love concatenated; mac: .love dropped into the
# official (universal) love.app; linux: the official AppImage taken
# apart, the .love fused into bin/love, then reassembled with
# mksquashfs (squashfs-tools required).
# -----------------------------------------

LOVE_VERSION   = 11.5
LOVE_BASE_URL  = https://github.com/love2d/love/releases/download/$(LOVE_VERSION)
LOVE_CACHE_DIR = /opt/love-dist

BINARY_SLUGS = win-x64 mac-universal linux-x64

# $(1) dist file name
define f_fetch_love
	mkdir -p $(DIST_DIR); \
	if [ -f "$(LOVE_CACHE_DIR)/$(1)" ]; then \
		echo "==> Using cached $(1)"; \
		cp "$(LOVE_CACHE_DIR)/$(1)" "$(DIST_DIR)/$(1)"; \
	elif [ ! -f "$(DIST_DIR)/$(1)" ]; then \
		echo "==> Downloading $(1)"; \
		curl -sSL "$(LOVE_BASE_URL)/$(1)" -o "$(DIST_DIR)/$(1)"; \
	fi
endef

binaries:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@$(MAKE) binary-win binary-mac binary-linux VERSION=$(VERSION)

binary-win: love
	@echo "==> Fusing windows binary"
	@$(call f_fetch_love,love-$(LOVE_VERSION)-win64.zip)
	@set -e; \
	PKG_DIR="$(PROJECT)-$(VERSION)-win-x64"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip" $(DIST_DIR)/win64; \
	unzip -q $(DIST_DIR)/love-$(LOVE_VERSION)-win64.zip -d $(DIST_DIR)/win64; \
	SRC=$$(dirname $$(find $(DIST_DIR)/win64 -name love.exe | head -n 1)); \
	mkdir -p "$$PKG_DIR"; \
	cat "$$SRC/love.exe" $(OUTPUT_LOVE) > "$$PKG_DIR/$(PROJECT).exe"; \
	cp "$$SRC"/*.dll "$$PKG_DIR/"; \
	cp "$$SRC/license.txt" "$$PKG_DIR/" 2>/dev/null || true; \
	zip -qr "$$PKG_DIR.zip" "$$PKG_DIR"; \
	rm -rf "$$PKG_DIR" $(DIST_DIR)/win64; \
	echo "==> $$PKG_DIR.zip kesz"

binary-mac: love
	@echo "==> Fusing macOS app bundle"
	@$(call f_fetch_love,love-$(LOVE_VERSION)-macos.zip)
	@set -e; \
	PKG_DIR="$(PROJECT)-$(VERSION)-mac-universal"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip" $(DIST_DIR)/macos; \
	unzip -q $(DIST_DIR)/love-$(LOVE_VERSION)-macos.zip -d $(DIST_DIR)/macos; \
	mkdir -p "$$PKG_DIR"; \
	mv $(DIST_DIR)/macos/love.app "$$PKG_DIR/$(PROJECT).app"; \
	cp $(OUTPUT_LOVE) "$$PKG_DIR/$(PROJECT).app/Contents/Resources/"; \
	PLIST="$$PKG_DIR/$(PROJECT).app/Contents/Info.plist"; \
	sed -i.bak "s|<string>LÖVE</string>|<string>$(PROJECT)</string>|g" "$$PLIST" && rm "$$PLIST.bak"; \
	sed -i.bak "s|org\.love2d\.love|org.teletypegames.$(PROJECT)|g" "$$PLIST" && rm "$$PLIST.bak"; \
	zip -qry "$$PKG_DIR.zip" "$$PKG_DIR"; \
	rm -rf "$$PKG_DIR" $(DIST_DIR)/macos; \
	echo "==> $$PKG_DIR.zip kesz"

# Az AppImage runtime glibc-dinamikus, alpine (musl) alatt nem futtatható,
# ezért nem a runtime-ot futtatjuk: az offsetet readelf-ből számoljuk
# (shoff + shentsize*shnum), a squashfs-t unsquashfs -o bontja ki.
binary-linux: love
	@echo "==> Fusing linux AppImage"
	@$(call f_fetch_love,love-$(LOVE_VERSION)-x86_64.AppImage)
	@set -e; \
	PKG_DIR="$(PROJECT)-$(VERSION)-linux-x64"; \
	APPIMAGE="$(DIST_DIR)/love-$(LOVE_VERSION)-x86_64.AppImage"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip" squashfs-root $(DIST_DIR)/game.squashfs $(DIST_DIR)/runtime; \
	OFFSET=$$(readelf -h "$$APPIMAGE" | awk '/Start of section headers/{o=$$5} /Size of section headers/{s=$$5} /Number of section headers/{n=$$5} END{print o+s*n}'); \
	unsquashfs -q -o $$OFFSET -d squashfs-root "$$APPIMAGE" >/dev/null; \
	cat squashfs-root/bin/love $(OUTPUT_LOVE) > squashfs-root/bin/love.fused; \
	mv squashfs-root/bin/love.fused squashfs-root/bin/love; \
	chmod +x squashfs-root/bin/love; \
	mksquashfs squashfs-root $(DIST_DIR)/game.squashfs -root-owned -noappend -quiet -comp gzip; \
	head -c $$OFFSET "$$APPIMAGE" > $(DIST_DIR)/runtime; \
	mkdir -p "$$PKG_DIR"; \
	cat $(DIST_DIR)/runtime $(DIST_DIR)/game.squashfs > "$$PKG_DIR/$(PROJECT).AppImage"; \
	chmod +x "$$PKG_DIR/$(PROJECT).AppImage"; \
	zip -qr "$$PKG_DIR.zip" "$$PKG_DIR"; \
	rm -rf "$$PKG_DIR" squashfs-root $(DIST_DIR)/game.squashfs $(DIST_DIR)/runtime; \
	echo "==> $$PKG_DIR.zip kesz"

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

ci-binaries:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) binaries VERSION=$$VERSION

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	FILE_LOVE="$(PROJECT)-$$VERSION.love.zip"; \
	FILE_WEB="$(PROJECT)-$$VERSION.html.zip"; \
	META_SRC="metadata.json"; \
	META_DST="$(PROJECT)-$$VERSION.metadata.json"; \
	cp $$META_SRC $$META_DST; \
	BINS=""; \
	for slug in $(BINARY_SLUGS); do \
		[ -f "$(PROJECT)-$$VERSION-$$slug.zip" ] && BINS="$$BINS $(PROJECT)-$$VERSION-$$slug.zip"; \
	done; \
	sshpass -p "$(DROPAREA_SSH_PASSWORD)" scp -o StrictHostKeyChecking=no -P $(DROPAREA_PORT) \
		$$FILE_LOVE $$FILE_WEB $$META_DST $$BINS \
		$(DROPAREA_USER)@$(DROPAREA_HOST):$(DROPAREA_TARGET_PATH)/

ci-update:
	@VERSION=$$(cat $(VERSION_FILE)); \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=love&version=$$VERSION"; \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=love-web&version=$$VERSION"

.PHONY: all build love web export binaries binary-win binary-mac binary-linux watch clean ci-version ci-export ci-binaries ci-upload ci-update