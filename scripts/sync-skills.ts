#!/usr/bin/env bun
/**
 * sync-skills.ts — bidirectional skill mirror between Claude Code and Antigravity.
 *
 *   Claude side:      .claude/skills/<name>/SKILL.md   (superset frontmatter)
 *   Antigravity side: .agents/skills/<name>/SKILL.md   (name + description projection)
 *
 * Model: Claude's SKILL.md is the SUPERSET (keeps user-invocable, paths,
 * argument-hint, disable-model-invocation, comment lines, …). Antigravity's is a
 * PROJECTION (only `name` + `description` + body). Sync therefore is asymmetric:
 *   - Claude → Antigravity: emit name+description only, copy body verbatim.
 *   - Antigravity → Claude: MERGE — keep all existing Claude-only fields, update
 *     only name/description/body.
 *
 * Change detection: a committed state file (scripts/skill-sync-state.json) stores,
 * per skill, the hash of the shared projection (name+description+body, comments and
 * extra frontmatter excluded). On each run, per skill:
 *   - only one side differs from state → that side is the source
 *   - both differ → newer SKILL.md mtime wins
 *   - neither differs → skip
 *   - exists on only one side → create on the other
 *
 * Deletion is intentionally NOT propagated (ambiguous to infer).
 *
 * Usage: bun scripts/sync-skills.ts [--dry-run] [--quiet]
 */

import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { readdirSync } from "node:fs";
import { dirname, join } from "node:path";

const REPO_ROOT = resolveRepoRoot();
const CLAUDE_DIR = join(REPO_ROOT, ".claude", "skills");
const AG_DIR = join(REPO_ROOT, ".agents", "skills");
const STATE_PATH = join(REPO_ROOT, "scripts", "skill-sync-state.json");

const DRY_RUN = process.argv.includes("--dry-run");
const QUIET = process.argv.includes("--quiet");

// ── frontmatter handling (dependency-free) ───────────────────────────────────

interface Entry {
  key: string | null; // null for comments / blank passthrough lines
  raw: string; // full text of this entry, may span continuation lines, no trailing newline
}

interface Parsed {
  hasFrontmatter: boolean;
  entries: Entry[];
  body: string; // everything after the closing '---', verbatim
}

/** Split a SKILL.md into ordered frontmatter entries + body. */
function parse(text: string): Parsed {
  if (!text.startsWith("---\n") && !text.startsWith("---\r\n")) {
    return { hasFrontmatter: false, entries: [], body: text };
  }
  const lines = text.split("\n");
  // line 0 is the opening '---'; find the closing one.
  let close = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      close = i;
      break;
    }
  }
  if (close === -1) {
    return { hasFrontmatter: false, entries: [], body: text };
  }
  const fmLines = lines.slice(1, close);
  const body = lines.slice(close + 1).join("\n");

  const entries: Entry[] = [];
  let current: Entry | null = null;
  const keyRe = /^([A-Za-z0-9_-]+):/;
  for (const line of fmLines) {
    const m = line.match(keyRe);
    const isTopLevelKey = m !== null && !/^\s/.test(line);
    if (isTopLevelKey) {
      current = { key: m![1], raw: line };
      entries.push(current);
    } else if (current && (/^\s/.test(line) || line.trim() === "")) {
      // indented continuation or blank line belonging to the current key
      current.raw += "\n" + line;
    } else {
      // standalone line (comment at column 0, or stray) — preserve as passthrough
      entries.push({ key: null, raw: line });
      current = null;
    }
  }
  return { hasFrontmatter: true, entries, body };
}

/** Raw text of a key's entry (including `key:` prefix), or undefined. */
function entryRaw(p: Parsed, key: string): string | undefined {
  return p.entries.find((e) => e.key === key)?.raw;
}

/** Normalized scalar value of a key, quotes stripped, for hashing/equality. */
function scalar(p: Parsed, key: string): string {
  const raw = entryRaw(p, key);
  if (raw === undefined) return "";
  let v = raw.slice(raw.indexOf(":") + 1).trim();
  // collapse multi-line YAML scalars to single spaces for a stable projection
  v = v.replace(/\s+/g, " ").trim();
  if (
    (v.startsWith('"') && v.endsWith('"')) ||
    (v.startsWith("'") && v.endsWith("'"))
  ) {
    v = v.slice(1, -1);
  }
  return v;
}

/** The shared projection that both platforms agree on. */
function projection(p: Parsed): string {
  return JSON.stringify([scalar(p, "name"), scalar(p, "description"), p.body.trim()]);
}

function hash(s: string): string {
  return createHash("sha256").update(s).digest("hex");
}

/**
 * Serialize entries + body back into a SKILL.md string. `body` is exactly the
 * text that followed the closing `---` line (its first line was the blank line, if
 * any), so the closing fence is always terminated by a single `\n` and the body
 * is appended verbatim — preserving the conventional blank line after frontmatter.
 */
function serialize(entries: Entry[], body: string): string {
  const fm = entries.map((e) => e.raw).join("\n");
  return `---\n${fm}\n---\n${body}`;
}

// ── build the two projections of a skill ─────────────────────────────────────

/** Antigravity file from a source Parsed: name + description only, verbatim body. */
function toAntigravity(src: Parsed, name: string): string {
  const nameRaw = entryRaw(src, "name") ?? `name: ${name}`;
  const descRaw = entryRaw(src, "description") ?? "description:";
  return serialize([{ key: "name", raw: nameRaw }, { key: "description", raw: descRaw }], src.body);
}

