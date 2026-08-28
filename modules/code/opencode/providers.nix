{
  flake.nixosModules.inference = {
    config,
    lib,
    ...
  }: {
    options.inference.providers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };

    config = {
      sops.secrets.v3x_inference_token = {
        owner = "luc";
        mode = "0400";
      };

      inference.providers.v3x-inference = {
        npm = "@ai-sdk/openai-compatible";
        name = "V3X Inference";
        options = {
          baseURL = "https://inference.v3x.host/v1";
          apiKey = "{file:${config.sops.secrets.v3x_inference_token.path}}";
        };
        models = {
          "v3x-m/qwen3.8-27b" = {
            name = "Qwen3.8 27B";
          };
          "zeroparams/jonatan" = {
            name = "Jonatan";
          };
          "z-ai/glm-5.3-flash" = {
            name = "GLM-5.3-Flash";
          };
        };
      };
    };
  };
}
