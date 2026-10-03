{inputs, ...}: let
  # Also compiled into the bridge as SOCKET_PATH in src/bin/github-reader-mcp.rs.
  socket = "/run/github-reader/socket";
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages.github-reader-mcp = pkgs.rustPlatform.buildRustPackage {
      pname = "github-reader";
      version = "0.1.0";
      src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src];
      };
      cargoLock.lockFile = ./Cargo.lock;
    };
  };

  # The daemon holds the token and runs outside every agent sandbox. A sandbox
  # gets only the socket, and `github-reader-mcp` joins a harness to it.
  flake.nixosModules.tools = {
    config,
    pkgs,
    ...
  }: {
    sops.secrets.github_reader_token.restartUnits = ["github-reader.service"];

    systemd.sockets.github-reader = {
      wantedBy = ["sockets.target"];
      socketConfig = {
        ListenStream = socket;
        SocketUser = "luc";
        SocketMode = "0600";
      };
    };

    systemd.services.github-reader = {
      serviceConfig = {
        ExecStart = "${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.github-reader-mcp}/bin/github-reader";
        DynamicUser = true;
        LoadCredential = "token:${config.sops.secrets.github_reader_token.path}";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
      };
    };

    # Not a device node, but bound the same way: only while it exists. The
    # directory is bound rather than the socket, so a recreated socket stays
    # reachable from sandboxes that are already running.
    agentRuntime.toolsets.base.devices = [(dirOf socket)];
  };
}
