{...}: {
  flake.nixosModules.pi = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (import ../../network/services.nix) services;
  in {
    agentRuntime.harnesses.pi = let
      models = pkgs.writeText "pi-models.json" (builtins.toJSON {
        providers = {
          anthropic = {
            baseUrl = "https://${services.agent.name}";
            models = map (id: {
              inherit id;
              contextWindow = 1050000;
              maxTokens = 128000;
            }) ["gpt-5.6-luna" "gpt-5.6-terra" "gpt-5.6-sol" "gpt-6-astra"];
          };
          "v3x-inference" = {
            baseUrl = "https://${services.inference.name}/v1";
            api = "openai-completions";
            apiKey = "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.v3x_inference_token.path}";
            authHeader = true;
            models = map (id: {inherit id;}) [
              "v3x-m/gpt-oss-20b"
              "v3x-m/qwen3.8-27b"
              "v3x-t/qwen3.6-35b-a3b"
            ];
          };
        };
      });
      settings = pkgs.writeText "pi-settings.json" (builtins.toJSON {
        enableInstallTelemetry = false;
        # Let pi's fullscreen TUI own mouse selection and copy the underlying
        # message text to the clipboard (OSC 52) instead of the terminal
        # grabbing padded/soft-wrapped screen cells. Only takes effect in
        # fullscreen TUI mode.
        fullscreenCopyOnSelect = true;
      });
    in {
      command = ["pi"];
      glyph = "π";
      color = "139;233;253";
      blurb = "pi";
      logo = ../agent/icons/pi.png;
      package = pkgs.pi-coding-agent;
      inherit models settings;
    };
  };
}
