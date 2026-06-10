{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    zshConfig = pkgs.writeTextFile {
      name = "zsh-config";
      text = ''
        # prompt (zsh prefers PROMPT over PS1)
        PROMPT='[%n@%m %~]$--- '
        # aliases — eza is already on PATH via environment.nix
        alias ll='eza -l'
        alias la='eza -la'
        # zoxide
        if command -v zoxide >/dev/null; then
          eval "$(zoxide init zsh)"
        fi
      '';
      destination = "/.zshrc";
    };
  in {
    packages.zsh = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.zsh;
      runtimeInputs = [pkgs.zoxide];
      flags = {};
      env.ZDOTDIR = zshConfig;
    };
  };
}
