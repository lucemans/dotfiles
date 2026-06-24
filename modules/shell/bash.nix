{
  inputs,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: let
    bashConfig = pkgs.writeTextFile {
      name = "bash-config";
      text = ''
        PS1='%(?.%F{green}✓%f.%F{red}✗%f) %F{blue}%n@%m%f
        %F{cyan}%~%f%F{yellow}$(git_info)%f
        %# '
        alias ll='eza -l'
        alias la='eza -la'
        alias edit='nvim'
        alias upgrade='sudo nixos-rebuild switch --flake /etc/nixos#v3x-fighter'
      '';
      destination = "/.bashrc";
    };
  in {
    packages.bash = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.bash;
      runtimeInputs = [pkgs.bash-completion];
      flags = {};
      env.BASHRC = bashConfig;
    };
  };
}
