import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

type GitState = { head: string; subject: string; dirty: number };

const stateType = "git-hint.state";

const isGitState = (data: unknown): data is GitState =>
  typeof data === "object" &&
  data !== null &&
  "head" in data &&
  typeof data.head === "string" &&
  "subject" in data &&
  typeof data.subject === "string" &&
  "dirty" in data &&
  typeof data.dirty === "number";

export default function (pi: ExtensionAPI): void {
  let last: GitState | undefined;

  const read = async (cwd: string): Promise<GitState | undefined> => {
    const [log, status] = await Promise.all([
      pi.exec("git", ["log", "-1", "--format=%H%x00%s"], { cwd, timeout: 2000 }),
      pi.exec("git", ["status", "--porcelain"], { cwd, timeout: 2000 }),
    ]);
    if (log.code !== 0 || status.code !== 0) return undefined;
    const [head = "", subject = ""] = log.stdout.trim().split("\0");
    return { head, subject, dirty: status.stdout.split("\n").filter((line) => line !== "").length };
  };

  pi.on("session_start", (_event, ctx) => {
    last = undefined;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === stateType && isGitState(entry.data)) {
        last = entry.data;
      }
    }
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    if (ctx.agent.kind !== "main") return undefined;
    const current = await read(ctx.cwd);
    if (current === undefined) return undefined;
    const previous = last;
    if (previous !== undefined && current.head === previous.head && current.dirty === previous.dirty) {
      return undefined;
    }
    last = current;
    pi.appendEntry(stateType, current);
    if (previous === undefined) return undefined;
    const moved = current.head === previous.head ? "" : `HEAD ${previous.head.slice(0, 7)} → `;
    const tree = current.dirty === 0 ? "tree clean" : `${current.dirty} uncommitted paths`;
    const content = `git: ${moved}${current.head.slice(0, 7)} "${current.subject}"; ${tree}`;
    return { message: { customType: "git-hint", content, display: false } };
  });
}
