{...}: {
  flake.nixosModules.voice = {
    self,
    config,
    pkgs,
    ...
  }: {
    imports = [
      self.nixosModules.peripheral
    ];

    boot.loader.grub.enable = true;
    networking.hostName = "v3x-voice";
    networking.useDHCP = true;
    time.timeZone = "Europe/Amsterdam";

    sops = {
      age.keyFile = "/var/lib/sops-nix/key.txt";
      defaultSopsFile = ../../secrets/voice.sops.yaml;
      secrets = {
        acme_cloudflare_token = {};
        voice_component = {};
        voice_turn = {};
      };
    };

    security.acme = {
      acceptTerms = true;
      certs."voice.channel" = {
        email = "luc@lucemans.nl";
        domain = "*.voice.channel";
        extraDomainNames = ["voice.channel"];
        dnsProvider = "cloudflare";
        extraLegoFlags = ["--dns.propagation-wait=60s"];
        credentialFiles.CF_DNS_API_TOKEN_FILE =
          config.sops.secrets.acme_cloudflare_token.path;
        group = "voice-channel-certs";
        reloadServices = ["prosody.service"];
      };
    };

    users.groups.voice-channel-certs.members = ["prosody" "nginx"];

    services.voice-channel = {
      enable = true;
      domain = "voice.channel";
      admins = ["admin@voice.channel"];
      certificates.useACMEHost = "voice.channel";
      componentSecretFile = config.sops.secrets.voice_component.path;
      turn.secretFile = config.sops.secrets.voice_turn.path;
      openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      sops
      age
      net-tools
    ];

    system.stateVersion = "26.05";
  };
}
