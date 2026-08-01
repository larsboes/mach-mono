"""Shared Bazel constants for mach-mono.

Single source of truth for cross-target values like minimum OS versions.
Keep this file small — it's loaded by every BUILD.bazel that needs it.
"""

# Minimum macOS deployment target for all first-party Apple targets.
# Bumping this is a one-line change here; do not hardcode the value in BUILD files.
MINIMUM_MACOS_VERSION = "26.0"
