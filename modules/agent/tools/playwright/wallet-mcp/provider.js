(() => {
  const brokerUrl = "ws://127.0.0.1:47621";
  const listeners = new Map();
  const requests = new Map();
  let socket;
  let account = null;
  let chainId = "0x7a69";
  let sequence = 0;

  const emit = (event, ...arguments_) => {
    for (const listener of listeners.get(event) ?? []) {
      listener(...arguments_);
    }
  };

  const send = (message) => {
    if (socket?.readyState !== WebSocket.OPEN) {
      throw { code: 4900, message: "Dapp QA Wallet is disconnected." };
    }
    socket.send(JSON.stringify(message));
  };

  const connect = () => {
    socket = new WebSocket(brokerUrl);
    socket.addEventListener("open", () => {
      send({ type: "register", origin: location.origin });
    });
    socket.addEventListener("message", ({ data }) => {
      const message = JSON.parse(data);
      if (message.type === "response") {
        const request = requests.get(message.id);
        if (!request) return;
        requests.delete(message.id);
        message.error ? request.reject(message.error) : request.resolve(message.result);
      }
      if (message.type === "state") {
        const previousAccount = account;
        const previousChainId = chainId;
        account = message.account;
        chainId = message.chainId;
        if (previousAccount !== account) emit("accountsChanged", account ? [account] : []);
        if (previousChainId !== chainId) emit("chainChanged", chainId);
      }
    });
    socket.addEventListener("close", () => {
      for (const request of requests.values()) {
        request.reject({ code: 4900, message: "Dapp QA Wallet is disconnected." });
      }
      requests.clear();
      setTimeout(connect, 250);
    });
  };

  const provider = {
    isDappQaWallet: true,
    request: ({ method, params = [] }) => new Promise((resolve, reject) => {
      const id = `${crypto.randomUUID()}-${sequence++}`;
      requests.set(id, { resolve, reject });
      try {
        send({ type: "request", id, origin: location.origin, method, params });
      } catch (error) {
        requests.delete(id);
        reject(error);
      }
    }),
    on: (event, listener) => {
      const eventListeners = listeners.get(event) ?? new Set();
      eventListeners.add(listener);
      listeners.set(event, eventListeners);
      return provider;
    },
    removeListener: (event, listener) => {
      listeners.get(event)?.delete(listener);
      return provider;
    },
  };

  Object.defineProperty(window, "ethereum", {
    configurable: false,
    enumerable: true,
    value: provider,
    writable: false,
  });

  const info = {
    icon: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath fill='%23ff0040' d='M16 2 3 9v14l13 7 13-7V9z'/%3E%3C/svg%3E",
    name: "Dapp QA Wallet",
    rdns: "local.dapp-qa-wallet",
    uuid: crypto.randomUUID(),
  };
  const announce = () => window.dispatchEvent(new CustomEvent("eip6963:announceProvider", { detail: { info, provider } }));
  window.addEventListener("eip6963:requestProvider", announce);
  announce();
  connect();
})();
