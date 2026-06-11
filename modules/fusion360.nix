# https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/src/branch/main
{...}: let
  mkFusion360 = pkgs: let
    installer = pkgs.fetchurl {
      url = "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/setup/autodesk_fusion_installer_x86-64.sh";
      hash = "sha256-QaU4tfm3cQ1SYKi6+WfKyNBmeMFtbp2LrdgHrDJ0suo=";
    };

    runtimePath = pkgs.lib.makeBinPath (with pkgs; [
      bash
      bc
      cabextract
      coreutils
      curl
      desktop-file-utils
      file
      findutils
      gawk
      gettext
      gnugrep
      gnused
      inetutils
      lsb-release
      mesa-demos
      mokutil
      p7zip
      pciutils
      polkit
      sambaFull
      systemd
      unzip
      wget
      wineWow64Packages.stableFull
      winetricks
      xdg-utils
      xrandr
      xset
      zip
    ]);

    libraryPath = pkgs.lib.makeLibraryPath (with pkgs; [
      fontconfig
      freetype
      gnutls
      libglvnd
      libunwind
      libusb1
      libx11
      libxcursor
      libxext
      libxi
      libxrandr
      libxrender
      udev
      vulkan-loader
      zlib
    ]);
  in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "fusion360";
      version = "2.1.4-alpha";

      nativeBuildInputs = [pkgs.makeWrapper];
      dontUnpack = true;

      installPhase = ''
        runHook preInstall

        install -Dm755 ${installer} $out/libexec/autodesk_fusion_installer_x86-64.sh

        makeWrapper $out/libexec/autodesk_fusion_installer_x86-64.sh $out/bin/autodesk-fusion360-installer \
          --prefix PATH : ${runtimePath} \
          --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${libraryPath} \
          --set __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d

        makeWrapper $out/libexec/autodesk_fusion_installer_x86-64.sh $out/bin/fusion360-install \
          --prefix PATH : ${runtimePath} \
          --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${libraryPath} \
          --set __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d \
          --add-flags "--install-fix --default"

        makeWrapper $out/libexec/autodesk_fusion_installer_x86-64.sh $out/bin/fusion360-uninstall \
          --prefix PATH : ${runtimePath} \
          --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${libraryPath} \
          --set __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d \
          --add-flags "--uninstall --default"

        cat > $out/bin/fusion360 <<'EOF'
        #!${pkgs.runtimeShell}
        set -euo pipefail

        export PATH=${runtimePath}:$PATH
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib:${libraryPath}
        export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d

        launcher="$HOME/.autodesk_fusion/bin/autodesk_fusion_launcher.sh"
        if [ -x "$launcher" ]; then
          exec "$launcher" "$@"
        fi

        exec "$(dirname "$0")/fusion360-install" "$@"
        EOF
        chmod 755 $out/bin/fusion360

        runHook postInstall
      '';

      meta = {
        description = "Autodesk Fusion installer and launcher for Linux";
        homepage = "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux";
        license = pkgs.lib.licenses.unfreeRedistributable;
        mainProgram = "fusion360";
        platforms = ["x86_64-linux"];
      };
    };
in {
  perSystem = {pkgs, ...}: {
    packages.fusion360 = mkFusion360 pkgs;
  };

  flake.nixosModules.fusion360 = {pkgs, ...}: {
    environment.systemPackages = [
      (mkFusion360 pkgs)
    ];
  };
}
