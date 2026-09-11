_: {
  flake.nixosModules.cliproxy = {config, ...}: let
    port = 8317;
    stateDir = "/var/lib/cli-proxy-api";
  in {
    sops = {
      secrets = {
        watch_cliproxy_api_key.mode = "0400";
        watch_cliproxy_management_password.mode = "0400";
      };

      templates.watch_cliproxy_env = {
        mode = "0400";
        content = ''
          MANAGEMENT_PASSWORD=${config.sops.placeholder.watch_cliproxy_management_password}
        '';
      };

      templates.watch_cliproxy_config = {
        mode = "0400";
        restartUnits = ["docker-cliproxy.service"];
        content = ''
          host: "${config.v3x.address}"
          port: ${toString port}

          auth-dir: "/data/auths"

          api-keys:
            - "${config.sops.placeholder.watch_cliproxy_api_key}"

          remote-management:
            allow-remote: true
            secret-key: ""
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${stateDir}/auths 0700 root root -"
      "d ${stateDir}/static 0700 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "docker";

      containers.cliproxy = {
        image = "eceasy/cli-proxy-api:v7.2.157";

        extraOptions = ["--network=host"];

        environmentFiles = [config.sops.templates.watch_cliproxy_env.path];

        environment = {
          TZ = config.time.timeZone;
          MANAGEMENT_STATIC_PATH = "/data/static";
        };

        volumes = [
          "${config.sops.templates.watch_cliproxy_config.path}:/CLIProxyAPI/config.yaml:ro"
          "${stateDir}/auths:/data/auths"
          "${stateDir}/static:/data/static"
        ];
      };
    };

    systemd.services.docker-cliproxy = {
      after = ["wireguard-wg0.service"];
      wants = ["wireguard-wg0.service"];
    };
  };
}
