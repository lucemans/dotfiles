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

        host_name=''${HOST%%.*}
        case "$host_name" in
          v3x-fighter)
            host_color=blue
            ;;
          v3x-mission)
            host_color=magenta
            ;;
          v3x-point)
            host_color=yellow
            ;;
          *)
            host_color=blue
            ;;
        esac

        precmd() {
          vcs_info
          print -Pn "\e]2;%n@%m\a"
        }

        setopt prompt_subst
        PROMPT='%F{blue}%n@%f%F{$host_color}%m%f %F{cyan}%~%f''${vcs_info_msg_0_} %(?.%F{green}✓%f.%F{red}✗%f)
        - '

        alias ll='eza -l'
        alias la='eza -la'
        alias edit='nvim'
        alias p='pnpm'
        alias why='pnpm'
        alias k='kubectl'
        alias j='just'

        alias update='cd /etc/nixos && git pull'
        alias upgrade='sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)'
        alias reload-plasma='systemctl --user restart plasma-plasmashell.service'

        ssh() {
          if [[ -t 0 && -t 1 ]] && command -v kitten >/dev/null; then
            kitten ssh "$@"
          else
            command ssh "$@"
          fi
        }

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
