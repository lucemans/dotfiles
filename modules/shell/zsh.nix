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
                PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%n@%m%f
        %F{cyan}%~%f%F{yellow}$(git_info)%f
        %# '
                # aliases — eza is already on PATH via environment.nix
                alias ll='eza -l'
                alias la='eza -la'
                alias edit='nvim'

                alias upgrade='sudo nixos-rebuild switch --flake /etc/nixos#v3x-fighter'

                # zoxide
                if command -v zoxide >/dev/null; then
                  eval "$(zoxide init zsh)"
                fi

                eval "$(direnv hook zsh)"
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
