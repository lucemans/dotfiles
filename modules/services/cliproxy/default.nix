_: {
  flake.nixosModules.cliproxy = {
    config,
    lib,
    pkgs,
    ...
  }: let
    port = 8317;
    stateDir = "/var/lib/cli-proxy-api";

    cliproxyapi = pkgs.cliproxyapi.overrideAttrs (finalAttrs: _: {
      version = "8.0.31";
      src = pkgs.fetchFromGitHub {
        owner = "router-for-me";
        repo = "CLIProxyAPI";
        tag = "v${finalAttrs.version}";
        hash = "sha256-mI5hxiaJnfykI53DgHy2VDmqJKOYqnMso7Pr/KYhhNM=";
      };
      vendorHash = "sha256-r3yWkdMcM40G9jV7MxW/qNv3E9WrHavFilW24quEf+8=";
      patches = [./meta-terminal-cancel.patch];
    });

    image = pkgs.dockerTools.buildLayeredImage {
      name = "cliproxy";
      tag = cliproxyapi.version;
      config = {
        Cmd = [(lib.getExe cliproxyapi)];
        WorkingDir = "/CLIProxyAPI";
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          "ZONEINFO=${pkgs.tzdata}/share/zoneinfo"
        ];
      };
    };
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

          quota-exceeded:
            switch-project: true

          routing:
            strategy: "round-robin"
            session-affinity: true

          logging-to-file: true
          logs-max-total-size-mb: 1024
          request-log: true

          usage-statistics-enabled: true
          redis-usage-queue-retention-seconds: 3600
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${stateDir}/auths 0700 root root -"
      "d ${stateDir}/logs 0700 root root -"
      "d ${stateDir}/static 0700 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "docker";

      containers.cliproxy = {
        image = "${image.imageName}:${image.imageTag}";
        imageFile = image;

        extraOptions = ["--network=host"];

        environmentFiles = [config.sops.templates.watch_cliproxy_env.path];

        environment = {
          TZ = config.time.timeZone;
          MANAGEMENT_STATIC_PATH = "/data/static";
        };

        volumes = [
          "${config.sops.templates.watch_cliproxy_config.path}:/CLIProxyAPI/config.yaml:ro"
          "${stateDir}/auths:/data/auths"
          "${stateDir}/logs:/CLIProxyAPI/logs"
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
