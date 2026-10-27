{teapotModels, ...}: {
  _module.args = {
    teapotModels = {
      "qwen3.6-35b-a3b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights.path = "/var/lib/llama-models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
        args = [
          "--ctx-size 131072"
          "--flash-attn on"
          "--cache-type-k q8_0"
          "--cache-type-v q8_0"
          "--jinja"
          "--temp 1.0"
          "--top-p 0.95"
          "--top-k 20"
          "--min-p 0.0"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 10;
      };

      # A decision model: it serves only /v1/systemone, reached through
      # /upstream/clef-flash/v1/systemone. The whole prompt must fit in one ubatch.
      "clef-flash" = {
        litellm.model_name = "clef-flash";
        litellm.model_info = {
          mode = "decisions";
        };
        weights = {
          repo = "ggml-org/Clef-Flash-GGUF";
          rev = "4a192915ef971886004b5b13294f2b4c7a7fc39d";
          files."Clef-Flash-Q4_K_M.gguf" = "fd3e90605e8103307dca37cb5a8cdb036267e2fe3cb2d908d80a8ceb9ec0638c";
        };
        fileArgs."--mmproj".files."mmproj-Clef-Flash-Q8_0.gguf" = "3fbc646617c56c35ba48e06f0fbe8693a83bde49eb31e2a3bf59ba0a308c9e25";
        args = [
          "--ctx-size 8192"
          "--batch-size 8192"
          "--ubatch-size 8192"
          "--flash-attn on"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        # Above the default 10: one `find` keeps 16 judgments in flight, and
        # llama-server queues them on its single slot.
        concurrencyLimit = 32;
      };

      # A non-causal model embeds each input in one ubatch, so the ubatch
      # size caps the input length. No ttl: a cold load takes over a minute,
      # longer than Mnemopi's 30 s request timeout.
      "embeddinggemma-2" = {
        litellm.model_info = {
          input_cost_per_token = 0.00000005;
          mode = "embedding";
        };
        weights = {
          repo = "ggml-org/embeddinggemma-2-GGUF";
          rev = "bfcd298762cc34d0357ece5ebdd31791a3a374d8";
          files."embeddinggemma-2-Q8_0.gguf" = "2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135";
        };
        args = [
          "--embeddings"
          "--ctx-size 8192"
          "--batch-size 8192"
          "--ubatch-size 8192"
          "--parallel 1"
          "--no-webui"
        ];
      };

      # Spark-X2.6-4B: on-device agent model, 1M context claimed. Q8_0 fits the
      # card next to the speech server; the tiny title-generator and role move here.
      "spark-x2.6-4b" = {
        litellm.model_info = {
          input_cost_per_token = 0.00000005;
          mode = "chat";
          output_cost_per_token = 0.00000005;
        };
        weights = {
          repo = "XHToken/Spark-X2.6-4B-GGUF";
          rev = "83b47fda018fd14f51aa63341f78266f628af5a5";
          files."Spark-X2.6-4B-Q8_0.gguf" = "145c2aa606820663f26ad530b8fc141ed885e2e9ca29f9be7c3bfe8931d58b81";
        };
        args = [
          "--ctx-size 16384"
          "--flash-attn on"
          "--jinja"
          "--parallel 2"
          "--no-webui"
        ];
        ttl = 600;
        concurrencyLimit = 4;
      };
    };
  };

  flake.nixosModules.teapotInference = {
    lib,
    pkgs,
    ...
  }: let
    engine = import ../engine {inherit lib pkgs;} {
      # The i7-12700K.
      cpuFlags = [
        "GGML_SSE42"
        "GGML_AVX"
        "GGML_F16C"
        "GGML_FMA"
        "GGML_AVX2"
        "GGML_BMI2"
        "GGML_AVX_VNNI"
      ];
      # qwen3.6 runs a q8_0 KV cache, the other models f16.
      flashAttnQuants = "q8_0-q8_0;f16-f16";
      fetch = "store";
    };

    served = engine teapotModels;
  in {
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
        models = served.swap;

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = [
            "qwen3.6-35b-a3b"
            "clef-flash"
            "spark-x2.6-4b"
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
