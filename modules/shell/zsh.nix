{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    zshConfig = pkgs.writeTextFile {
      name = "zsh-config";
      text = ''
        autoload -Uz vcs_info
        zstyle ':vcs_info:*' enable git
        zstyle ':vcs_info:git:*' check-for-changes true
        zstyle ':vcs_info:git:*' stagedstr '%F{green}+%f%F{yellow}'
        zstyle ':vcs_info:git:*' unstagedstr '%F{red}*%f%F{yellow}'
        zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b%u%c)%f'

        precmd() {
          vcs_info
        }

        setopt prompt_subst
        PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%n@%m%f
        %F{cyan}%~%f''${vcs_info_msg_0_}
        %# '

        alias ll='eza -l'
        alias la='eza -la'
        alias edit='nvim'

        alias upgrade='sudo nixos-rebuild switch --flake /etc/nixos#v3x-fighter'

        if command -v zoxide >/dev/null; then
          eval "$(zoxide init zsh)"
        fi

        if command -v direnv >/dev/null; then
          eval "$(direnv hook zsh)"
        fi
      '';
      destination = "/.zshrc";
    };
  in {
    packages.zsh = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.zsh;
      runtimeInputs = [
        pkgs.direnv
        pkgs.zoxide
      ];
      flags = {};
      env.ZDOTDIR = zshConfig;
    };
  };
}
