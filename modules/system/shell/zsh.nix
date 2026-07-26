{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    zshConfig = pkgs.writeTextFile {
      name = "zsh-config";
      text = ''
        HISTFILE="''${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
        HISTSIZE=10000
        SAVEHIST=10000
        mkdir -p -- "''${HISTFILE:h}"
        setopt SHARE_HISTORY
        setopt HIST_FCNTL_LOCK
        setopt HIST_IGNORE_DUPS

        # Find completions shipped by packages in the system and Home Manager profiles.
        for p in ''${(z)NIX_PROFILES}; do
          fpath=(
            $p/share/zsh/site-functions
            $p/share/zsh/$ZSH_VERSION/functions
            $p/share/zsh/vendor-completions
            $fpath
          )
        done

        autoload -Uz compinit
        compinit

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
          v3x-teapot)
            host_color=pink
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
        compdef _nvim edit
        alias edit='nvim'
        compdef _pnpm p
        alias p='pnpm'
        compdef _pnpm why
        alias why='pnpm'
        compdef _pnpm y
        alias y='pnpm'
        compdef _just j
        alias j='just'

        compdef _kubectl k
        alias k='kubectl'

        alias reload-plasma='systemctl --user restart plasma-plasmashell.service'

        ssh() {
          if [[ -t 0 && -t 1 ]] && command -v kitten >/dev/null; then
            kitten ssh "$@"
          else
            command ssh "$@"
          fi
        }

        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
        ZSH_AUTOSUGGEST_STRATEGY=(history completion)

        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        bindkey '^F' autosuggest-accept
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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
