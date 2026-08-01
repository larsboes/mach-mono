#!/usr/bin/env bun
/**
 * stop-gate.ts — green-gate that runs the repo architecture checks when an agent
 * tries to finish, refusing to stop while violations exist.
 *
 * Wired to: Antigravity Stop and Claude Code Stop.
 *
 * Loop-safety (important): this gate intervenes AT MOST ONCE per run, so a failing
 * check can never lock an agent in an infinite stop→continue loop:
 *   - Claude: honor `stop_hook_active` — if the stop was already triggered by a hook,
 *     allow the stop.
 *   - Antigravity: only gate when `fullyIdle` is true, and bail if `executionNum` >= 2.
 *
 * Output:
 *   - Antigravity: {"decision":"continue","reason":...} to re-enter, else {"decision":"allow"}.
 *   - Claude: {"decision":"block","reason":...} to re-enter, else exit 0.
 */

import { platformOf, readInput, runArchCheck } from "./lib.ts";

const input = await readInput();
const platform = platformOf(input);

function allowStop(): never {
  if (platform === "antigravity") process.stdout.write(JSON.stringify({ decision: "allow" }));
  process.exit(0);
}

// ── loop guards ──────────────────────────────────────────────────────────────
if (platform === "claude" && input?.stop_hook_active === true) allowStop();
if (platform === "antigravity") {
  if (input?.fullyIdle === false) allowStop(); // background work still running
  if (typeof input?.executionNum === "number" && input.executionNum >= 2) allowStop();
}

const { ok, output } = runArchCheck();
if (ok) allowStop();

const reason =
  `Architecture checks must pass before finishing. Violations:\n${output}\n` +
  `Run \`bash .github/scripts/arch-check.sh\`, fix, and try again.`;

if (platform === "antigravity") {
  process.stdout.write(JSON.stringify({ decision: "continue", reason }));
  process.exit(0);
}
// Claude
process.stdout.write(JSON.stringify({ decision: "block", reason }));
process.exit(0);
