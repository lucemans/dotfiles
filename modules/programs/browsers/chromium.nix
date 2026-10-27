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
        {
          # ublock origin
          id = "fkgkibajhfbepljeaefdnfnegdcjomkh";
          crxPath = pkgs.fetchurl {
            url = "https://github.com/gorhill/uBlock/releases/download/1.75.0/uBlock0_1.75.0.chromium.crx";
            hash = "sha256-1ojtPwJi7E+L3NTI9lmHxURMVgrrOHqeAqyh+s36cEY=";
          };
          version = "1.75.0";
        }
        (createChromiumExtension {
          # bitwarden
          id = "nngceckbapebfimnlniiiahkandclblb";
          hash = "sha256-8v63/EbSVQvvm2mvHMNYrqJrkKlHZF+d4W7BTZKW72k=";
          version = "2026.10.0";
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
          hash = "sha256-VYf+K2qZRhAcoN3nxu/nanVcXuW21uY9/EjH9zbNtP8=";
          version = "6.1.6";
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
