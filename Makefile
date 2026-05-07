CERT          := Apple Development: ilars.boes@gmail.com (SVHPB8QYPH)
DEST          := $(HOME)/Applications/machNotch.app
BAZEL_APP     := $(shell find bazel-out -name "machNotch.app" -type d 2>/dev/null | grep "archive-root" | head -1)

.PHONY: run build install kill

## Build, sign with dev cert, install to ~/Applications, launch.
## Run this instead of opening bazel-out directly — permissions persist across rebuilds.
run: build install kill
	open "$(DEST)"
	@echo "✓ machNotch launched from $(DEST)"

build:
	bazelisk build //Apps/machNotch:machNotch

install: build
	$(eval APP := $(shell find bazel-out -name "machNotch.app" -type d 2>/dev/null | grep "archive-root" | head -1))
	@test -n "$(APP)" || (echo "ERROR: could not find built machNotch.app in bazel-out" && exit 1)
	@mkdir -p "$(HOME)/Applications"
	rm -rf "$(DEST)"
	cp -R "$(APP)" "$(DEST)"
	codesign --force --deep --sign "$(CERT)" "$(DEST)"
	@echo "✓ Installed and signed at $(DEST)"

kill:
	-pkill -x machNotch 2>/dev/null || true
