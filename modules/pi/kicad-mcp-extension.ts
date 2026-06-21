import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";

class McpClient {
  private proc: ChildProcessWithoutNullStreams;
  private nextId = 1;
  private buffer = "";
  private pending = new Map<
    number,
    {
      resolve: (value: any) => void;
      reject: (error: Error) => void;
      timer: NodeJS.Timeout;
    }
  >();

  constructor(command: string, args: string[] = []) {
    this.proc = spawn(command, args, {
      stdio: ["pipe", "pipe", "pipe"],
      env: process.env,
    });

    this.proc.stdout.on("data", (chunk) => this.onData(chunk));
    this.proc.stderr.on("data", (chunk) => {
      process.stderr.write(`[kicad-mcp] ${chunk}`);
    });
    this.proc.on("error", (error) => this.rejectAll(error));
    this.proc.on("exit", (code, signal) => {
      this.rejectAll(new Error(`kicad-mcp exited with code=${code} signal=${signal}`));
    });
  }

  async initialize() {
    await this.request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {
        name: "pi-kicad-mcp",
        version: "1.0.0",
      },
    });

    this.notification("notifications/initialized", {});
  }

  async request(method: string, params?: any, timeoutMs = 30_000): Promise<any> {
    const id = this.nextId++;
    const message = {
      jsonrpc: "2.0",
      id,
      method,
      ...(params === undefined ? {} : { params }),
    };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`MCP request timed out: ${method}`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timer });
      this.send(message);
    });
  }

  notification(method: string, params?: any) {
    this.send({
      jsonrpc: "2.0",
      method,
      ...(params === undefined ? {} : { params }),
    });
  }

  close() {
    this.proc.kill();
  }

  private send(message: any) {
    // Python MCP/FastMCP stdio uses newline-delimited JSON-RPC, not the
    // Language Server Protocol Content-Length framing.
    this.proc.stdin.write(`${JSON.stringify(message)}\n`);
  }

  private onData(chunk: Buffer) {
    this.buffer += chunk.toString("utf8");

    while (true) {
      const lineEnd = this.buffer.indexOf("\n");
      if (lineEnd === -1) return;

      const line = this.buffer.slice(0, lineEnd).trim();
      this.buffer = this.buffer.slice(lineEnd + 1);
      if (!line) continue;

      let message: any;
      try {
        message = JSON.parse(line);
      } catch (error) {
        console.error("Failed to parse KiCad MCP message", { line, error });
        continue;
      }

      if (message.id !== undefined && this.pending.has(message.id)) {
        const pending = this.pending.get(message.id)!;
        this.pending.delete(message.id);
        clearTimeout(pending.timer);

        if (message.error) {
          pending.reject(new Error(message.error.message ?? JSON.stringify(message.error)));
        } else {
          pending.resolve(message.result);
        }
      }
    }
  }

  private rejectAll(error: Error) {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
  }
}

function toolName(name: string) {
  return `kicad_${name.replace(/[^a-zA-Z0-9_]/g, "_")}`;
}

export default async function (pi: ExtensionAPI) {
  const command = process.env.KICAD_MCP_COMMAND ?? "kicad-mcp";
  const client = new McpClient(command);

  try {
    await client.initialize();
    const listed = await client.request("tools/list", {});
    const tools = listed.tools ?? [];

    for (const tool of tools) {
      pi.registerTool({
        name: toolName(tool.name),
        label: `KiCad: ${tool.name}`,
        description: tool.description ?? `KiCad MCP tool: ${tool.name}`,
        parameters: (tool.inputSchema ?? {
          type: "object",
          properties: {},
          additionalProperties: true,
        }) as any,

        async execute(_toolCallId, params) {
          const result = await client.request("tools/call", {
            name: tool.name,
            arguments: params ?? {},
          });

          const content = Array.isArray(result.content) && result.content.length > 0
            ? result.content.map((item: any) => {
                if (item?.type === "text") return item;
                return { type: "text", text: JSON.stringify(item, null, 2) };
              })
            : [{ type: "text", text: JSON.stringify(result, null, 2) }];

          return {
            content,
            details: result,
          };
        },
      });
    }

    pi.on("session_start", async (_event, ctx) => {
      ctx.ui.notify(`Loaded ${tools.length} KiCad MCP tools`, "info");
    });
  } catch (error) {
    client.close();
    console.error("Failed to load KiCad MCP extension", error);

    pi.on("session_start", async (_event, ctx) => {
      ctx.ui.notify(`Failed to load KiCad MCP: ${String(error)}`, "error");
    });
  }
}
