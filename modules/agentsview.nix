{lib, ...}: {
  perSystem = {pkgs, ...}: let
    version = "0.33.0";

    cliSrc = pkgs.fetchurl {
      url = "https://github.com/kenn-io/agentsview/releases/download/v${version}/agentsview_${version}_linux_amd64.tar.gz";
      sha256 = "4f1b243f3f784fa9b59ff55d89ba5936989acec00e6e5780206e8ac4d7190053";
    };

    desktopSrc = pkgs.fetchurl {
      url = "https://github.com/kenn-io/agentsview/releases/download/v${version}/AgentsView_${version}_amd64.AppImage";
      sha256 = "ce2145e1f4a46a719350182fef9d5cbf1239cf3cdb0fabd2f071fe9be0caef00";
    };

    desktopPname = "agentsview-desktop";

    desktopItem = pkgs.makeDesktopItem {
      name = desktopPname;
      desktopName = "AgentsView";
      genericName = "Coding Agent Analytics";
      comment = "Local-first session intelligence and analytics for coding agents";
      exec = "${desktopPname} %U";
      icon = "agentsview";
      categories = ["Development" "Utility"];
      startupWMClass = "AgentsView";
    };

    appimageContents = pkgs.appimageTools.extractType2 {
      pname = desktopPname;
      inherit version;
      src = desktopSrc;
    };
  in {
    packages.agentsview = pkgs.stdenv.mkDerivation {
      pname = "agentsview";
      inherit version;
      src = cliSrc;

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];

      buildInputs = [
        pkgs.stdenv.cc.cc.lib
      ];

      dontBuild = true;
      sourceRoot = ".";

      installPhase = ''
        runHook preInstall

        binary="$(find . -type f -name agentsview -print -quit)"
        if [ -z "$binary" ]; then
          echo "agentsview binary not found in release archive" >&2
          exit 1
        fi

        install -Dm755 "$binary" "$out/bin/agentsview"

        runHook postInstall
      '';

      meta = {
        description = "Local-first session intelligence and analytics for coding agents";
        homepage = "https://www.agentsview.io/";
        license = lib.licenses.mit;
        mainProgram = "agentsview";
        platforms = ["x86_64-linux"];
      };
    };

    packages.agentsview-desktop = pkgs.appimageTools.wrapType2 {
      pname = desktopPname;
      inherit version;
      src = desktopSrc;

      extraInstallCommands = ''
        install -Dm444 ${desktopItem}/share/applications/${desktopPname}.desktop \
          $out/share/applications/${desktopPname}.desktop

        if [ -d ${appimageContents}/usr/share/icons ]; then
          mkdir -p $out/share
          cp -r --no-preserve=mode,ownership ${appimageContents}/usr/share/icons $out/share/
        fi

        icon="$(find ${appimageContents} -type f \
          \( -iname 'agentsview.png' -o -iname 'agentsview.svg' -o -iname 'icon.png' -o -iname 'icon.svg' \) \
          -print -quit)"
        if [ -n "$icon" ]; then
          case "$icon" in
            *.svg) install -Dm444 "$icon" $out/share/icons/hicolor/scalable/apps/agentsview.svg ;;
            *) install -Dm444 "$icon" $out/share/icons/hicolor/512x512/apps/agentsview.png ;;
          esac
        fi
      '';

      meta = {
        description = "Desktop app for AgentsView";
        homepage = "https://www.agentsview.io/";
        license = lib.licenses.mit;
        mainProgram = "agentsview-desktop";
        platforms = ["x86_64-linux"];
      };
    };
  };
}
