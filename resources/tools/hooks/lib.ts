/**
 * lib.ts — shared helpers for dual-platform agent hooks (Antigravity + Claude Code).
 *
 * Antigravity and Claude Code drive hooks with DIFFERENT stdin/stdout contracts:
 *   - Antigravity (hooks.json): PreToolUse stdin has { toolCall: { name, args } };
 *     decisions returned as JSON { decision, reason }.
 *   - Claude Code (settings.json): PreToolUse stdin has { tool_name, tool_input };
 *     a block is signalled by exit code 2 with the reason on stderr.
 *
 * These helpers detect the platform from the payload shape and expose a single
 * API so each hook script stays platform-agnostic.
 */

import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";

export type Platform = "antigravity" | "claude" | "unknown";

/** Repo root: this file lives at <root>/resources/tools/hooks/lib.ts. */
export const REPO_ROOT = dirname(dirname(import.meta.dir));

/** Read the full stdin payload and JSON-parse it; {} when empty/unparseable. */
export async function readInput(): Promise<any> {
  try {
    const text = await Bun.stdin.text();
    return text.trim() ? JSON.parse(text) : {};
  } catch {
    return {};
  }
}

export function platformOf(input: any): Platform {
  if (input == null || typeof input !== "object") return "unknown";
  if ("toolCall" in input || "terminationReason" in input || "stepIdx" in input) {
    return "antigravity";
  }
  if (
    "tool_name" in input ||
    "hook_event_name" in input ||
    "stop_hook_active" in input ||
    "session_id" in input
  ) {
    return "claude";
  }
  return "unknown";
}

/** The shell command a PreToolUse hook is gating, or null. */
export function getCommand(input: any): string | null {
  return input?.toolCall?.args?.CommandLine ?? input?.tool_input?.command ?? null;
}

/** The file path a PostToolUse write touched (Claude only — AG omits args). */
export function getWrittenPath(input: any): string | null {
  return input?.tool_input?.file_path ?? input?.tool_input?.TargetFile ?? null;
}

/** Run the repo's architecture check. Fast (grep-based, no Xcode). */
export function runArchCheck(): { ok: boolean; output: string } {
  const script = join(REPO_ROOT, ".github", "scripts", "arch-check.sh");
  if (!existsSync(script)) return { ok: true, output: "" };
  try {
    const out = execFileSync("bash", [script], { cwd: REPO_ROOT, encoding: "utf8" });
    return { ok: true, output: out };
  } catch (e: any) {
    const out = [e?.stdout, e?.stderr].filter(Boolean).join("\n");
    // surface only the FAIL: lines to keep feedback tight
    const fails = out
      .split("\n")
      .filter((l: string) => l.includes("FAIL:") || l.includes("FAILED:"))
      .join("\n");
    return { ok: false, output: fails || out };
  }
}

/** Emit a PreToolUse allow and exit. */
export function allowAndExit(platform: Platform): never {
  if (platform === "antigravity") process.stdout.write(JSON.stringify({ decision: "allow" }));
  process.exit(0);
}

/** Emit a PreToolUse deny (AG: JSON+exit0, Claude: stderr+exit2) and exit. */
export function denyAndExit(platform: Platform, reason: string): never {
  if (platform === "antigravity") {
    process.stdout.write(JSON.stringify({ decision: "deny", reason }));
    process.exit(0);
  }
  process.stderr.write(reason + "\n");
  process.exit(2);
}
