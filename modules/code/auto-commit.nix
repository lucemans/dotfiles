{inputs, ...}: {
  flake.nixosModules.auto-commit = {config, ...}: {
    imports = [
      inputs.auto-commit.nixosModules.default
    ];

    sops = {
      secrets = {
        auto_commit_endpoint = {
          owner = "luc";
          mode = "0400";
        };
        auto_commit_token = {
          owner = "luc";
          mode = "0400";
        };
      };
    };

    programs.auto-commit = {
      enable = true;
      endpoint.file = config.sops.secrets.auto_commit_endpoint.path;
      apiKey.file = config.sops.secrets.auto_commit_token.path;
      model = "v3x-m/qwen3.6-35b-a3b";
      settings = {
        context_commits = 10;
        max_tool_calls = 3;
        candidates = 3;
      };
    };
  };
}
