_: {
  flake.nixosModules.ingestarrHuggingface = _: {
    services.ingestarr.settings.source = [
      {
        key = "huggingface-trending-text";
        name = "HF Trending LLM";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "text-generation";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-tts";
        name = "HF Trending TTS";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "text-to-speech";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-stt";
        name = "HF Trending STT";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "automatic-speech-recognition";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-embedding";
        name = "HF Trending Embed";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "feature-extraction";
          top = 10;
        };
      }
      {
        key = "huggingface-ggml-org";
        name = "HF ggml-org";
        kind = "huggingface";
        icon = "llama-cpp";
        huggingface.author = "ggml-org";
      }
      {
        key = "huggingface-qwen";
        name = "HF Qwen";
        kind = "huggingface";
        huggingface.author = "Qwen";
      }
      {
        key = "huggingface-deepseek-ai";
        name = "HF DeepSeek";
        kind = "huggingface";
        icon = "llama-cpp";
        huggingface.author = "deepseek-ai";
      }
      {
        key = "huggingface-openai";
        name = "HF OpenAI";
        kind = "huggingface";
        huggingface.author = "openai";
      }
      {
        key = "huggingface-cloudflare";
        name = "HF Cloudflare";
        kind = "huggingface";
        huggingface.author = "Cloudflare";
      }
      {
        key = "huggingface-google";
        name = "HF Google";
        kind = "huggingface";
        huggingface.author = "google";
      }
      {
        key = "huggingface-nvidia";
        name = "HF Nvidia";
        kind = "huggingface";
        huggingface.author = "nvidia";
      }
      {
        key = "huggingface-meta-models";
        name = "HF Meta Models";
        kind = "huggingface";
        huggingface.author = "meta-models";
      }
      {
        key = "huggingface-meta-llama";
        name = "HF Meta Llama";
        kind = "huggingface";
        huggingface.author = "meta-llama";
      }
      {
        key = "huggingface-facebook";
        name = "HF Facebook";
        kind = "huggingface";
        huggingface.author = "facebook";
      }
      {
        key = "huggingface-openbmb";
        name = "HF OpenBMB";
        kind = "huggingface";
        huggingface.author = "openbmb";
      }
    ];

    services.ingestarr.collections = [
      {
        name = "huggingface";
        title = "Hugging Face";
        kinds = ["huggingface"];
      }
    ];
  };
}
