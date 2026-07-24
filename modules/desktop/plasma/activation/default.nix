{inputs, ...}: {
  flake.nixosModules.plasma-activation = {pkgs, ...}: let
    activate-linux = pkgs.rustPlatform.buildRustPackage {
      pname = "activate-linux";
      version = "0.1.0";
      src = inputs.activate-linux;
      cargoHash = "sha256-GrxFI30lRE12O0wSmm6DkgzdtmdffHTLAtfIZcCa26k=";
      buildInputs = [pkgs.libxkbcommon];
      nativeBuildInputs = [pkgs.pkg-config];
      patches = [./activate-linux-output.patch];
    };
    toggle-activate-linux = pkgs.writeShellApplication {
      name = "toggle-activate-linux";
      runtimeInputs = [
        activate-linux
        pkgs.procps
      ];
      text = ''
        if pgrep --exact --uid "$(id -u)" activate-linux >/dev/null; then
          pkill --exact --uid "$(id -u)" activate-linux
        else
          activate-linux --header "Activate Linux" --output DP-4 >/dev/null 2>&1 &
        fi
      '';
    };
  in {
    home-manager.users.luc = {
      xdg.desktopEntries.activate-linux-toggle = {
        name = "Toggle Activate Linux";
        comment = "Toggle the Activate Linux overlay";
        exec = "${toggle-activate-linux}/bin/toggle-activate-linux";
        icon = "preferences-desktop-display";
        terminal = false;
        categories = ["Utility"];
      };

      programs.plasma = {
        hotkeys.commands."toggle-activate-linux" = {
          name = "Toggle Activate Linux";
          key = "Meta+Shift+A";
          command = "${toggle-activate-linux}/bin/toggle-activate-linux";
        };
      };
    };
  };
}
