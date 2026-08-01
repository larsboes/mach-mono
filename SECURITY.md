# Security Policy

This project includes local services (HTTP/WebSocket/local API) and macOS automation paths. Security issues are handled via GitHub's standard channels.

## Supported versions

- macOS 26+ for development and local runtime.
- Main branch is the only supported branch for security fixes.

## Reporting a security issue

If you discover a vulnerability:

1. **Use private reporting first** via GitHub Security Advisories:
   https://github.com/larsboes/mach-mono/security/advisories/new
2. If a private advisory is not available, open a GitHub issue and add the `security` label.

Please include:

- Exact build/runtime details (OS version, commit SHA, affected target).
- The attack scenario and reproducible steps.
- Whether the issue affects signed binaries, local API, or local data handling.

## Local security hygiene

- Keep Apple signing certificates and macOS automation permissions to the minimum set required.
- Review plugin/feature permissions against runtime needs.
- When sharing logs, remove machine identifiers and local paths.

