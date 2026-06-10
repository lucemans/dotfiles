{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.fighterThermal = {
    config,
    pkgs,
    ...
  }: {
    # The in-tree nct6683 driver detects this MSI board as nct6687, but exposes PWM as read-only.
    # The out-of-tree nct6687 driver provides writable fan controls for CoolerControl.
    boot.blacklistedKernelModules = ["nct6683"];
    boot.extraModulePackages = [config.boot.kernelPackages.nct6687d];
    boot.kernelModules = ["nct6687"];
    boot.extraModprobeConfig = ''
      options nct6687 force=1 msi_fan_brute_force=1
    '';

    services.power-profiles-daemon.enable = true;

    environment.systemPackages = with pkgs; [
      lm_sensors
      coolercontrol.coolercontrol-gui
    ];

    home-manager.users.luc.xdg.configFile."autostart/org.coolercontrol.CoolerControl.desktop".source = "${pkgs.coolercontrol.coolercontrol-gui}/share/applications/org.coolercontrol.CoolerControl.desktop";

    systemd.services.coolercontrold = {
      description = "CoolerControl daemon";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service"];
      serviceConfig = {
        ExecStart = "${pkgs.coolercontrol.coolercontrold}/bin/coolercontrold";
        Restart = "always";
        RestartSec = "2s";
      };
    };
  };
}
