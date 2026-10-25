{
  flake.nixosModules.mediabusInference = {
    lib,
    pkgs,
    ...
  }: let
    models = import ./mediabus-models.nix;
    modelsDir = "/var/lib/llama-models";

    # Same llama.cpp pin as teapotInference, built for the Ryzen 9 7900 (Zen 4).
    # The models run on the GPUs, so the CPU flags only matter for offloaded layers.
    llama-cpp =
      (pkgs.llama-cpp.override {
        cudaSupport = true;
        cpuArchDynamicDispatch = false;
      }).overrideAttrs (old: {
        version = "0.7.0";
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
            "GGML_AVX512"
            "GGML_AVX512_VBMI"
            "GGML_AVX512_VNNI"
            "GGML_AVX512_BF16"
          ]
          ++ [
            # The models use q4_0, q8_0 or f16 KV caches, with the same type for K and V.
            (lib.cmakeFeature "GGML_CUDA_FA_QUANTS" "q4_0-q4_0;q8_0-q8_0;f16-f16")
          ];
        doCheck = false;
      });
    llama-server = lib.getExe' llama-cpp "llama-server";

    modelPath = key: let
      m = models.${key};
    in "${modelsDir}/${builtins.replaceStrings ["/"] ["--"] m.repo}/${m.file}";

    serve = args:
      lib.concatStringsSep " " ([llama-server "--port" "\${PORT}"] ++ args);

    fetchModels = pkgs.writeShellApplication {
      name = "llama-models-fetch";
      runtimeInputs = [pkgs.curl pkgs.coreutils];
      text = ''
        failed=0

        fetch() {
          local url=$1 dest=$2 want=$3 gated=$4 rc=0 got
          if [ -f "$dest" ] && [ "$(cat "$dest.ok" 2>/dev/null)" = "$want" ]; then
            return 0
          fi
          mkdir -p "$(dirname "$dest")"
          # A file put here by hand, such as one restored from the NAS, is accepted when its hash matches.
          if [ -f "$dest" ]; then
            echo "verifying $dest"
            got=$(sha256sum "$dest" | cut -d' ' -f1)
            if [ "$got" = "$want" ]; then
              echo "$want" > "$dest.ok"
              return 0
            fi
            echo "sha256 of $dest is $got, want $want" >&2
            rm -f "$dest"
          fi
          if [ "$gated" = 1 ]; then
            echo "$dest is from a gated repo, so it has to be placed by hand" >&2
            return 0
          fi
          echo "downloading $dest"
          # Exit 33 means the partial file already holds every byte, so it only needs the hash check.
          curl --fail --location --retry 5 --retry-delay 10 --continue-at - --output "$dest.part" "$url" || rc=$?
          if [ "$rc" -ne 0 ] && [ "$rc" -ne 33 ]; then
            echo "download failed for $dest (curl exit $rc)" >&2
            return 1
          fi
          got=$(sha256sum "$dest.part" | cut -d' ' -f1)
          if [ "$got" != "$want" ]; then
            echo "sha256 mismatch for $dest: got $got, want $want" >&2
            rm -f "$dest.part"
            return 1
          fi
          mv "$dest.part" "$dest"
          echo "$want" > "$dest.ok"
        }

        ${lib.concatMapStrings (m: ''
          fetch ${lib.escapeShellArg "https://huggingface.co/${m.repo}/resolve/${m.rev}/${m.file}"} \
            ${lib.escapeShellArg "${modelsDir}/${builtins.replaceStrings ["/"] ["--"] m.repo}/${m.file}"} \
            ${m.sha256} ${
            if m.gated or false
            then "1"
            else "0"
          } || failed=1
        '') (lib.attrValues models)}

        exit "$failed"
      '';
    };
  in {
    nixpkgs.config.allowUnfree = true;
    # Both RTX A4000 cards are Ampere, compute capability 8.6.
    nixpkgs.config.cudaCapabilities = ["8.6"];

    systemd.tmpfiles.rules = [
      "d ${modelsDir} 0755 root root -"
    ];

    # The download runs in the background. `Type=exec` finishes the start job once the
    # script is running, so neither the boot nor `switch-to-configuration` waits for 279GB.
    # A model whose file has not arrived yet fails to load until its download finishes.
    systemd.services.llama-models-fetch = {
      description = "Download and verify the llama-swap model files";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "exec";
        RemainAfterExit = true;
        ExecStart = lib.getExe fetchModels;
        Restart = "on-failure";
        RestartSec = "5min";
      };
    };

    services.llama-swap = {
      enable = true;
      # LiteLLM on teapot reaches this at http://10.90.0.11:11434/v1.
      listenAddress = "0.0.0.0";
      port = 11434;
      openFirewall = true;

      settings = {
        healthCheckTimeout = 300;
        logLevel = "debug";
        logToStdout = "both";
        # Unload models after 15 minutes without requests.
        globalTTL = 900;

        performance = {
          enable = true;
          every = "5s";
        };

        models = {
          "qwen3.6-35b-a3b" = {
            cmd = serve [
              "--model"
              (modelPath "qwen3.6-35b-a3b")
              "--alias"
              "qwen3.6-35b-a3b"
              "--ctx-size 98304"
              "--n-gpu-layers 999"
              "--flash-attn on"
              "--cache-type-k q4_0"
              "--cache-type-v q4_0"
              "--jinja"
              "--temp 0.7"
              "--top-p 0.95"
              "--top-k 20"
              "--min-p 0.0"
              "--parallel 1"
              "--repeat-penalty 1.12"
              "--repeat-last-n 256"
            ];
            ttl = 900;
            concurrencyLimit = 2;
          };
          "qwen2.5-coder-1.5b" = {
            cmd = serve [
              "--model"
              (modelPath "qwen2.5-coder-1.5b")
              "--alias"
              "qwen2.5-coder-1.5b"
              "--gpu-layers all"
              "--ctx-size 16384"
              "--flash-attn on"
              "--parallel 5"
              "--no-prefill-assistant"
            ];
            ttl = 300;
            concurrencyLimit = 5;
          };
          "qwen3-8b-dflash" = {
            cmd = serve [
              "--model"
              (modelPath "qwen3-8b")
              "--model-draft"
              (modelPath "qwen3-8b-dflash")
              "--alias"
              "qwen3-8b-dflash"
              "--spec-type draft-dflash"
              "--spec-draft-n-max 15"
              "--gpu-layers all"
              "--gpu-layers-draft all"
              "--flash-attn on"
              "--ctx-size 16384"
              "--parallel 1"
              "--temperature 0"
              "--cache-type-k q8_0"
              "--cache-type-v q8_0"
              "--top-k 1"
            ];
            ttl = 300;
            concurrencyLimit = 3;
          };
          "qwen2.5-coder-7b-fim" = {
            env = ["CUDA_VISIBLE_DEVICES=0"];
            cmd = serve [
              "--model"
              (modelPath "qwen2.5-coder-7b")
              "--alias"
              "qwen2.5-coder-7b-fim"
              "--gpu-layers all"
              "--split-mode none"
              "--main-gpu 0"
              "--flash-attn on"
              "--ctx-size 16384"
              "--cache-type-k q8_0"
              "--cache-type-v q8_0"
              "--cache-reuse 256"
              "--parallel 1"
              "--batch-size 2048"
              "--ubatch-size 512"
            ];
            ttl = 3600;
            concurrencyLimit = 3;
          };
          "sweep-next-edit-1.5b" = {
            cmd = serve [
              "--model"
              (modelPath "sweep-next-edit-1.5b")
              "--alias"
              "sweep-next-edit-1.5b"
              "--gpu-layers all"
              "--split-mode none"
              "--main-gpu 0"
              "--flash-attn on"
              "--ctx-size 8192"
              "--parallel 1"
              "--temperature 0.1"
              "--top-k 40"
              "--cache-type-k q8_0"
              "--cache-type-v q8_0"
            ];
          };
          "sweep-next-edit-v2-7b" = {
            cmd = serve [
              "--model"
              (modelPath "sweep-next-edit-v2-7b")
              "--alias"
              "sweep-next-edit-v2-7b"
              "--gpu-layers all"
              "--split-mode none"
              "--flash-attn on"
              "--ctx-size 32768"
              "--parallel 4"
              "--temperature 0.1"
              "--cache-reuse 256"
              "--cache-type-k q8_0"
              "--cache-type-v q8_0"
            ];
            concurrencyLimit = 4;
          };
          "gpt-oss-20b" = {
            cmd = serve [
              "--model"
              (modelPath "gpt-oss-20b")
              "--alias"
              "gpt-oss-20b"
            ];
          };
          "qwen3-coder-30b-a3b" = {
            cmd = serve [
              "--model"
              (modelPath "qwen3-coder-30b-a3b")
              "--alias"
              "qwen3-coder-30b-a3b"
              "--flash-attn on"
              "--ctx-size 262144"
              "--cache-type-k q4_0"
              "--cache-type-v q4_0"
              "--parallel 1"
              "--temperature 0.2"
              "--top-k 10"
              "--min-p 0"
              "--top-p 0.8"
              "--repeat-penalty 1.03"
            ];
            ttl = 3600;
            concurrencyLimit = 2;
          };
          "muse-glimmer-30b" = {
            cmd = serve [
              "--model"
              (modelPath "muse-glimmer-30b")
              "--alias"
              "muse-glimmer-30b"
              "--spec-draft-model"
              (modelPath "muse-glimmer-30b-draft")
              "--spec-draft-n-max 10"
              "--gpu-layers all"
              "--tensor-split 1,1"
              "--ctx-size 8192"
              "--parallel 1"
              "--flash-attn on"
              "--spec-type draft-dflash"
              "--spec-draft-ngl all"
              "--temperature 0.3"
              "--top-p 0.8"
              "--top-k 40"
              "--min-p 0"
              "--n-predict 512"
              "--jinja"
            ];
            ttl = 3600;
            concurrencyLimit = 1;
          };
          "qwen3.8-27b" = {
            cmd = serve [
              "--model"
              (modelPath "qwen3.8-27b")
              "--alias"
              "qwen3.8-27b"
              "--parallel 2"
              "--flash-attn on"
            ];
            ttl = 3600;
            concurrencyLimit = 3;
          };
          "nex-n2.5-mini" = {
            cmd = serve [
              "--model"
              (modelPath "nex-n2.5-mini")
              "--alias"
              "nex-n2.5-mini"
              "--parallel 4"
              "--ctx-size 32768"
              "--flash-attn on"
              "--jinja"
            ];
            ttl = 3600;
            concurrencyLimit = 8;
          };
          "minicpm5-2b" = {
            cmd = serve [
              "--model"
              (modelPath "minicpm5-2b")
              "--alias"
              "minicpm5-2b"
              "--parallel 4"
              "--ctx-size 32768"
              "--flash-attn on"
              "--jinja"
            ];
            ttl = 3600;
            concurrencyLimit = 8;
          };
          "nex-n2.5-mini-uncensored" = {
            cmd = serve [
              "--model"
              (modelPath "nex-n2.5-mini-uncensored")
              "--alias"
              "nex-n2.5-mini-uncensored"
              "--parallel 1"
              "--flash-attn on"
            ];
            ttl = 3600;
            concurrencyLimit = 1;
          };
          "qwen3-embedding-0.6b" = {
            cmd = serve [
              "--model"
              (modelPath "qwen3-embedding-0.6b")
              "--alias"
              "qwen3-embedding-0.6b"
              "--parallel 1"
              "--pooling last"
              "--embeddings"
              "--gpu-layers 999"
              "--ctx-size 4096"
              "--batch-size 2048"
              "--ubatch-size 2048"
            ];
          };
          "zeta-2.1" = {
            cmd = serve [
              "--model"
              (modelPath "zeta-2.1")
              "--alias"
              "zeta-2.1"
              "--parallel 2"
              "--spec-type ngram-mod,ngram-simple"
              "--spec-ngram-simple-size-n 12"
              "--spec-ngram-simple-size-m 16"
              "--spec-ngram-mod-n-match 24"
              "--spec-ngram-mod-n-min 8"
              "--spec-ngram-mod-n-max 16"
            ];
            concurrencyLimit = 2;
          };
          "qwen3.8-flash-next" = {
            name = "Qwen3.8 Flash Next IQ4 XS";
            # llama.cpp finds shards 2 and 3 next to the first one.
            cmd = serve [
              "--model"
              (modelPath "qwen3.8-flash-next-1")
              "--split-mode layer"
              "--ctx-size 65536"
              "--parallel 1"
              "--flash-attn on"
              "--cache-type-k q8_0"
              "--cache-type-v q8_0"
              "--ubatch-size 256"
              "--load-mode none"
              "--jinja"
              "--cont-batching"
              "--metrics"
              "-lv 4"
            ];
            concurrencyLimit = 4;
          };
          "hemmingway-1" = {
            name = "Hemmingway 1";
            cmd = serve [
              "--model"
              (modelPath "hemmingway-1")
              "--split-mode layer"
              "--parallel 1"
              "--flash-attn on"
              "--jinja"
            ];
            concurrencyLimit = 1;
          };
        };

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = ["qwen3.6-35b-a3b"];
        };
      };
    };
  };
}
