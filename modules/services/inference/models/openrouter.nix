{
  "openai/gpt-5.6-luna" = {
    model_info = {
      base_model = "gpt-5.6-luna";
      mode = "chat";
    };
  };
  "openai/gpt-6-luna" = {
    model_info = {
      base_model = "gpt-6-luna";
      mode = "chat";
    };
  };
  "openai/gpt-oss-120b" = {
    model_info = {
      base_model = "openai/gpt-oss-120b";
      mode = "chat";
    };
  };
  "z-ai/glm-5.3-flash" = {
    litellm_params = {
      provider = {
        allow_fallbacks = true;
        order = [
          "baseten"
          "z-ai"
        ];
      };
    };
    model_info = {
      base_model = "z-ai/glm-5.3-flash";
      mode = "chat";
    };
  };
  "openrouter/deepseek/deepseek-v4.1-flash" = {
    litellm_params = {
      provider = {
        allow_fallbacks = false;
        ignore = [
          "baseten/fast"
        ];
        order = [
          "deepinfra/fp8"
          "baseten"
        ];
      };
    };
    model_info = {
      base_model = "deepseek/deepseek-v4.1-flash";
      mode = "chat";
      supports_reasoning = true;
    };
  };
  "openrouter/deepseek/deepseek-v4.1-flash-1017" = {
    litellm_params = {
      provider = {
        allow_fallbacks = false;
        order = [
          "deepinfra/fp8"
          "relace"
          "inference-net/fp8"
          "cloudflare"
          "together"
        ];
      };
    };
    model_info = {
      base_model = "deepseek/deepseek-v4.1-flash-1017";
      mode = "chat";
      supports_reasoning = true;
    };
  };
  "openrouter/*" = {
  };
}
