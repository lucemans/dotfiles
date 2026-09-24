import net from "node:net";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const socketPath = process.env.HERDR_SOCKET_PATH;
const paneId = process.env.HERDR_PANE_ID;
const source = "user:pi-metadata";

// Each report opens its own connection, so reports can arrive out of order, and
// herdr drops any whose seq is not above the last one it accepted from this
// source. Every report therefore carries the whole state.
let seq = Date.now() * 1000;

type Metadata = {
  title: string | undefined;
  model: string | undefined;
};

function report({ title, model }: Metadata): void {
  if (socketPath === undefined || paneId === undefined) {
    return;
  }
  seq += 1;
  const request = {
    id: `${source}:${seq}`,
    method: "pane.report_metadata",
    params: {
      pane_id: paneId,
      source,
      seq,
      ...(title === undefined ? { clear_title: true } : { title }),
      tokens: { model: model ?? null },
    },
  };
  const socket = net.createConnection(socketPath);
  socket.setTimeout(2000, () => socket.destroy());
  socket.on("error", () => socket.destroy());
  socket.on("data", () => socket.destroy());
  socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
}

export default function (pi: ExtensionAPI): void {
  if (process.env.HERDR_ENV !== "1") {
    return;
  }

  let active = false;
  const state: Metadata = { title: undefined, model: undefined };

  pi.on("session_start", (_event, ctx) => {
    // Print, JSON and RPC runs have no pane of their own to describe.
    active = ctx.mode === "tui";
    if (!active) {
      return;
    }
    state.title = pi.getSessionName();
    state.model = ctx.model?.id;
    report(state);
  });

  pi.on("session_info_changed", (event) => {
    if (active) {
      state.title = event.name;
      report(state);
    }
  });

  pi.on("model_select", (event) => {
    if (active) {
      state.model = event.model.id;
      report(state);
    }
  });
}
