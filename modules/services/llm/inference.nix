{
  flake.nixosModules.teapotInference = {
    config,
    lib,
    pkgs,
    ...
  }: let
    llama-cpp = pkgs.llama-cpp.override {cudaSupport = true;};
    llama-server = lib.getExe' llama-cpp "llama-server";
    # Stock llama.cpp rejects the PQ2_0 and PTQ1_0 tensor types that Bonsai ships.
    llama-cpp-prism = llama-cpp.overrideAttrs {
      src = pkgs.fetchFromGitHub {
        owner = "PrismML-Eng";
        repo = "llama.cpp";
        tag = "prism-b10743-adfffbe";
        hash = "sha256-SNBAC+dNTwQxpGmKyG7i/8eqCNg6985DXtqGbzWgwFA=";
      };
    };
    llama-server-prism = lib.getExe' llama-cpp-prism "llama-server";
    bonsai-2-27b = pkgs.fetchurl {
      url = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/b072e1d3b35a0a630cece372c2127528e0994386/Ternary-Bonsai-2-27B-PQ2_0.gguf";
      sha256 = "3907dc1658db1f78a9826bf8d5bcb8dc65db0d466388937af57f2294fae62ec1";
    };
    # /v1/systemone and the clef architecture first ship in v0.6.0.
    llama-cpp-clef = llama-cpp.overrideAttrs {
      version = "0.6.0";
      npmDepsHash = "sha256-a17M+L3nLdRnN6WMB6imPFmwqG2g8uv+gwN0XTAUrf8=";
      src = pkgs.fetchFromGitHub {
        owner = "ggml-org";
        repo = "llama.cpp";
        tag = "v0.6.0";
        hash = "sha256-l6l6JIlIVTaVC6xh5M4fRHFtXsweQuugtkNTWHcZZF4=";
      };
    };
    llama-server-clef = lib.getExe' llama-cpp-clef "llama-server";
    clef-flash = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/4a192915ef971886004b5b13294f2b4c7a7fc39d/Clef-Flash-Q4_K_M.gguf";
      sha256 = "fd3e90605e8103307dca37cb5a8cdb036267e2fe3cb2d908d80a8ceb9ec0638c";
    };
    clef-flash-mmproj = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/4a192915ef971886004b5b13294f2b4c7a7fc39d/mmproj-Clef-Flash-Q8_0.gguf";
      sha256 = "3fbc646617c56c35ba48e06f0fbe8693a83bde49eb31e2a3bf59ba0a308c9e25";
    };
  in {
    nixpkgs.config.allowUnfree = true;

    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

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

        # No --n-gpu-layers or --n-cpu-moe: the speech server holds part of the
        # card, and llama.cpp's --fit, on by default, places the layers and
        # experts in whatever memory is free when a model loads.
        models = {
          "qwen3.6-35b-a3b" = {
            cmd = ''
              ${llama-server} \
                --port ${"\${PORT}"} \
                --model /var/lib/llama-models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf \
                --alias qwen3.6-35b-a3b \
                --ctx-size 131072 \
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
          "bonsai-2-27b" = {
            cmd = ''
              ${llama-server-prism} \
                --port ${"\${PORT}"} \
                --model ${bonsai-2-27b} \
                --alias bonsai-2-27b \
                --ctx-size 65536 \
                --flash-attn on \
                --cache-type-k q8_0 \
                --cache-type-v q8_0 \
                --jinja \
                --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.05 \
                --parallel 1 \
                --no-webui
            '';
            ttl = 900;
            concurrencyLimit = 10;
          };
          # A decision model: it serves only /v1/systemone, reached through
          # /upstream/clef-flash/v1/systemone. The whole prompt must fit in one ubatch.
          "clef-flash" = {
            cmd = ''
              ${llama-server-clef} \
                --port ${"\${PORT}"} \
                --model ${clef-flash} \
                --mmproj ${clef-flash-mmproj} \
                --alias clef-flash \
                --ctx-size 8192 \
                --batch-size 8192 \
                --ubatch-size 8192 \
                --flash-attn on \
                --parallel 1 \
                --no-webui
            '';
            ttl = 900;
          };
        };

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = [
            "qwen3.6-35b-a3b"
            "bonsai-2-27b"
            "clef-flash"
          ];
        };
      };
    };
  };
}
