_: {
  flake.nixosModules.ingestarrAi = _: {
    services.ingestarr.settings.source = [
      {
        key = "arxiv-cl";
        name = "arXiv cs.CL";
        kind = "arxiv";
        arxiv = {
          category = "cs.CL";
          keywords = ["speculative decoding" "diffusion language model" "KV cache"];
        };
      }
      {
        key = "hf-ggml-org";
        name = "Hugging Face ggml-org";
        kind = "huggingface";
        icon = "llama-cpp";
        huggingface.author = "ggml-org";
      }
      {
        key = "hf-qwen";
        name = "Hugging Face Qwen";
        kind = "huggingface";
        huggingface.author = "Qwen";
      }
      {
        key = "hf-trending-text";
        name = "Hugging Face trending text models";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "text-generation";
          top = 10;
        };
      }
      {
        key = "librechat-image";
        name = "LibreChat image";
        kind = "container-registry";
        icon = "librechat";
        container-registry = {
          image = "registry.librechat.ai/danny-avila/librechat-dev";
          track = "latest";
        };
      }
      {
        key = "vllm-omni-image";
        name = "vLLM-Omni image";
        kind = "container-registry";
        icon = "vllm";
        container-registry = {
          image = "vllm/vllm-omni";
          tags = ''^v\d+\.\d+\.\d+$'';
        };
      }
      {
        key = "claude-code-npm";
        name = "Claude Code";
        kind = "package";
        icon = "claude";
        package = {
          registry = "npm";
          name = "@anthropic-ai/claude-code";
        };
      }
    ];
  };
}
