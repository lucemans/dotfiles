{lib, ...}: let
  gstPlugins = pkgs: [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.gst_all_1.gst-libav
    pkgs.gst_all_1.gst-vaapi
    pkgs.pipewire
  ];

  mkDoubletake = pkgs: {
    pname,
    version,
    rev,
    srcHash,
    vendorHash,
    binSuffix ? "",
  }: let
    gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" (map lib.getLib (gstPlugins pkgs));
    doubletakeBin = "doubletake${binSuffix}";
    doubletakeCtlBin = "doubletake${binSuffix}-ctl";
  in
    pkgs.buildGoModule {
      inherit pname version vendorHash;

      src = pkgs.fetchFromGitHub {
        owner = "omarroth";
        repo = "doubletake";
        inherit rev;
        sha256 = srcHash;
      };

      subPackages = [
        "cmd/doubletake"
        "cmd/doubletake-ctl"
      ];

      nativeBuildInputs = [pkgs.makeWrapper];

      postInstall = ''
        if [ "${binSuffix}" != "" ]; then
          mv $out/bin/doubletake $out/bin/${doubletakeBin}
          mv $out/bin/doubletake-ctl $out/bin/${doubletakeCtlBin}
        fi

        install -Dm444 man/man1/doubletake.1 $out/share/man/man1/${doubletakeBin}.1
        install -Dm444 man/man1/doubletake-ctl.1 $out/share/man/man1/${doubletakeCtlBin}.1

        wrapProgram $out/bin/${doubletakeBin} \
          --prefix PATH : ${lib.makeBinPath [
          pkgs.gst_all_1.gstreamer
          pkgs.xrandr
        ]} \
          --set GST_PLUGIN_SYSTEM_PATH_1_0 ${gstPluginPath}
      '';

      meta = {
        description = "AirPlay screen mirroring sender for Linux";
        homepage = "https://github.com/omarroth/doubletake";
        license = lib.licenses.lgpl3Plus;
        mainProgram = doubletakeBin;
        platforms = ["x86_64-linux"];
      };
    };
in {
  perSystem = {pkgs, ...}: {
    packages.doubletake = mkDoubletake pkgs rec {
      pname = "doubletake";
      version = "0.3.2";
      rev = "v${version}";
      srcHash = "11kv7rfqxn147d941iy1kna48zyxxaxixn9ra2zddpbiwb957l2l";
      vendorHash = "sha256-cgvY9MVGe8I3g3Ni2sGucTY6YCyPJ2YnoxxUaYfl1E4=";
    };

    packages.doubletake-git = mkDoubletake pkgs {
      pname = "doubletake-git";
      version = "0-unstable-2026-07-02";
      rev = "a65f5abc0c20099605d6decbfc74ec9100141e53";
      srcHash = "070bibsmf58nlxc2n4jspidw35cks4rhz4nhyqwz6vwwvmc4cyss";
      vendorHash = "sha256-cgvY9MVGe8I3g3Ni2sGucTY6YCyPJ2YnoxxUaYfl1E4=";
      binSuffix = "-git";
    };
  };

  flake.nixosModules.doubletake = {
    pkgs,
    self,
    ...
  }: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.doubletake
      self.packages.${pkgs.stdenv.hostPlatform.system}.doubletake-git
    ];

    services.pipewire.enable = true;

    environment.variables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPath "lib/gstreamer-1.0" (map lib.getLib (gstPlugins pkgs));
  };
}
