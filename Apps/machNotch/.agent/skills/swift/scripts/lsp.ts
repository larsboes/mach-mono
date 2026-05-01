#!/usr/bin/env -S npx tsx
/**
 * Swift LSP Client Script
 *
 * On-demand SourceKit-LSP integration for the Swift skill.
 * Usage: swift_lsp <command> [args]
 *
 * Commands:
 *   status                    - Check LSP status and workspace info
 *   goto <file> <line> <col>  - Go to definition
 *   hover <file> <line> <col> - Get type info/docs
 *   diagnostics <file>        - Get errors/warnings
 *
 * Requires: npx (comes with Node.js)
 */

import { spawn, ChildProcess } from "child_process";
import { promises as fs } from "fs";
import { join, dirname } from "path";

// JSON-RPC types
interface JSONRPCRequest {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params?: unknown;
}

interface JSONRPCResponse {
  jsonrpc: "2.0";
  id: number;
  result?: unknown;
  error?: { code: number; message: string };
}

class SwiftLSPClient {
  private process: ChildProcess | null = null;
  private messageId = 0;
  private pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  private buffer = "";
  private initialized = false;

  constructor(private executablePath: string) {}

  async connect(): Promise<void> {
    if (this.process) return;
    return new Promise((resolve, reject) => {
      this.process = spawn(this.executablePath, [], { stdio: ["pipe", "pipe", "pipe"] });
      this.process.stdout?.on("data", (d: Buffer) => this.handleData(d.toString()));
      this.process.stderr?.on("data", (d: Buffer) => console.error(`[sourcekit] ${d.toString().trim()}`));
      this.process.on("error", (e) => reject(new Error(`Failed to start: ${e.message}`)));
      this.process.on("exit", () => this.cleanup());
      setTimeout(resolve, 100);
    });
  }

  async initializeWorkspace(rootUri: string): Promise<void> {
    if (!this.process) await this.connect();
    await this.request("initialize", {
      processId: process.pid,
      rootUri: `file://${rootUri}`,
      capabilities: {
        textDocument: {
          synchronization: { dynamicRegistration: false },
          completion: { dynamicRegistration: false },
          hover: { dynamicRegistration: false, contentFormat: ["markdown", "plaintext"] },
          definition: { dynamicRegistration: false },
        },
        workspace: {},
      },
      workspaceFolders: [{ uri: `file://${rootUri}`, name: rootUri.split("/").pop() || "workspace" }],
    });
    this.initialized = true;
    this.notify("initialized", {});
  }

  async openDocument(filePath: string, text: string): Promise<void> {
    if (!this.initialized) return;
    this.notify("textDocument/didOpen", {
      textDocument: { uri: `file://${filePath}`, languageId: "swift", version: 1, text },
    });
  }

  async gotoDefinition(filePath: string, line: number, character: number): Promise<{ uri: string; range: { start: { line: number; character: number } } } | null> {
    if (!this.initialized) return null;
    const result = await this.request("textDocument/definition", {
      textDocument: { uri: `file://${filePath}` },
      position: { line, character },
    });
    if (!result) return null;
    const locations = Array.isArray(result) ? result : [result];
    if (locations.length === 0) return null;
    const loc = locations[0] as { uri: string; range: { start: { line: number; character: number } } };
    return { uri: loc.uri.replace("file://", ""), range: loc.range };
  }

  async hover(filePath: string, line: number, character: number): Promise<string | null> {
    if (!this.initialized) return null;
    const result = await this.request("textDocument/hover", {
      textDocument: { uri: `file://${filePath}` },
      position: { line, character },
    });
    if (!result) return null;
    const contents = (result as { contents?: string | { value: string } | Array<string | { value: string }> }).contents;
    if (typeof contents === "string") return contents;
    if (Array.isArray(contents)) return contents.map(c => typeof c === "string" ? c : c.value).join("\n");
    if (contents && "value" in contents) return contents.value;
    return JSON.stringify(contents);
  }

  async shutdown(): Promise<void> {
    if (!this.process) return;
    try { await this.request("shutdown", {}); this.notify("exit", {}); } catch {}
    this.process.kill();
    this.cleanup();
  }

  private cleanup(): void {
    this.process = null;
    this.initialized = false;
    this.buffer = "";
    for (const { reject } of this.pending.values()) reject(new Error("Connection closed"));
    this.pending.clear();
  }

  private handleData(data: string): void {
    this.buffer += data;
    while (true) {
      const headerMatch = this.buffer.match(/Content-Length: (\d+)\r\n\r\n/);
      if (!headerMatch) break;
      const contentLength = parseInt(headerMatch[1], 10);
      const headerEnd = headerMatch.index! + headerMatch[0].length;
      const messageEnd = headerEnd + contentLength;
      if (this.buffer.length < messageEnd) break;
      const message = this.buffer.slice(headerEnd, messageEnd);
      this.buffer = this.buffer.slice(messageEnd);
      try {
        const parsed = JSON.parse(message) as JSONRPCResponse;
        if (parsed.id !== undefined && this.pending.has(parsed.id)) {
          const { resolve, reject } = this.pending.get(parsed.id)!;
          this.pending.delete(parsed.id);
          parsed.error ? reject(new Error(parsed.error.message)) : resolve(parsed.result);
        }
      } catch {}
    }
  }

