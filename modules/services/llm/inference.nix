{
  flake.nixosModules.teapotInference = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # /v1/systemone and the clef architecture first ship in v0.6.0, gemma-embedding2 in v0.7.0.
    # Faster builds: one CPU variant for the i7-12700K, no tests.
    llama-cpp =
      (pkgs.llama-cpp.override {
        cudaSupport = true;
        cpuArchDynamicDispatch = false;
      }).overrideAttrs (old: {
        version = "0.7.0";
        # The nixpkgs patch is a backport that v0.7.0 already contains.
        patches = [];
        npmDepsHash = "sha256-hqYzdp1FwPhYkBP278fQXgY9NCKB6Q3P6Gko7BfP0m0=";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "v0.7.0";
          hash = "sha256-pEDYgI3AMTU+cekvRX7NNt5wddznydQSNuerswvEpsA=";
        };
        cmakeFlags =
          old.cmakeFlags
          ++ map (flag: lib.cmakeBool flag true) [
            "GGML_SSE42"
            "GGML_AVX"
            "GGML_F16C"
            "GGML_FMA"
            "GGML_AVX2"
            "GGML_BMI2"
            "GGML_AVX_VNNI"
          ]
          ++ [
            # qwen3.6 runs a q8_0 KV cache, the other models f16.
            (lib.cmakeFeature "GGML_CUDA_FA_QUANTS" "q8_0-q8_0;f16-f16")
          ];
        doCheck = false;
      });
    llama-server = lib.getExe' llama-cpp "llama-server";
    clef-flash = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/4a192915ef971886004b5b13294f2b4c7a7fc39d/Clef-Flash-Q4_K_M.gguf";
      sha256 = "fd3e90605e8103307dca37cb5a8cdb036267e2fe3cb2d908d80a8ceb9ec0638c";
    };
    clef-flash-mmproj = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/4a192915ef971886004b5b13294f2b4c7a7fc39d/mmproj-Clef-Flash-Q8_0.gguf";
      sha256 = "3fbc646617c56c35ba48e06f0fbe8693a83bde49eb31e2a3bf59ba0a308c9e25";
    };
    embeddinggemma-2 = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/embeddinggemma-2-GGUF/resolve/bfcd298762cc34d0357ece5ebdd31791a3a374d8/embeddinggemma-2-Q8_0.gguf";
      sha256 = "2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135";
    };
  in {
    nixpkgs.config.allowUnfree = true;
    # The RTX 3080 Ti.
    nixpkgs.config.cudaCapabilities = ["8.6"];

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
          # A decision model: it serves only /v1/systemone, reached through
          # /upstream/clef-flash/v1/systemone. The whole prompt must fit in one ubatch.
          "clef-flash" = {
            cmd = ''
              ${llama-server} \
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
          # A non-causal model embeds each input in one ubatch, so the ubatch
          # size caps the input length.
          "embeddinggemma-2" = {
            cmd = ''
              ${llama-server} \
                --port ${"\${PORT}"} \
                --model ${embeddinggemma-2} \
                --alias embeddinggemma-2 \
                --embeddings \
                --ctx-size 8192 \
                --batch-size 8192 \
                --ubatch-size 8192 \
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
            "clef-flash"
          ];
        };

        # persistent stops a local-gpu swap from unloading the embedding model.
        groups.embedding = {
          swap = false;
          exclusive = false;
          persistent = true;
          members = ["embeddinggemma-2"];
        };
      };
    };
  };
}
