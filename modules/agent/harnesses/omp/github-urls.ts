import { InternalUrlRouter } from "@oh-my-pi/pi-coding-agent/internal-urls";
import type { InternalResource, InternalUrl, ResolveContext } from "@oh-my-pi/pi-coding-agent/internal-urls";

// OMP resolves pr:// and issue:// through the gh CLI, which needs a token in
// the sandbox. These handlers send the same reads to the github_reader MCP
// server, whose daemon holds a read-only token outside the sandbox.

type Scheme = "issue" | "pr";

type Target =
  | { kind: "diff"; repo: string | undefined; number: number; file: string | undefined }
  | { kind: "item"; repo: string | undefined; number: number; comments: boolean }
  | { kind: "list"; repo: string | undefined };

type ToolCall = { name: string; arguments: Record<string, unknown> };

const schemes: Scheme[] = ["pr", "issue"];

const promptDoc =
  "`issue://<N>` / `pr://<N>` (`<owner>/<repo>/<N>` for other repos): GitHub issue/PR; bare: recent; `?state=&limit=&author=&label=`. PR diff: `pr://<N>/diff` (files), `/diff/<i>`, `/diff/all`.";

const positive = (text: string | undefined): number | undefined =>
  text !== undefined && /^[1-9]\d*$/.test(text) ? Number(text) : undefined;

const parse = (scheme: Scheme, url: InternalUrl): Target => {
  const path = (url.rawPathname ?? url.pathname).split("/");
  const segments = [url.rawHost || url.hostname, ...path].filter((segment) => segment !== "");
  const repoSegments = segments.length >= 2 && positive(segments[0]) === undefined ? segments.slice(0, 2) : [];
  const repo = repoSegments.length === 2 ? repoSegments.join("/") : undefined;
  const [number, diff, file, ...rest] = segments.slice(repoSegments.length);
  const item = positive(number);
  if (number === undefined) {
    return { kind: "list", repo };
  }
  if (item !== undefined && diff === undefined) {
    const comments = url.searchParams.get("comments");
    return { kind: "item", repo, number: item, comments: comments !== "0" && comments !== "false" };
  }
  if (item !== undefined && scheme === "pr" && diff === "diff" && rest.length === 0) {
    return { kind: "diff", repo, number: item, file };
  }
  throw new Error(
    `Invalid ${scheme}:// URL. Expected ${scheme}://, ${scheme}://<number>, ${scheme}://<owner>/<repo>, or ${scheme}://<owner>/<repo>/<number>` +
      (scheme === "pr" ? ", with /diff, /diff/<i>, or /diff/all after a number" : ""),
  );
};

const defaultRepo = async (cwd: string): Promise<string> => {
  const child = Bun.spawn(["git", "ls-remote", "--get-url", "origin"], { cwd, stdout: "pipe", stderr: "ignore" });
  const origin = (await new Response(child.stdout).text()).trim();
  const match = /github\.com[:/]([^/]+\/[^/]+?)(?:\.git)?$/.exec(origin);
  if (!match?.[1]) {
    throw new Error(`${cwd} has no github.com origin; name the repository as <owner>/<repo>`);
  }
  return match[1];
};

const toolCall = (scheme: Scheme, target: Target, repo: string, url: InternalUrl): ToolCall => {
  switch (target.kind) {
    case "diff": {
      return {
        name: "get_pull_diff",
        arguments: target.file === undefined ? { repo, number: target.number } : { repo, number: target.number, file: target.file },
      };
    }
    case "item": {
      return {
        name: scheme === "pr" ? "get_pull" : "get_issue",
        arguments: { repo, number: target.number, comments: target.comments },
      };
    }
    case "list": {
      const options: Record<string, unknown> = { repo };
      for (const key of ["state", "author", "label"]) {
        const value = url.searchParams.get(key);
        if (value !== null) {
          options[key] = value;
        }
      }
      const limit = url.searchParams.get("limit");
      if (limit !== null) {
        options.limit = positive(limit) ?? limit;
      }
      return { name: scheme === "pr" ? "list_pulls" : "list_issues", arguments: options };
    }
  }
};

const callTool = async (call: ToolCall): Promise<string> => {
  const child = Bun.spawn(["github-reader-mcp"], { stdin: "pipe", stdout: "pipe", stderr: "pipe" });
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: call })}\n`);
  await child.stdin.end();
  const [output, failure] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text()]);
  await child.exited;
  const response: unknown = output.trim() === "" ? undefined : JSON.parse(output);
  const result: unknown =
    typeof response === "object" && response !== null && "result" in response ? response.result : undefined;
  if (typeof result !== "object" || result === null || !("content" in result) || !Array.isArray(result.content)) {
    throw new Error(`github_reader gave no answer: ${failure.trim() || output.trim()}`);
  }
  const first: unknown = result.content[0];
  const text = typeof first === "object" && first !== null && "text" in first ? first.text : undefined;
  if (typeof text !== "string") {
    throw new Error(`github_reader answered without text: ${output.trim()}`);
  }
  if ("isError" in result && result.isError === true) {
    throw new Error(text);
  }
  return text;
};

const resolve = async (scheme: Scheme, url: InternalUrl, context?: ResolveContext): Promise<InternalResource> => {
  const target = parse(scheme, url);
  const repo = target.repo ?? (await defaultRepo(context?.cwd ?? process.cwd()));
  const content = await callTool(toolCall(scheme, target, repo, url));
  return { url: url.href, content, contentType: "text/markdown", size: Buffer.byteLength(content, "utf-8") };
};

export default function (): void {
  const router = InternalUrlRouter.instance();
  for (const scheme of schemes) {
    // The spread keeps OMP's own fields, such as `spec`. It drops prototype
    // methods, and OMP's own `promptDoc` lists these schemes only when `gh`
    // is on PATH, so both are supplied here.
    router.register({
      ...router.getHandler(scheme),
      scheme,
      promptDoc: scheme === "issue" ? () => promptDoc : undefined,
      resolve: (url: InternalUrl, context?: ResolveContext) => resolve(scheme, url, context),
    });
  }
}
