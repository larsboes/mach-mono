#!/usr/bin/env bun
/**
 * command-gate.ts — PreToolUse gate enforcing this repo's command conventions.
 *
 * Wired to:
 *   - Antigravity: PreToolUse matcher "run_command"
 *   - Claude Code: PreToolUse matcher "Bash"
 *
 * Denies a small, unambiguous blocklist; everything else is allowed. Edit
 * BLOCKLIST to adjust. Default-allow keeps the gate non-intrusive.
 */

import { allowAndExit, denyAndExit, getCommand, platformOf, readInput } from "./lib.ts";

const BLOCKLIST: { re: RegExp; reason: string }[] = [
  {
    re: /\bxcodebuild\b/,
    reason: "Blocked: don't build from Xcode. Use Bazel — `bazelisk build //Apps/...`. (repo.yaml)",
  },
  {
    re: /(^|\s)(npm|npx|yarn|pnpm)(\s|$)/,
    reason: "Blocked: this is a bun-only repo with no Node package. Use `bun` / `bunx`.",
  },
];

const input = await readInput();
const platform = platformOf(input);
const command = getCommand(input);

if (!command) allowAndExit(platform);

for (const rule of BLOCKLIST) {
  if (rule.re.test(command!)) denyAndExit(platform, rule.reason);
}

allowAndExit(platform);
