_: {
  flake.nixosModules.ingestarrContainers = _: {
    services.ingestarr.settings.source = [
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
    ];
  };
}
