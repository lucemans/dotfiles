{
  flake.homeModules.chromium = {
    pkgs,
    lib,
    ...
  }: {
    xdg.mimeApps.defaultApplications = {
      "text/html" = "chromium-browser.desktop";
      "x-scheme-handler/http" = "chromium-browser.desktop";
      "x-scheme-handler/https" = "chromium-browser.desktop";
    };

    programs.chromium = {
      enable = true;
      package = pkgs.ungoogled-chromium;
      extensions = let
        createChromiumExtensionFor = browserVersion: {
          id,
          hash,
          version,
        }: {
          inherit id;
          crxPath = pkgs.fetchurl {
            url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${browserVersion}&x=id%3D${id}%26installsource%3Dondemand%26uc";
            name = "${id}.crx";
            inherit hash;
          };
          inherit version;
        };
        createChromiumExtension = createChromiumExtensionFor (
          lib.versions.major pkgs.ungoogled-chromium.version
        );
      in [
        (createChromiumExtension {
          # ublock origin
          id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
          hash = "sha256-VJ1fsew67rnYSg2Z8pqUlMtqYKjNA8Lmk6s5vqMyPBw=";
          version = "1.71.0";
        })
        (createChromiumExtension {
          # bitwarden
          id = "nngceckbapebfimnlniiiahkandclblb";
          hash = "sha256-xRK2iX2ntV6N/PQh/KcK10FoNsKV44B+UtyqvFCvelI=";
          version = "2026.5.1";
        })
        (createChromiumExtension {
          # framesh
          id = "ldcoohedfbjoobcadoglnnmmfbdlmmhf";
          hash = "sha256-oUhtmd6MXjOhOwp45c1Jq1j4k0CKgdBdIz/2x6ebzH8=";
          version = "0.12.1";
        })
        (createChromiumExtension {
          # sponsorblock
          id = "mnjggcdmjocbbbhaepdhchncahnbgone";
          hash = "sha256-nE5FE3Eo1jG8sT1KYjVl8JRbmAiyhN8IZObHsAIb0wY=";
          version = "6.1.5";
        })
        (createChromiumExtension {
          # istilldontcareaboutcookies
          id = "edibdbjcniadpccecjdfdjjppcpchdlm";
          hash = "sha256-RrbNwwND3Sl8bTTZF5xeHMHuQEyOY7FU3vFY4TAQw30=";
          version = "1.1.9";
        })
      ];
    };
  };
}
