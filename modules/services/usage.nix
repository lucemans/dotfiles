{inputs, ...}: {
  flake.nixosModules.usage = {config, ...}: {
    imports = [inputs.metered-usage.nixosModules.default];

    sops = {
      secrets.watch_metered_usage_token.mode = "0400";

      templates.watch_metered_usage_env = {
        mode = "0400";
        restartUnits = ["metered-usage.service"];
        content = ''
          METERED_USAGE_TOKEN=${config.sops.placeholder.watch_metered_usage_token}
          CLIPROXY_MANAGEMENT_KEY=${config.sops.placeholder.watch_cliproxy_management_password}
        '';
      };
    };

    services.metered-usage = {
      enable = true;
      host = config.v3x.address;
      port = 3000;
      environmentFile = config.sops.templates.watch_metered_usage_env.path;
      settings.source = [
        {
          key = "watch";
          name = "watch cliproxy";
          kind = "cliproxy";
          base_url = "http://${config.v3x.address}:8317";
          key_env = "CLIPROXY_MANAGEMENT_KEY";
        }
      ];
    };

    systemd.services.metered-usage = {
      after = ["wireguard-wg0.service" "docker-cliproxy.service"];
      wants = ["wireguard-wg0.service" "docker-cliproxy.service"];
    };
  };
}
