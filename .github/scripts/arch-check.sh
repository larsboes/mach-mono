#!/usr/bin/env bash
# Architecture checks — enforces project conventions from CLAUDE.md
# Runs on Ubuntu (no Xcode needed), catches violations before build.

set -euo pipefail

ERRORS=0
SRC="boringNotch"

echo "=== Architecture Check ==="
echo ""

# --- 1. Files over 300 lines (excluding known exception) ---
echo "--- Checking file length (max 300 lines) ---"
while IFS= read -r file; do
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 300 ]; then
        basename=$(basename "$file")
        if [ "$basename" = "DefaultsNotchSettings.swift" ]; then
            continue  # Intentional exception
        fi
        echo "FAIL: $file ($lines lines, max 300)"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find "$SRC" -name '*.swift' -type f)

# --- 2. Direct Defaults[ access outside allowed files ---
echo "--- Checking Defaults[ access ---"
ALLOWED_DEFAULTS=(
    "DefaultsNotchSettings.swift"
    "DefaultsNotchSettings+HUD.swift"
    "DefaultsNotchSettings+Display.swift"
    "DefaultsNotchSettings+Music.swift"
    "DefaultsNotchSettings+Plugins.swift"
    "PluginSettings.swift"
    "matters.swift"          # intentional write-back
    "WeatherService.swift"   # API key access
    "CalendarService.swift"  # calendar selection state
    "DefaultsKeys.swift"     # key definitions
    "NavigationState.swift"  # Defaults.updates() — accepted exception
)

while IFS= read -r file; do
    basename=$(basename "$file")
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
done < <(grep -rl 'Defaults\[' "$SRC" --include='*.swift' || true)

# --- 3. @Default property wrapper (banned) ---
echo "--- Checking @Default property wrapper ---"
while IFS= read -r file; do
    echo "FAIL: $file uses @Default property wrapper"
    ERRORS=$((ERRORS + 1))
done < <(grep -rl '@Default(' "$SRC" --include='*.swift' || true)

# --- 4. ObservableObject / @Published (banned) ---
echo "--- Checking ObservableObject / @Published ---"
while IFS= read -r file; do
    # Exclude protocol definitions and comments
    if grep -q 'ObservableObject' "$file" && ! grep -q '// legacy' "$file"; then
        echo "FAIL: $file uses ObservableObject"
        ERRORS=$((ERRORS + 1))
    fi
done < <(grep -rl 'ObservableObject' "$SRC" --include='*.swift' || true)

while IFS= read -r file; do
    echo "FAIL: $file uses @Published"
    ERRORS=$((ERRORS + 1))
done < <(grep -rl '@Published ' "$SRC" --include='*.swift' || true)

# --- 5. Banned .shared singletons (custom ones only) ---
echo "--- Checking banned .shared singletons ---"
# These are system/allowed singletons — not flagged
ALLOWED_SHARED='NSWorkspace\.shared|NSApplication\.shared|URLSession\.shared|URLCache\.shared|XPCHelperClient\.shared|FullScreenMonitor\.shared|QLThumbnailGenerator\.shared|QLPreviewPanel\.shared|NSScreenUUIDCache\.shared|SkyLightOperator\.shared|DefaultsNotchSettings\.shared|ProcessInfo\.shared|NSColorSpace\.shared|UNUserNotificationCenter\.shared|CBCentralManager|FileManager\.shared|UserDefaults\.shared|NotificationCenter\.shared|NSPasteboard\.shared|NSSpeechSynthesizer\.shared|DistributedNotificationCenter\.shared|MTLCreateSystemDefaultDevice|CIContext\.shared'

SHARED_HITS=$(grep -rn '\.shared' "$SRC" --include='*.swift' \
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
FORCE_UNWRAP_HITS=$(grep -rnE 'pluginManager!|services!' "$SRC/Core" "$SRC/ContentView.swift" "$SRC/ContentView+Appearance.swift" \
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