/**
 * Claude file from an Antigravity source, merged onto an existing Claude file:
 * keep every Claude-only field, replace only name/description, take AG body.
 */
function toClaude(agSrc: Parsed, existingClaude: Parsed | null, name: string): string {
  const nameRaw = entryRaw(agSrc, "name") ?? `name: ${name}`;
  const descRaw = entryRaw(agSrc, "description") ?? "description:";

  if (!existingClaude || !existingClaude.hasFrontmatter) {
    return serialize(
      [{ key: "name", raw: nameRaw }, { key: "description", raw: descRaw }],
      agSrc.body,
    );
  }
  const entries = existingClaude.entries.map((e) => ({ ...e }));
  replaceOrInsert(entries, "name", nameRaw, 0);
  replaceOrInsert(entries, "description", descRaw, indexOfKey(entries, "name") + 1);
  return serialize(entries, agSrc.body);
}

function indexOfKey(entries: Entry[], key: string): number {
  return entries.findIndex((e) => e.key === key);
}

function replaceOrInsert(entries: Entry[], key: string, raw: string, insertAt: number) {
  const i = indexOfKey(entries, key);
  if (i >= 0) entries[i] = { key, raw };
  else entries.splice(Math.min(insertAt, entries.length), 0, { key, raw });
}

// ── filesystem helpers ───────────────────────────────────────────────────────

function listSkills(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(join(dir, d.name, "SKILL.md")))
    .map((d) => d.name);
}

function readSkill(dir: string, name: string): { text: string; mtimeMs: number } | null {
  const p = join(dir, name, "SKILL.md");
  if (!existsSync(p)) return null;
  return { text: readFileSync(p, "utf8"), mtimeMs: statSync(p).mtimeMs };
}

function writeSkill(dir: string, name: string, text: string) {
  const p = join(dir, name, "SKILL.md");
  if (DRY_RUN) return;
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, text, "utf8");
}

function loadState(): Record<string, string> {
  if (!existsSync(STATE_PATH)) return {};
  try {
    return JSON.parse(readFileSync(STATE_PATH, "utf8"));
  } catch {
    return {};
  }
}

function saveState(state: Record<string, string>) {
  if (DRY_RUN) return;
  mkdirSync(dirname(STATE_PATH), { recursive: true });
  writeFileSync(STATE_PATH, JSON.stringify(sortKeys(state), null, 2) + "\n", "utf8");
}

function sortKeys(o: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.keys(o).sort().map((k) => [k, o[k]]));
}

function resolveRepoRoot(): string {
  // scripts/sync-skills.ts → repo root is one level up.
  return dirname(import.meta.dir);
}

// ── main sync ─────────────────────────────────────────────────────────────────

type Action = "claude→ag" | "ag→claude" | "skip" | "conflict-mtime";

function log(msg: string) {
  if (!QUIET) console.log(msg);
}

function main() {
  const state = loadState();
  const names = Array.from(new Set([...listSkills(CLAUDE_DIR), ...listSkills(AG_DIR)])).sort();

  let changes = 0;
  const summary: string[] = [];

  for (const name of names) {
    const claude = readSkill(CLAUDE_DIR, name);
    const ag = readSkill(AG_DIR, name);

    const claudeP = claude ? parse(claude.text) : null;
    const agP = ag ? parse(ag.text) : null;
    const claudeProj = claudeP ? hash(projection(claudeP)) : null;
    const agProj = agP ? hash(projection(agP)) : null;
    const prev = state[name];

    let action: Action = "skip";

    if (claude && !ag) {
      action = "claude→ag";
    } else if (ag && !claude) {
      action = "ag→claude";
    } else if (claude && ag) {
      const claudeChanged = claudeProj !== prev;
      const agChanged = agProj !== prev;
      if (claudeProj === agProj) {
        action = "skip"; // already in agreement
      } else if (claudeChanged && !agChanged) {
        action = "claude→ag";
      } else if (agChanged && !claudeChanged) {
        action = "ag→claude";
      } else {
        // both diverged (or fresh state with no prev) → newer mtime wins
        action = claude.mtimeMs >= ag.mtimeMs ? "claude→ag" : "ag→claude";
        if (prev !== undefined && claudeChanged && agChanged) {
          summary.push(`  ⚠ ${name}: both sides changed → newer mtime (${action})`);
        }
      }
    }

    if (action === "claude→ag") {
      const out = toAntigravity(claudeP!, name);
      const existing = ag?.text;
      if (out !== existing) {
        writeSkill(AG_DIR, name, out);
        changes++;
        summary.push(`  → ${name}: Claude → Antigravity`);
      }
      state[name] = hash(projection(parse(out)));
    } else if (action === "ag→claude") {
      const out = toClaude(agP!, claudeP, name);
      const existing = claude?.text;
      if (out !== existing) {
        writeSkill(CLAUDE_DIR, name, out);
        changes++;
        summary.push(`  → ${name}: Antigravity → Claude`);
      }
      state[name] = hash(projection(parse(out)));
    } else {
      // in agreement — record the agreed projection so future drift is detectable
      if (claudeProj) state[name] = claudeProj;
      else if (agProj) state[name] = agProj;
    }
  }

  saveState(state);

  if (changes === 0) {
    log("skill-sync: in sync, nothing to do.");
  } else {
    log(`skill-sync: ${changes} skill file(s) ${DRY_RUN ? "would be " : ""}updated`);
    for (const line of summary) log(line);
  }
}

main();
