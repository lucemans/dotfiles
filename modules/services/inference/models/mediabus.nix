{
  flake.nixosModules.mediabusInference = {
    lib,
    pkgs,
    ...
  }: let
    modelsDir = "/var/lib/llama-models";

    engine = import ../engine {inherit lib pkgs;} {
      # The Ryzen 9 7900 (Zen 4).
      cpuFlags = [
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
      ];
      # The models use q4_0, q8_0 or f16 KV caches, with the same type for K and V.
      flashAttnQuants = "q4_0-q4_0;q8_0-q8_0;f16-f16";
      fetch = "runtime";
      dir = modelsDir;
    };

    served = engine {
      "qwen3.6-35b-a3b" = {
        weights = {
          repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
          rev = "a483e9e6cbd595906af30beda3187c2663a1118c";
          files."Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" = "707a55a8a4397ecde44de0c499d3e68c1ad1d240d1da65826b4949d1043f4450";
        };
        args = [
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
        weights = {
          repo = "ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF";
          rev = "8be1b8a895a84beea772817caaa71eba6b6e0d07";
          files."qwen2.5-coder-1.5b-q8_0.gguf" = "29871c94d15727a6e243f79a37113d4ae625a6215b5e800bf41a23af2da32832";
        };
        args = [
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
        weights = {
          repo = "ggml-org/Qwen3-8B-GGUF";
          rev = "bbd9eb5efae3fd6d45dd620650916346d7cecc67";
          files."Qwen3-8B-Q8_0.gguf" = "2f98cff159bcdf01431829406d43363ccacb76ed6b76d18bd9d6ab20976792c0";
        };
        fileArgs."--model-draft".files."dflash-Qwen3-8B-Q8_0.gguf" = "89a3d462b8e945c602599a91ab2329aa387f677d88383d0e23253b9f0082e502";
        args = [
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
        weights = {
          repo = "ggml-org/Qwen2.5-Coder-7B-Q8_0-GGUF";
          rev = "bca77e0a8c88fc224882bcc404170c3ef17efacc";
          files."qwen2.5-coder-7b-q8_0.gguf" = "0ef48dc94a3c551a6736ac2601de38413dc9aa9318534b16e8baee08290a4aaf";
        };
        args = [
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
        weights = {
          repo = "sweepai/sweep-next-edit-1.5B";
          rev = "409016591c6c1a94f545f22328a85a3516118f34";
          files."sweep-next-edit-1.5b.q8_0.v2.gguf" = "1321ea5e5d7529e60f9770c6a0b3a965f89542d16cf4ae51bab267f6a88150da";
        };
        args = [
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
        weights = {
          repo = "henrik3/sweep-next-edit-v2-7B-GGUF";
          rev = "f88a6bc2316f6b7f9581668ae51909478d13e685";
          files."q5_k_m.gguf" = "e232581569e4584de3afdfeb06d7fba2a1298d0d3a1e4c2b513927d7a495dc46";
        };
        args = [
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
        weights = {
          repo = "unsloth/gpt-oss-20b-GGUF";
          rev = "d449b42d93e1c2c7bda5312f5c25c8fb91dfa9b4";
          files."gpt-oss-20b-F16.gguf" = "4e4f9cd88d6456e4f389e7262eca4a8d565211e2b22ece9ca7a8556168ff3c66";
        };
      };
      "qwen3-coder-30b-a3b" = {
        weights = {
          repo = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
          rev = "b17cb02dd882d5b6ab62fc777ad2995f19668350";
          files."Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf" = "fadc3e5f8d42bf7e894a785b05082e47daee4df26680389817e2093056f088ad";
        };
        args = [
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
        weights = {
          repo = "meta-models/Muse-Glimmer-30B-GGUF";
          rev = "a0532f7263ee67f1e0a5f5c5fdcd50dd62fc9aa4";
          files."muse-glimmer-30B-kquant-17gb.gguf" = "7e9b74b7c8875e9e265695df9613bf6290f2392e479ce740495a129019c488d8";
        };
        fileArgs."--spec-draft-model".files."dflash-kquant.gguf" = "27d9a805fa29b943cfb6ad4843367cd4eaaaf06bd452d8cc3e00a2cd18a677bc";
        args = [
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
        weights = {
          repo = "unsloth/Qwen3.8-27B-GGUF";
          rev = "f1bfb127c64f7072bdd2cad55f258b9c8b2910fe";
          files."Qwen3.8-27B-UD-Q5_K_XL.gguf" = "176a6a3f034e9cdc447c10cd00329fc9b31002e6589b9295f2ad4f1eefe0f6ab";
        };
        args = [
          "--parallel 2"
          "--flash-attn on"
        ];
        ttl = 3600;
        concurrencyLimit = 3;
      };
      "nex-n2.5-mini" = {
        weights = {
          repo = "bartowski/nex-agi_Nex-N2.5-mini-GGUF";
          rev = "0048da1ad2ad33fdcf8b24bc12185cdebfe459d6";
          files."nex-agi_Nex-N2.5-mini-Q4_0.gguf" = "0fe15b40ff686e4389eeb9b193ca2dc4380e40039594d573a1335f738d72155b";
        };
        args = [
          "--parallel 4"
          "--ctx-size 32768"
          "--flash-attn on"
          "--jinja"
        ];
        ttl = 3600;
        concurrencyLimit = 8;
      };
      "minicpm5-2b" = {
        weights = {
          repo = "bartowski/MiniCPM5-2B-GGUF";
          rev = "31fee0334c4ed9f1e079afe586ba30cb83e0f883";
          files."MiniCPM5-2B-bf16.gguf" = "92b5df1d7e1444fa0baa925521130e367cf1267edd66904cbf0afe281765382c";
        };
        args = [
          "--parallel 4"
          "--ctx-size 32768"
          "--flash-attn on"
          "--jinja"
        ];
        ttl = 3600;
        concurrencyLimit = 8;
      };
      "nex-n2.5-mini-uncensored" = {
        weights = {
          repo = "orcarouter/Nex-N2.5-mini-Uncensored-GGUF";
          rev = "59f36a2cd1e5c64139e271b5b406a014b68109ef";
          files."Nex-N2.5-mini-Uncensored-Q3_K_M.gguf" = "09b29439812458a2a4f0d0d61998ddd5ecba8eb49e7604793f420ee9b2cee3ec";
          gated = true;
        };
        args = [
          "--parallel 1"
          "--flash-attn on"
        ];
        ttl = 3600;
        concurrencyLimit = 1;
      };
      "qwen3-embedding-0.6b" = {
        weights = {
          repo = "Qwen/Qwen3-Embedding-0.6B-GGUF";
          rev = "370f27d7550e0def9b39c1f16d3fbaa13aa67728";
          files."Qwen3-Embedding-0.6B-f16.gguf" = "421a27e58d165478cc7acb984a688c2aa41404968b0203e7cd743ece44c54340";
        };
        args = [
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
        weights = {
          repo = "mradermacher/zeta-2.1-i1-GGUF";
          rev = "92c5ffc501a76d9c92bd04c0022cebfffa461dc8";
          files."zeta-2.1.i1-Q4_K_M.gguf" = "216ddb5722a49f9ff49b21a050c4db3c801ef6f34e4bd1702d5db43e3325b076";
        };
        args = [
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
        weights = {
          repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
          rev = "38bb39ee97821de2c9009abb7e93950eec396e66";
          files = {
            "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf" = "5ce89370720f8bf90890f439361282104c1aa1482d4013bb9a50923e758e71a4";
            "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00002-of-00003.gguf" = "577a38a2392b40ca2193cea502e1d92f60b8cd370675d308e0ec21885d9daaa7";
            "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00003-of-00003.gguf" = "d4634e6d84f0ebb0940be15c90d3790bf6464e3dea3a1cddc567dc0e83ad8833";
          };
        };
        alias = null;
        args = [
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
        weights = {
          repo = "bartowski/Altworld_Hemmingway-1-GGUF";
          rev = "259605e26a47f2dcc8731ae1aa7305f8047d2c6d";
          files."Altworld_Hemmingway-1-Q4_K_M.gguf" = "c029ba6cc24bc022a65d00e4d81796ff0bd678e371a36c9a7d1119a0acc7085e";
        };
        alias = null;
        args = [
          "--split-mode layer"
          "--parallel 1"
          "--flash-attn on"
          "--jinja"
        ];
        concurrencyLimit = 1;
      };
    };
  in {
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
        ExecStart = lib.getExe (import ../engine/model-fetch.nix {inherit lib pkgs;} served.files);
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

        models = served.swap;

        groups.local-gpu = {
          swap = true;
          exclusive = true;
          members = ["qwen3.6-35b-a3b"];
        };
      };
    };
  };
}
