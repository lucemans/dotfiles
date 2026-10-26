{inputs, ...}: let
  inherit (import ../../network/services.nix) services;
in {
  flake.nixosModules.kettleClient = {pkgs, ...}: let
    inherit (pkgs.stdenv.hostPlatform) system;
    codeUrl = "https://${services.code.name}";
  in {
    users.users.luc.packages = [
      inputs.kettle-code.packages.${system}.k5c-cli
      inputs.kettle-code.packages.${system}.k5c-desktop
      inputs.kettle-forge.packages.${system}.kettle-forge
    ];

    home-manager.users.luc = {
      config,
      lib,
      ...
    }: {
      home.sessionVariables = {
        K5C_URL = codeUrl;
        K5F_URL = "https://${services.forge.name}";
      };
      # The desktop app rewrites this file on every connect, so it cannot be a
      # read-only store link.
      home.activation.kettleDesktopServer = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run install -D -m 0644 ${pkgs.writeText "server" "${codeUrl}\n"} \
          ${lib.escapeShellArg "${config.xdg.configHome}/company.v3x.kettlecode/server"}
      '';
    };
  };
}