  private request(method: string, params: unknown): Promise<unknown> {
    return new Promise((resolve, reject) => {
      const id = ++this.messageId;
      this.pending.set(id, { resolve, reject });
      this.send({ jsonrpc: "2.0", id, method, params });
    });
  }

  private notify(method: string, params: unknown): void {
    this.send({ jsonrpc: "2.0", method, params });
  }

  private send(message: Omit<JSONRPCRequest, "id"> | JSONRPCRequest): void {
    if (!this.process?.stdin) return;
    const content = JSON.stringify(message);
    this.process.stdin.write(`Content-Length: ${Buffer.byteLength(content)}\r\n\r\n${content}`);
  }
}

// Find sourcekit-lsp executable
async function findSourceKitLSP(): Promise<string | null> {
  const { execSync } = await import("child_process");
  try {
    return execSync("which sourcekit-lsp", { encoding: "utf8" }).trim() || null;
  } catch {
    const paths = [
      "/usr/bin/sourcekit-lsp",
      "/usr/local/bin/sourcekit-lsp",
      "/opt/homebrew/bin/sourcekit-lsp",
      "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
    ];
    for (const p of paths) if (await fs.access(p).then(() => true).catch(() => false)) return p;
    return null;
  }
}

// Find workspace root
async function findWorkspaceRoot(filePath: string): Promise<string | null> {
  let dir = dirname(filePath);
  while (dir !== "/" && dir !== ".") {
    try {
      const entries = await fs.readdir(dir);
      if (entries.includes("Package.swift") || entries.some(e => e.endsWith(".xcodeproj"))) return dir;
    } catch {}
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

// Main
async function main() {
  const [command, ...args] = process.argv.slice(2);

  if (command === "status") {
    const path = await findSourceKitLSP();
    const cwd = process.cwd();
    const swiftFiles: string[] = [];
    async function scan(dir: string, depth: number): Promise<void> {
      if (depth > 3) return;
      try {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        for (const e of entries) {
          if (e.isDirectory() && !e.name.startsWith(".") && e.name !== "node_modules" && e.name !== "build") {
            await scan(join(dir, e.name), depth + 1);
          } else if (e.name.endsWith(".swift")) {
            swiftFiles.push(join(dir, e.name));
          }
        }
      } catch {}
    }
    await scan(cwd, 0);
    const hasPackage = await fs.access(join(cwd, "Package.swift")).then(() => true).catch(() => false);
    const hasXcode = (await fs.readdir(cwd).catch(() => [])).some(e => e.endsWith(".xcodeproj"));
    console.log(JSON.stringify({ sourcekit: path, files: swiftFiles.length, package: hasPackage, xcode: hasXcode }, null, 2));
    return;
  }

  if (command === "goto" && args.length >= 3) {
    const [file, line, col] = args;
    const sourcekit = await findSourceKitLSP();
    if (!sourcekit) { console.error("sourcekit-lsp not found"); process.exit(1); }
    const client = new SwiftLSPClient(sourcekit);
    const root = await findWorkspaceRoot(file) || dirname(file);
    await client.initializeWorkspace(root);
    await client.openDocument(file, await fs.readFile(file, "utf8"));
    const loc = await client.gotoDefinition(file, parseInt(line) - 1, parseInt(col));
    await client.shutdown();
    if (loc) console.log(`${loc.uri}:${loc.range.start.line + 1}:${loc.range.start.character}`);
    else console.log("No definition found");
    return;
  }

  if (command === "hover" && args.length >= 3) {
    const [file, line, col] = args;
    const sourcekit = await findSourceKitLSP();
    if (!sourcekit) { console.error("sourcekit-lsp not found"); process.exit(1); }
    const client = new SwiftLSPClient(sourcekit);
    const root = await findWorkspaceRoot(file) || dirname(file);
    await client.initializeWorkspace(root);
    await client.openDocument(file, await fs.readFile(file, "utf8"));
    const info = await client.hover(file, parseInt(line) - 1, parseInt(col));
    await client.shutdown();
    console.log(info || "No info available");
    return;
  }

  console.log(`Usage: swift_lsp <command> [args]

Commands:
  status                    Check LSP status and workspace info
  goto <file> <line> <col>  Go to definition (1-indexed line)
  hover <file> <line> <col> Get type info/docs (1-indexed line)

Examples:
  swift_lsp status
  swift_lsp goto ./MyFile.swift 42 15
  swift_lsp hover ./MyFile.swift 42 15`);
}

main().catch(e => { console.error(e); process.exit(1); });
