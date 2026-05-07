CERT     := Apple Development: ilars.boes@gmail.com (SVHPB8QYPH)
DEST     := $(HOME)/Applications/machNotch.app
ZIP      := bazel-bin/Apps/machNotch/machNotch.zip
UNZIP_TMP := /tmp/machNotch-install

.PHONY: run build install kill

## Build, sign with dev cert, install to ~/Applications, launch.
## Permissions persist across rebuilds because team_id stays constant.
run: install kill
	open "$(DEST)"
	@echo "✓ machNotch launched from $(DEST)"

build:
	bazelisk build //Apps/machNotch:machNotch

install: build
	@test -f "$(ZIP)" || (echo "ERROR: $(ZIP) not found — run 'make build' first" && exit 1)
	@mkdir -p "$(HOME)/Applications"
	rm -rf "$(DEST)" "$(UNZIP_TMP)"
	mkdir -p "$(UNZIP_TMP)"
	unzip -q "$(ZIP)" -d "$(UNZIP_TMP)"
	mv "$(UNZIP_TMP)/machNotch.app" "$(DEST)"
	rm -rf "$(UNZIP_TMP)"
	codesign --force --deep --sign "$(CERT)" "$(DEST)"
	@echo "✓ Installed and signed at $(DEST)"

kill:
	-pkill -x machNotch 2>/dev/null || true
