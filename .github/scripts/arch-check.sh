#!/usr/bin/env bash
# Architecture checks — enforces project conventions from CLAUDE.md
# Runs on Ubuntu (no Xcode needed), catches violations before build.

set -euo pipefail

ERRORS=0

# Define source directories to scan, including both the main app and package sources.
SRC_DIRS=( "Apps/machNotch/machNotch" )
for dir in Packages/*/Sources; do
    if [ -d "$dir" ]; then
        SRC_DIRS+=("$dir")
    fi
done

echo "=== Architecture Check ==="
echo ""

# Fail loudly if any expected source tree is missing
for dir in "${SRC_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "FAIL: source directory '$dir' not found (run from repo root)"
        exit 1
    fi
done

SWIFT_FILE_COUNT=$(find "${SRC_DIRS[@]}" -name '*.swift' -type f | wc -l | tr -d ' ')
if [ "$SWIFT_FILE_COUNT" -eq 0 ]; then
    echo "FAIL: no Swift files found under source directories"
    exit 1
fi
echo "Scanning $SWIFT_FILE_COUNT Swift files under ${SRC_DIRS[*]}"
echo ""

# --- 1. Files over 300 lines (excluding known exceptions) ---
FILE_LENGTH_EXCEPTIONS=(
    "DefaultsNotchSettings.swift"       # intentional: settings store
    "AppObjectGraph.swift"              # TODO: extract service wiring helpers
    "MediaKeyInterceptor.swift"         # TODO: split CGEventTap setup from dispatch
    "NotchWeather.swift"                # TODO: extract row/icon subviews
    "PluginEventBus.swift"              # legacy: custom event bus implementation
    "SystemStatsServiceProtocol.swift"  # legacy: system statistics definitions
    "FluidSimulationEngine.swift"       # intentional: GPU fluid simulation engine
    "SoundscapePlugin.swift"            # intentional: soundscape plugin core implementation
)
echo "--- Checking file length (max 300 lines) ---"
while IFS= read -r file; do
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 300 ]; then
        basename=$(basename "$file")
        skip=false
        for a in "${FILE_LENGTH_EXCEPTIONS[@]}"; do
            if [ "$basename" = "$a" ]; then
                skip=true
                break
            fi
        done
        if [ "$skip" = true ]; then
            continue
        fi
        echo "FAIL: $file ($lines lines, max 300)"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find "${SRC_DIRS[@]}" -name '*.swift' -type f)

# --- 2. Direct Defaults[ access outside allowed files ---
echo "--- Checking Defaults[ access ---"
ALLOWED_DEFAULTS=(
    "PluginSettings.swift"
    "matters.swift"          # intentional write-back
    "WeatherService.swift"   # API key access
    "CalendarService.swift"  # calendar selection state
    "DefaultsKeys.swift"     # key definitions
    "NavigationState.swift"  # Defaults.updates() — accepted exception
    "NotesManager.swift"     # TODO: refactor to use settings injection
)

while IFS= read -r file; do
    basename=$(basename "$file")
    # All DefaultsNotchSettings (+ its extensions) are the wrapper itself by design.
    case "$basename" in
        DefaultsNotchSettings.swift|DefaultsNotchSettings+*.swift)
            continue
            ;;
    esac
    allowed=false
    for a in "${ALLOWED_DEFAULTS[@]}"; do
        if [ "$basename" = "$a" ]; then
            allowed=true
            break
        fi
    done
    if [ "$allowed" = false ]; then
        echo "FAIL: $file has direct Defaults[ access"
        ERRORS=$((ERRORS + 1))
    fi
done < <(grep -rl 'Defaults\[' "${SRC_DIRS[@]}" --include='*.swift' || true)

# --- 3. @Default property wrapper (banned) ---
echo "--- Checking @Default property wrapper ---"
while IFS= read -r file; do
    echo "FAIL: $file uses @Default property wrapper"
    ERRORS=$((ERRORS + 1))
done < <(grep -rl '@Default(' "${SRC_DIRS[@]}" --include='*.swift' || true)

# --- 4. ObservableObject / @Published (banned) ---
echo "--- Checking ObservableObject / @Published ---"
while IFS= read -r file; do
    # Exclude protocol definitions and comments
    if grep -q 'ObservableObject' "$file" && ! grep -q '// legacy' "$file"; then
        echo "FAIL: $file uses ObservableObject"
        ERRORS=$((ERRORS + 1))
    fi
done < <(grep -rl 'ObservableObject' "${SRC_DIRS[@]}" --include='*.swift' || true)

while IFS= read -r file; do
    echo "FAIL: $file uses @Published"
    ERRORS=$((ERRORS + 1))
done < <(grep -rlE '@Published\b' "${SRC_DIRS[@]}" --include='*.swift' || true)

# --- 5. Banned .shared singletons (custom ones only) ---
echo "--- Checking banned .shared singletons ---"
# These are system/allowed singletons — not flagged
ALLOWED_SHARED='NSWorkspace\.shared|NSApplication\.shared|URLSession\.shared|URLCache\.shared|XPCHelperClient\.shared|FullScreenMonitor\.shared|QLThumbnailGenerator\.shared|QLPreviewPanel\.shared|NSScreenUUIDCache\.shared|SkyLightOperator\.shared|DefaultsNotchSettings\.shared|ProcessInfo\.shared|NSColorSpace\.shared|UNUserNotificationCenter\.shared|CBCentralManager|FileManager\.shared|UserDefaults\.shared|NotificationCenter\.shared|NSPasteboard\.shared|NSSpeechSynthesizer\.shared|DistributedNotificationCenter\.shared|MTLCreateSystemDefaultDevice|CIContext\.shared|ScreenDisplayRegistry\.shared|NSAppleEventManager\.shared|WeatherKit\.WeatherService\.shared|BrowserExtensionServer\.shared|DictionaryEntryCache\.shared'

SHARED_HITS=$(grep -rn '\.shared' "${SRC_DIRS[@]}" --include='*.swift' \
    | grep -v '// ' \
    | grep -v 'func shared' \
    | grep -v 'var shared' \
    | grep -v 'protocol ' \
    | grep -v '= \.shared' \
    | grep -Ev "$ALLOWED_SHARED" \
    || true)

if [ -n "$SHARED_HITS" ]; then
    while IFS= read -r line; do
        echo "WARN: potential banned .shared — $line"
    done <<< "$SHARED_HITS"
    echo "(Review warnings above — false positives possible)"
fi

# --- 6. Force unwraps in core runtime code ---
echo "--- Checking force unwraps in core runtime code ---"
FORCE_UNWRAP_HITS=$(grep -rnE 'pluginManager!|services!' "Apps/machNotch/machNotch/Core" "Apps/machNotch/machNotch/ContentView.swift" "Apps/machNotch/machNotch/ContentView+Appearance.swift" \
    --include='*.swift' \
    || true)

if [ -n "$FORCE_UNWRAP_HITS" ]; then
    while IFS= read -r line; do
        echo "FAIL: force unwrap found — $line"
        ERRORS=$((ERRORS + 1))
    done <<< "$FORCE_UNWRAP_HITS"
fi

# --- Summary ---
echo ""
echo "=== Results ==="
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS violation(s) found"
    exit 1
else
    echo "PASSED: All architecture checks passed"
fi
