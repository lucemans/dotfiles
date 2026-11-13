_: {
  flake.nixosModules.uxplay = {
    lib,
    pkgs,
    ...
  }: {
    # `-p` selects the ports opened below. Bare `-pw` shows a new 4-digit code in
    # this terminal for each connection and checks it before streaming starts.
    # `-pin` only advertises pairing to clients: UxPlay 1.73.6 lets a client that
    # skips it connect anyway.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "uxplay-fighter" ''
        exec ${lib.getExe pkgs.uxplay} -n fighter -nh -pw -p -vs waylandsink -avdec "$@"
      '')
    ];

    # UxPlay registers its service through avahi over D-Bus. avahi refuses with
    # kDNSServiceErr_Unknown while publishing is off.
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [7000 7001 7100];
      allowedUDPPorts = [6000 6001 7011];
    };
  };
}
