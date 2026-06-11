{
  flake.nixosModules.opencode = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      opencode
    ];

    # nixpkgs builds opencode with OPENCODE_CHANNEL=stable, and upstream
    # opencode uses channel-specific DB names by default. AgentsView 0.32.1
    # only discovers the shared opencode.db path, so keep opencode on that
    # stable shared filename until AgentsView supports opencode-*.db natively.
    environment.sessionVariables.OPENCODE_DISABLE_CHANNEL_DB = "1";

    home-manager.users.luc.home.sessionVariables.OPENCODE_DISABLE_CHANNEL_DB = "1";
  };
}
