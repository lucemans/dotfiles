{
  flake.nixosModules.cursor = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      code-cursor
    ];

    home-manager.users.luc.home.file.".config/Cursor/User/settings.json".source = ./settings.json;
    home-manager.users.luc.home.file.".config/Cursor/User/keybindings.json".source = ./keybindings.json;
  };
}
