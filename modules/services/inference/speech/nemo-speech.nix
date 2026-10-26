_: {
  perSystem = {pkgs, ...}: let
    cpu = pkgs.callPackage ./nemo-speech/package.nix {cuda = false;};
    model = import ./nemo-speech/model.nix {inherit pkgs;};
  in {
    packages = {
      nemo-speech = pkgs.callPackage ./nemo-speech/package.nix {};
      nemo-speech-cpu = cpu;
      nemo-speech-model = model;
    };

    # Starts the CPU build on a loopback port, so it needs no GPU and no
    # network. The model is 700 MB and the first run loads it, which is
    # most of the runtime.
    checks.nemo-speech = import ./nemo-speech/check.nix {
      inherit pkgs model;
      package = cpu;
    };
  };

  # Nemotron Speech Streaming through NVIDIA's own ggml runtime. The server
  # speaks an OpenAI-style HTTP API plus a realtime WebSocket that takes PCM16
  # and returns partial transcripts as the audio arrives.
  flake.nixosModules.nemoSpeech = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.nemoSpeech;

    # modules/network/wireguard.nix names its interface wg0.
    tunnel = "wg0";

    # --asr.streaming.rnnt_right_context counts 80 ms encoder frames of
    # lookahead beyond the first. The chunk the encoder waits for is
    # (1 + R) * 80 ms.
    rightContext = {
      "80ms" = 0;
      "160ms" = 1;
      "560ms" = 6;
      "1120ms" = 13;
    };

    # A wildcard bind is not an address a client can dial.
    clientHost =
      if cfg.host == "0.0.0.0"
      then "127.0.0.1"
      else if cfg.host == "::"
      then "[::1]"
      else if lib.hasInfix ":" cfg.host
      then "[${cfg.host}]"
      else cfg.host;

    exe = lib.getExe cfg.package;
    gpu = cfg.gpu >= 0;

    # The key reaches the server as NEMO_SPEECH_HTTP_API_KEY. A command line
    # shows up in `ps` and in the unit file; a credential does not.
    start = pkgs.writeShellScript "nemo-speech-start" ''
      ${lib.optionalString (cfg.apiKeyFile != null) ''
        NEMO_SPEECH_HTTP_API_KEY="$(< "$CREDENTIALS_DIRECTORY/api-key")"
        export NEMO_SPEECH_HTTP_API_KEY
      ''}
      exec ${lib.escapeShellArgs [
        exe
        "serve"
        "--asr-model"
        cfg.model
        "--host"
        cfg.host
        "--port"
        (toString cfg.port)
        "--no-ui"
        "--gpu"
        (toString cfg.gpu)
        "--asr.streaming.rnnt_right_context"
        (toString rightContext.${cfg.latency})
      ]}
    '';

    # The server has no sd_notify. It binds its port only after the model has
    # loaded and warmed up, so /ready answering is the point where a client
    # connection gets a transcript. /ready is exempt from the API key.
    # TimeoutStartSec ends the loop, and systemd stops it as soon as the main
    # process exits.
    waitReady = pkgs.writeShellScript "nemo-speech-wait-ready" ''
      until ${lib.escapeShellArgs [exe "health" "--url" "${cfg.endpoint}/ready"]} >/dev/null 2>&1; do
        sleep 0.5
      done
    '';
  in {
    options.services.nemoSpeech = {
      enable = lib.mkEnableOption "the NeMo-Speech streaming speech recognition server";

      package = lib.mkOption {
        type = lib.types.package;
        # Builds for the GPUs the host declares, one architecture instead of
        # the four the package covers by default.
        default = pkgs.callPackage ./nemo-speech/package.nix (
          {cuda = true;}
          // lib.optionalAttrs (config.nixpkgs.config ? cudaCapabilities) {
            inherit (config.nixpkgs.config) cudaCapabilities;
          }
        );
        defaultText = lib.literalMD "the CUDA build for `config.nixpkgs.config.cudaCapabilities`";
        description = "The nemo-speech package. For a host without a GPU, set this to the CPU-only build (`packages.nemo-speech-cpu` of this flake) and `services.nemoSpeech.gpu = -1`.";
      };

      model = lib.mkOption {
        type = lib.types.path;
        default = import ./nemo-speech/model.nix {inherit pkgs;};
        defaultText = lib.literalMD "the pinned Nemotron Speech Streaming EN 0.6B Q8_0 GGUF";
        description = "ASR model in GGUF form.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address to bind. The API has no TLS, so keep it on loopback or the WireGuard address.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8010;
        description = "TCP port for the HTTP and WebSocket API.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the port on the WireGuard interface ${tunnel}, and on no other.";
      };

      latency = lib.mkOption {
        type = lib.types.enum (lib.attrNames rightContext);
        default = "160ms";
        description = ''
          Chunk size of the cache-aware encoder. A shorter chunk shows words
          sooner and costs accuracy, a longer one is the reverse.
        '';
      };

      gpu = lib.mkOption {
        type = lib.types.ints.between (-1) 63;
        default = 0;
        description = "CUDA device index, or -1 to run on the CPU.";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          File holding the bearer token API clients must send. systemd loads it
          as a credential, so it needs no permissions for the service user.
        '';
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "http://${clientHost}:${toString cfg.port}";
        description = "Base URL clients use. The realtime route is `/v1/audio/transcriptions/realtime` under it, with `ws` as the scheme.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.openFirewall || config.networking.wireguard.interfaces ? ${tunnel};
          message = "services.nemoSpeech.openFirewall opens the port on ${tunnel}, which this host does not define.";
        }
      ];

      networking.firewall.interfaces.${tunnel}.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

      systemd.services.nemo-speech = {
        description = "NeMo-Speech streaming speech recognition";
        wantedBy = ["multi-user.target"];
        # The bind address may be the tunnel address, which wg0 assigns.
        after = ["network.target"] ++ lib.optional (config.networking.wireguard.interfaces ? ${tunnel}) "wireguard-${tunnel}.service";

        environment = lib.mkIf gpu {
          # Only read when a kernel has no code for the GPU and the driver
          # JIT-compiles PTX. The default cache sits in $HOME, which is
          # read-only.
          CUDA_CACHE_PATH = "/var/cache/nemo-speech/cuda";
        };

        serviceConfig =
          {
            Type = "exec";
            ExecStart = start;
            ExecStartPost = waitReady;
            # Loading 700 MB and warming up takes well under a minute on a
            # GPU. A CPU start with a cold page cache is the slow case.
            TimeoutStartSec = "5min";
            Restart = "on-failure";
            RestartSec = 5;

            DynamicUser = true;
            CacheDirectory = "nemo-speech";
            LoadCredential = lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}";

            CapabilityBoundingSet = [""];
            LockPersonality = true;
            # No MemoryDenyWriteExecute: the CUDA driver maps writable and
            # executable memory.
            NoNewPrivileges = true;
            PrivateDevices = !gpu;
            PrivateTmp = true;
            PrivateUsers = true;
            # The driver reads /proc/driver/nvidia and /proc/meminfo.
            ProcSubset = "all";
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RemoveIPC = true;
            RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            # @resources comes back after the deny: the inference threads set
            # their scheduling and affinity, and the CUDA runtime sets rlimits.
            SystemCallFilter = ["@system-service" "~@privileged" "@resources"];
            UMask = "0077";
          }
          // lib.optionalAttrs gpu {
            DevicePolicy = "closed";
            DeviceAllow = [
              "char-nvidiactl"
              "char-nvidia-caps"
              "char-nvidia-frontend"
              "char-nvidia-uvm"
            ];
            # The device nodes are world-writable under NixOS, but a site that
            # tightens them to group video or render keeps working.
            SupplementaryGroups = ["video" "render"];
          };
      };
    };
  };
}
