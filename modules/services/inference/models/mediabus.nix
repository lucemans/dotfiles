{mediabusModels, ...}: {
  _module.args = {
    mediabusModels = {
      "qwen3.6-35b-a3b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights = {
          repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
          rev = "a483e9e6cbd595906af30beda3187c2663a1118c";
          files."Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" = "707a55a8a4397ecde44de0c499d3e68c1ad1d240d1da65826b4949d1043f4450";
        };
        # DFlash2 drafter (inco.ai blog), an auxiliary block-diffusion model.
        fileArgs."--model-draft" = {
          repo = "aminya/Qwen3.6-35B-A3B-DFlash2-GGUF";
          rev = "1e26e3499d865b9d2fc55e019d65b3f0e8ab6846";
          files."Qwen3.6-35B-A3B-DFlash2-Q8_0.gguf" = "69bc81f5344dfeb67bcfc09277dd9617500fca1823f72e6e08d5df92e73a8b44";
        };
        args = [
          "--ctx-size 98304"
          "--n-gpu-layers 999"
          "--flash-attn on"
          "--spec-type draft-dflash"
          "--spec-draft-n-max 8"
          "--spec-draft-n-ubatch 512"
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
        litellm.model_info = {
          input_cost_per_token = 0.00000002;
          mode = "completion";
          output_cost_per_token = 0.00000002;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.00000018;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights = {
          repo = "unsloth/gpt-oss-20b-GGUF";
          rev = "d449b42d93e1c2c7bda5312f5c25c8fb91dfa9b4";
          files."gpt-oss-20b-F16.gguf" = "4e4f9cd88d6456e4f389e7262eca4a8d565211e2b22ece9ca7a8556168ff3c66";
        };
      };
      "qwen3-coder-30b-a3b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights = {
          repo = "unsloth/Qwen3.8-27B-GGUF";
          rev = "f1bfb127c64f7072bdd2cad55f258b9c8b2910fe";
          files."Qwen3.8-27B-UD-Q5_K_XL.gguf" = "176a6a3f034e9cdc447c10cd00329fc9b31002e6589b9295f2ad4f1eefe0f6ab";
        };
        # The repo moved the sidecar into an MTP/ folder after this rev; pin the
        # current rev for the draft file only.
        fileArgs."--model-draft" = {
          repo = "unsloth/Qwen3.8-27B-GGUF";
          rev = "4ca720788d1e01f1bff70c033e0d0028fd02e502";
          files."MTP/mtp-Qwen3.8-27B-Q4_0.gguf" = "50d9ce5a6da381bbcfb31061cf73df94a90e6faf8efeddee379a9cb8f1501c6e";
        };
        args = [
          "--spec-type draft-mtp"
          "--parallel 2"
          "--flash-attn on"
          "--spec-draft-n-max 6"
          "--spec-draft-n-ubatch 512"
        ];
        ttl = 3600;
        concurrencyLimit = 3;
      };
      "nex-n2.5-mini" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000001;
          mode = "chat";
          output_cost_per_token = 0.0000001;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.00000005;
          mode = "chat";
          output_cost_per_token = 0.00000005;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.0000001;
          mode = "chat";
          output_cost_per_token = 0.0000001;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.00000005;
          mode = "embedding";
          output_cost_per_token = 0.00000005;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.00000002;
          mode = "completion";
          output_cost_per_token = 0.00000002;
        };
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
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
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
        # The MTP drafter ships at the pinned rev under MTP/.
        fileArgs."--model-draft" = {
          repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
          rev = "38bb39ee97821de2c9009abb7e93950eec396e66";
          files."MTP/mtp-Qwen3.8-Flash-Next-Q4_K_M.gguf" = "b646ef60eaae2a9ed849e75f15f399629ca22633555e99e809959e95f22a1575";
        };
        args = [
          "--split-mode layer"
          "--ctx-size 65536"
          "--parallel 1"
          "--flash-attn on"
          "--spec-type draft-mtp"
          "--spec-draft-n-max 6"
          "--spec-draft-n-ubatch 512"
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
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        name = "Hemmingway 1";
        weights = {
          repo = "bartowski/Altworld_Hemmingway-1-GGUF";
          rev = "259605e26a47f2dcc8731ae1aa7305f8047d2c6d";
          files."Altworld_Hemmingway-1-Q4_K_M.gguf" = "c029ba6cc24bc022a65d00e4d81796ff0bd678e371a36c9a7d1119a0acc7085e";
        };
        # The quants carry MTP layers at Q4_0; the drafter needs no extra file.
        args = [
          "--split-mode layer"
          "--parallel 1"
          "--flash-attn on"
          "--spec-type draft-mtp"
          "--spec-draft-n-max 6"
          "--jinja"
        ];
        concurrencyLimit = 1;
      };

      # Flint: Recursive's 39.8B-A2.5B coding-agent MoE, Terminal-Bench 2.1 54.9%,
      # SWE-bench Verified 74.2%. Needs the b11912 build (FlintForCausalLM #30928).
      # Q4_K_M keeps the non-expert tensors at Q8_0.
      "flint-1" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        llama-cpp = "b11912";
        weights = {
          repo = "ggml-org/Flint-GGUF";
          rev = "468307a1b38259e9e4c9d4fe53d4e3b76386572c";
          files."Flint-Q4_K_M.gguf" = "c3c4d93f9db92627a2fc47ea8fe8c64a094cabd3549db544bcdd2c00e9a9a347";
        };
        args = [
          "--split-mode layer"
          "--ctx-size 65536"
          "--flash-attn on"
          "--jinja"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 2;
      };

      # Nanbeige4.3-33B: dense Llama arch (no new code), 512k context, claims
      # state-of-the-art agentic performance in the ~30B class. Released Oct 24.
      "nanbeige4.3-33b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights = {
          repo = "bartowski/Nanbeige_Nanbeige4.3-33B-GGUF";
          rev = "9beb68421fdf7be095093a6888325fa2c83ddd38";
          files."Nanbeige_Nanbeige4.3-33B-Q4_K_M.gguf" = "2cef79855ca47ee6571e166db32a07089e34f3cf78e0397b262d124ddb814c37";
        };
        args = [
          "--split-mode layer"
          "--ctx-size 65536"
          "--flash-attn on"
          "--cache-type-k q8_0"
          "--cache-type-v q8_0"
          "--jinja"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 2;
      };

      # Sage-A1.5: Shanghai AI Lab's agentic fine-tune of Qwen3.6-35B-A3B, same
      # qwen3_5_moe architecture as the workhorse. Q4_K_M fits the A4000 pair.
      "sage-a1.5" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        weights = {
          repo = "InternScience/Sage-A1.5-Q4_K_M-GGUF";
          rev = "10b179b52f2c841030db327627e707d076b4c8cf";
          files."Sage-A1.5-Q4_K_M.gguf" = "a64fe0bbf936db3eb54f66f142c2b2eee569ade83673649f549a21daef8ca395";
        };
        fileArgs."--mmproj".files."Sage-A1.5-mmproj.gguf" = "51cd4410057e8dc4152ca771a726fbfb34856f047e7049018c757d42ddd481f2";
        args = [
          "--split-mode layer"
          "--ctx-size 65536"
          "--flash-attn on"
          "--cache-type-k q4_0"
          "--cache-type-v q4_0"
          "--jinja"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 2;
      };

      # Spark-X2.6-4B: on-device agent model, 1M context claimed, replaces
      # MiniCPM5-2B's lane at the same size class. spark2_5 arch since b10828.
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
          "--gpu-layers all"
          "--split-mode none"
          "--main-gpu 0"
          "--ctx-size 65536"
          "--flash-attn on"
          "--jinja"
          "--parallel 4"
          "--no-webui"
        ];
        ttl = 3600;
        concurrencyLimit = 8;
      };

      # Ternary-Bonsai-2-27B: Qwen3.8-27B retrained at 2-bit ternary weights,
      # PQ2_0 runs from 7.2 GB on stock llama.cpp. mmproj gives it vision.
      "bonsai-2-27b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000001;
          mode = "chat";
          output_cost_per_token = 0.0000001;
        };
        weights = {
          repo = "prism-ml/Ternary-Bonsai-2-27B-gguf";
          rev = "b072e1d3b35a0a630cece372c2127528e0994386";
          files."Ternary-Bonsai-2-27B-PQ2_0.gguf" = "3907dc1658db1f78a9826bf8d5bcb8dc65db0d466388937af57f2294fae62ec1";
        };
        fileArgs."--mmproj".files."Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf" = "6807ede61d570bb86ba34b756a0fa109edc33668604de867c6ea6d8f1d631903";
        args = [
          "--split-mode layer"
          "--ctx-size 32768"
          "--flash-attn on"
          "--jinja"
          "--parallel 2"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 2;
      };

      # pplx-decider-flash-v1.2: Perplexity's 4.5B decision model on the same
      # /v1/systemone API as clef-flash, distilled from the 27B deciders. A second
      # judge lane on the small card, no llama.cpp code needed (qwen3_5 arch).
      "pplx-decider-flash" = {
        litellm.model_name = "pplx-decider-flash";
        litellm.model_info = {
          mode = "decisions";
        };
        weights = {
          repo = "perplexity-ai/pplx-decider-flash-gguf-v1.2";
          rev = "2514d5f0b7fbbe1ee1bfec9ffb5801a60289b4cc";
          files."decider-flash-v1.2-q8_0.gguf" = "ffb27ade8976765b0e6943a0b7f5f3fd0f7042d45ad90256a76d608bcd3942c2";
        };
        fileArgs."--mmproj".files."mmproj-decider-flash-v1.2-f16.gguf" = "b2459e42a5f12c9ecbc81742a91cb93b6bbe5082297b4aa9578d453ddcbecfab";
        args = [
          "--ctx-size 8192"
          "--batch-size 8192"
          "--ubatch-size 8192"
          "--flash-attn on"
          "--parallel 1"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 16;
      };

      # Humanizer-12B: Gemma 4 text-completion model that rewrites a draft so it does not
      # read like a language model. Pinned to the second A4000, so it stays loaded next to
      # qwen2.5-coder-7b-fim on the first. The Q4_K_M file is the quantization-aware one:
      # within noise of bf16 on the task, and 5 GB smaller than Q8_0, which buys the f16
      # KV cache and a 512-token ubatch instead of a layer split across PCIe.
      "humanizer-12b" = {
        litellm.model_info = {
          input_cost_per_token = 0.0000002;
          mode = "chat";
          output_cost_per_token = 0.0000002;
        };
        name = "Humanizer 12B";
        env = ["CUDA_VISIBLE_DEVICES=1"];
        weights = {
          repo = "jialinyyzz/humanizer-GGUF";
          rev = "d9c6be435fe29e6e96dc42f4c3cc185e06ae3eac";
          files."humanizer-12b-Q4_K_M.gguf" = "2229574dec5178629575ee4a153dfee7d9e924ab997d0ad9d2ac622b67e44834";
        };
        args = [
          "--gpu-layers all"
          "--split-mode none"
          "--main-gpu 0"
          "--flash-attn on"
          # Trained and evaluated at 8k. Its sliding-window layers cap their own cache at
          # 1024 tokens, so an f16 KV cache costs about 2.6 GiB at 8k.
          "--ctx-size 8192"
          "--batch-size 2048"
          "--ubatch-size 512"
          "--parallel 1"
          # A rewrite reuses the draft's numbers, names and quotes, so ngram speculation
          # drafts them out of the context. It is lossless: the sampled tokens do not change.
          "--spec-type ngram-mod,ngram-simple"
          "--spec-ngram-simple-size-n 12"
          "--spec-ngram-simple-size-m 16"
          "--spec-ngram-mod-n-match 24"
          "--spec-ngram-mod-n-min 8"
          "--spec-ngram-mod-n-max 16"
          # The file's chat template builds instr + draft + sep from the last user message,
          # and its stored defaults are the sampling below.
          "--jinja"
          "--temp 1.0"
          "--top-p 0.95"
          "--top-k 0"
          "--min-p 0"
          "--repeat-penalty 1.0"
          "--n-predict 2048"
          "--no-webui"
        ];
        ttl = 900;
        concurrencyLimit = 2;
      };
    };
  };

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

    served = engine mediabusModels;
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
          members = [
            "qwen3.6-35b-a3b"
            "flint-1"
            "nanbeige4.3-33b"
            "sage-a1.5"
            "bonsai-2-27b"
          ];
        };

        groups.smol = {
          swap = true;
          exclusive = false;
          persistent = true;
          members = [
            "nex-n2.5-mini"
          ];
        };
      };
    };
  };
}
