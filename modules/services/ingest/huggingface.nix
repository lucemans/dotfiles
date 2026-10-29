_: {
  flake.nixosModules.ingestarrHuggingface = _: {
    services.ingestarr.settings.source = [
      {
        key = "huggingface-trending-text";
        name = "Hugging Face trending: text";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "text-generation";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-tts";
        name = "Hugging Face trending: text-to-speech";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "text-to-speech";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-stt";
        name = "Hugging Face trending: speech recognition";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "automatic-speech-recognition";
          top = 10;
        };
      }
      {
        key = "huggingface-trending-embedding";
        name = "Hugging Face trending: embedding";
        kind = "huggingface";
        huggingface = {
          trending = "models";
          pipeline_tag = "feature-extraction";
          top = 10;
        };
      }
      {
        key = "huggingface-ggml-org";
        name = "Hugging Face ggml-org";
        kind = "huggingface";
        icon = "llama-cpp";
        huggingface.author = "ggml-org";
      }
      {
        key = "huggingface-qwen";
        name = "Hugging Face Qwen";
        kind = "huggingface";
        huggingface.author = "Qwen";
      }
      {
        key = "huggingface-deepseek-ai";
        name = "Hugging Face DeepSeek";
        kind = "huggingface";
        icon = "llama-cpp";
        huggingface.author = "deepseek-ai";
      }
      {
        key = "huggingface-openai";
        name = "Hugging Face OpenAI";
        kind = "huggingface";
        huggingface.author = "openai";
      }
      {
        key = "huggingface-cloudflare";
        name = "Hugging Face Cloudflare";
        kind = "huggingface";
        huggingface.author = "Cloudflare";
      }
      {
        key = "huggingface-google";
        name = "Hugging Face Google";
        kind = "huggingface";
        huggingface.author = "google";
      }
      {
        key = "huggingface-nvidia";
        name = "Hugging Face Nvidia";
        kind = "huggingface";
        huggingface.author = "nvidia";
      }
      {
        key = "huggingface-meta-models";
        name = "Hugging Face Meta Models";
        kind = "huggingface";
        huggingface.author = "meta-models";
      }
      {
        key = "huggingface-meta-llama";
        name = "Hugging Face Meta Llama";
        kind = "huggingface";
        huggingface.author = "meta-llama";
      }
      {
        key = "huggingface-facebook";
        name = "Hugging Face Facebook";
        kind = "huggingface";
        huggingface.author = "facebook";
      }
      {
        key = "huggingface-openbmb";
        name = "Hugging Face OpenBMB";
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
