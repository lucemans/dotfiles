{
  config,
  lib,
  pkgs,
  ethereum-nix,
  ...
}: {
  flake.nixosModules.teapot = {
    self,
    config,
    inputs,
    pkgs,
    lib,
    ...
  }: let
    prisma = inputs.prisma-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.prisma;
  in {
    imports = [
      self.nixosModules.peripheral
      self.nixosModules.teapotLlm
      self.nixosModules.teapotHermes
    ];

    nixpkgs.overlays = [
      (final: prev: {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pythonPackages: super: {
              langfuse = super.langfuse.overridePythonAttrs (old: {
                pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["wrapt"];
              });
              litellm = let
                prismaPython = super.prisma.overridePythonAttrs (old: {
                  postPatch =
                    (old.postPatch or "")
                    + ''
                      substituteInPlace src/prisma/_config.py \
                        --replace-fail "default='5.17.0'" "default='5.18.0'" \
                        --replace-fail "default='393aa359c9ad4a4bb28630fb5613f9c281cde053'" "default='4c784e32044a8a016d99474bd02a3b6123742169'"
                    '';
                  postInstall =
                    (old.postInstall or "")
                    + ''
                      schema="$TMPDIR/litellm-schema.prisma"
                      substitute ${super.litellm.src}/schema.prisma "$schema" \
                        --replace-fail '  provider = "prisma-client-py"' "  provider = \"prisma-client-py\"
                        output = \"$out/${pythonPackages.python.sitePackages}/prisma\""

                      export PYTHONPATH="$out/${pythonPackages.python.sitePackages}:$PYTHONPATH"
                        PATH="$out/bin:$PATH" ${lib.getExe' prisma "prisma"} generate --schema="$schema"
                    '';
                  pythonImportsCheck = (old.pythonImportsCheck or []) ++ ["prisma.client"];
                });
              in
                (super.litellm.override {prisma = prismaPython;}).overridePythonAttrs (old: {
                  makeWrapperArgs =
                    (old.makeWrapperArgs or [])
                    ++ [
                      "--prefix PATH : ${lib.makeBinPath [prisma]}"
                    ];
                });
            })
          ];
      })
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "v3x-teapot";
    networking.networkmanager.enable = true;
    time.timeZone = "Europe/Amsterdam";
    virtualisation.docker.enable = true;

    sops = {
      age.keyFile = "/home/luc/.config/sops/age/keys.txt";
      defaultSopsFile = ../../secrets/418.sops.yaml;
      secrets = {
        # ssh-public-key = {
        #   path = "/home/luc/.ssh/id_ed25519.pub";
        #   mode = "0644";
        # };
        # ssh-private-key = {
        #   path = "/home/luc/.ssh/id_ed25519";
        #   mode = "0600";
        # };
        teapot_github_pat = {};
      };
      templates = {
        cargo-credentials = {
          content = ''
            [hello]
            test = "${config.sops.placeholder.teapot_github_pat}"
          '';
          path = "/home/luc/testing.toml";
          mode = "0600";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
    ];
    networking.firewall.allowedUDPPorts = [
    ];

    environment.systemPackages = with pkgs; [
      sops
      age
    ];

    system.stateVersion = "26.05";
  };
}
