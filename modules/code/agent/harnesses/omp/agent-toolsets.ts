import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// `agent` reads the last entry of this type to resume a session with the
// toolsets it ran with.
const customType = "agent.toolsets";

export default function (pi: ExtensionAPI): void {
  const toolsets = (process.env.AGENT_TOOLSETS ?? "").split(" ").filter((name) => name !== "");
  const recorded = JSON.stringify({ toolsets });

  pi.on("session_start", (_event, ctx) => {
    let last: string | undefined;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === customType) {
        last = JSON.stringify(entry.data);
      }
    }
    if (last !== recorded) {
      pi.appendEntry(customType, { toolsets });
    }
  });
}
