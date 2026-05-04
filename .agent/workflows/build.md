---
description: Build and verify the machNotch project
---

# Build Project

Build the project using Xcode command line tools.

## Steps

1. Build the project:
```bash
xcodebuild -workspace mach-mono.xcworkspace -scheme machNotch -destination 'platform=macOS' build 2>&1 | head -100
```

## Notes
- Canonical `xcodebuild` line: see `repo.yaml` → `policies.build_verification.command`.
- Build logs are ignored by git (see `.gitignore`)
- For full output, redirect to a file: `> build_log.txt 2>&1`
