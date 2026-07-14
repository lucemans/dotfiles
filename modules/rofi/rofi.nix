{self, ...}: {
  flake.nixosModules.rofi = {pkgs, ...}: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    rofi-vscode = pkgs.writeShellApplication {
      name = "rofi-vscode";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        pkgs.sqlite
        pkgs.vscodium
      ];
      text = builtins.readFile ./vscode.sh;
    };
    rofi-doubletake = pkgs.writeShellApplication {
      name = "rofi-doubletake";
      runtimeInputs = [
        pkgs.avahi
        pkgs.gawk
        pkgs.kitty
        pkgs.procps
        pkgs.util-linux
        selfpkgs.doubletake-git
      ];
      text = builtins.readFile ./doubletake.sh;
    };
  in {
    home-manager.users.luc = {
      programs.plasma.hotkeys.commands = {
        "launch-rofi" = {
          name = "Launch Rofi";
          key = "Alt+R";
          command = "rofi -show combi";
        };

        "launch-rofi-vs" = {
          name = "Launch Rofi VSCode";
          key = "Alt+P";
          command = "rofi -show vs";
        };

        "launch-doubletake" = {
          name = "Launch Doubletake";
          key = "Alt+B";
          command = "rofi -show doubletake";
        };
      };

      programs.rofi = {
        enable = true;
        theme = "Adapta-Nokto";
        modes = [
          "combi"
          "drun"
          "ssh"
          "vs:${rofi-vscode}/bin/rofi-vscode"
          "doubletake:${rofi-doubletake}/bin/rofi-doubletake"
        ];
        extraConfig = {
          show-icons = true;
          show = "combi";
          combi-modes = "drun,ssh,vs";
          combi-hide-mode-prefix = false;
          click-to-exit = true;
          sort = true;
        };
      };
    };
  };
}
