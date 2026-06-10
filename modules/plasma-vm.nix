{...}: {
  flake.nixosModules.plasmaVm = {lib, ...}: {
    services.displayManager.autoLogin = {
      enable = true;
      user = "luc";
    };

    services.xserver.videoDrivers = lib.mkForce ["qxl"];
  };
}
