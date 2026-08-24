{
  flake.nixosModules.teapotInference = {
    config,
    lib,
    pkgs,
    ...
  }: let
    llama-cpp = pkgs.llama-cpp.override {cudaSupport = true;};
    llama-server = lib.getExe' llama-cpp "llama-server";
  in {
    nixpkgs.config.allowUnfree = true;

    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    networking.firewall.allowedTCPPorts = [
      4000
    ];

    networking.hosts."10.90.0.11" = ["ollama.v3x.sh"];

    systemd.tmpfiles.rules = [
      "d /var/lib/llama-models 0755 root root -"
    ];

    environment.systemPackages = with pkgs; [
      llmfit
    ];

    services.llama-swap = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8081;

      settings = {
        healthCheckTimeout = 300;

        models = {
          "qwen3.6-35b-a3b" = {
            cmd = ''
              ${llama-server} \
                --port ${"\${PORT}"} \
                --model /var/lib/llama-models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf \
                --alias qwen3.6-35b-a3b \
                --ctx-size 131072 \
                --n-gpu-layers 99 \
                --n-cpu-moe 28 \
                --flash-attn on \
                --cache-type-k q8_0 \
                --cache-type-v q8_0 \
                --jinja \
                --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 \
                --parallel 1 \
                --no-webui
            '';
            ttl = 900;
            concurrencyLimit = 10;
          };
        };

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = [
            "qwen3.6-35b-a3b"
          ];
        };
      };
    };
  };
}
