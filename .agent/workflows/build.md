---
description: Build and verify the machNotch project
---

# Build Project

Build the project using Xcode command line tools.

## Steps

// turbo
1. Build the project:
```bash
xcodebuild -project Apps/machNotch/machNotch.xcodeproj -scheme machNotch -destination 'platform=macOS' build 2>&1 | head -100
```

## Notes
- Build logs are ignored by git (see `.gitignore`)
- For full output, redirect to a file: `> build_log.txt 2>&1`
