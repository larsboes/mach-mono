#!/usr/bin/env bun
/**
 * swift-archcheck.ts — PostToolUse check that runs the repo architecture checks
 * after a Swift file is written, surfacing violations back to the agent immediately.
 *
 * Wired to: Claude Code PostToolUse matcher "Write|Edit" (Claude passes the written
 * file path; Antigravity's PostToolUse omits args and cannot inject feedback, so the
 * Antigravity equivalent is enforced by the Stop green-gate instead).
 *
 * Exit 0 = clean / not a Swift file. Exit 2 + stderr = violations (Claude feeds the
 * stderr back into the conversation).
 */

import { getWrittenPath, platformOf, readInput, runArchCheck } from "./lib.ts";

const input = await readInput();

// Claude-only by design; bail quietly on anything else.
if (platformOf(input) !== "claude") process.exit(0);

const path = getWrittenPath(input);
if (!path || !path.endsWith(".swift")) process.exit(0);

const { ok, output } = runArchCheck();
if (ok) process.exit(0);

process.stderr.write(
  `Architecture check failed after editing ${path}:\n${output}\n` +
    `Fix these before continuing (see .claude/skills/swift-code-quality).\n`,
);
process.exit(2);
