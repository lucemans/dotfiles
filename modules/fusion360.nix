# Direct Autodesk Fusion package for Wine on NixOS.
{...}: let
  mkFusion360 = pkgs: let
    inherit (pkgs) lib;

    version = "2702.1.58";

    fusionInstaller = pkgs.fetchurl {
      url = "https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe";
      hash = "sha256-AOOODF/D4946Zu/DYwBz1H8zq/59IwmhR1bMIaN8Rfo=";
    };

    patchedQt6WebEngineCore = pkgs.fetchurl {
      url = "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/extras/patched-dlls/Qt6WebEngineCore-06-2025.7z";
      hash = "sha256-UiKi7VN9sJlDXX2w6Vrxa0YAnK85ZdIqwPpdwcWfGU0=";
    };

    patchedSiappdll = pkgs.fetchurl {
      url = "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/extras/patched-dlls/siappdll.dll";
      hash = "sha256-quhtZGFD9Rmhnk8yheWbCxr+I8BdBYD3aX4ekRUhwPM=";
    };

    fusionWineBuild = pkgs.fetchurl {
      url = "https://github.com/Lolig4/Autodesk-Fusion-360-for-Linux/releases/download/Pre_Build_Wine%2FProton/fusion-wine-build.tar.gz";
      hash = "sha256-p37KVqe2Ny1TX4bbiJGcGnOcLAt0bOYGD9qE/JJ14UA=";
    };

    icon = pkgs.fetchurl {
      url = "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/setup/resource/graphics/autodesk_fusion.svg";
      hash = "sha256-YSz+4mWksZbut/gv4dt7d6MjsKhqNgWU2rbO2KmixOw=";
    };

    webview2Installer = pkgs.fetchurl {
      url = "https://github.com/aedancullen/webview2-evergreen-standalone-installer-archive/releases/download/109.0.1518.78/MicrosoftEdgeWebView2RuntimeInstallerX64.exe";
      hash = "sha256-8sxJhj4iFALUZk2fqUSkfyJUPaLcs2NDjD5Zh4m5/Vs=";
    };

    runtimePath = lib.makeBinPath (with pkgs; [
      coreutils
      curl
      findutils
      gnugrep
      gnused
      xdg-utils
    ]);

    winetricksPath = lib.makeBinPath (with pkgs; [
      cabextract
      winetricks
    ]);

    libraryPath = lib.makeLibraryPath (with pkgs; [
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

    machineOptions = pkgs.runCommand "NMachineSpecificOptions.xml" {} ''
      cat > $out <<'XMLEOF'
      <?xml version="1.0" encoding="UTF-16" standalone="no" ?>
      <OptionGroups>
        <BootstrapOptionsGroup SchemaVersion="2" ToolTip="Special preferences that require the application to be restarted after a change." UserName="Bootstrap">
          <driverOptionId ToolTip="The driver used to display the graphics" UserName="Graphics driver" Value="VirtualDeviceGLCore"/>
          <WeaveTheme ToolTip="Changes the active theme used by Fusion UI." UserName="Theme" Value="weave-dark-blue"/>
        </BootstrapOptionsGroup>
        <spacemouseDriverOptionId ToolTip="Changes the version of the SpaceMouse SDK used by Fusion. For unsupported devices, use the Older setting." UserName="SpaceMouse-Driver" Value="0"/>
        <NetworkOptionGroup SchemaVersion="2" ToolTip="This is a set of options used for network access." UserName="Network">
          <WindowsProxyOptionId ToolTip="Windows Network Proxy - Setting" UserName="Windows-Network-Proxy - Setting" Value="No Proxy"/>
          <SSLVerifyPeerOptionId ToolTip="Ensure that the Autodesk Fusion 360 client can validate the server SSL certificate." UserName="Server-Verification" Value="TrustAllServers"/>
        </NetworkOptionGroup>
      </OptionGroups>
      XMLEOF
      # Convert from UTF-8 to UTF-16LE with BOM
      ${pkgs.glibc.bin}/bin/iconv -f UTF-8 -t UTF-16LE $out > $out.tmp
      printf '\xff\xfe' > $out
      cat $out.tmp >> $out
      rm $out.tmp
    '';
  in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "fusion360";
      inherit version;

      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        p7zip
        xz
        cabextract
        patchelf
        winetricks
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p extracted payload patched $out/share/fusion360 $out/share/applications $out/opt $out/bin

        7z x -y -oextracted ${fusionInstaller} '_payload/packages/*.tar.xz'
        for archive in extracted/_payload/packages/*.tar.xz; do
          tar -xJf "$archive" -C payload
        done

        7z x -y -opatched ${patchedQt6WebEngineCore}
        qt_dir="$(dirname "$(find payload -name Qt6WebEngineCore.dll -print -quit)")"
        if [ -z "$qt_dir" ] || [ ! -d "$qt_dir" ]; then
          echo "Qt6WebEngineCore.dll not found in Fusion payload" >&2
          exit 1
        fi
        cp patched/Qt6WebEngineCore.dll "$qt_dir/Qt6WebEngineCore.dll"
        cp ${patchedSiappdll} "$qt_dir/siappdll.dll"

        cp -r payload/. $out/share/fusion360/
        cp ${fusionInstaller} $out/share/fusion360/FusionAdminInstall.exe
        tar -xzf ${fusionWineBuild} -C $out/opt

        install -Dm444 ${icon} $out/share/icons/hicolor/scalable/apps/autodesk_fusion.svg
        install -Dm444 ${machineOptions} $out/share/fusion360/NMachineSpecificOptions.xml
        install -Dm644 ${webview2Installer} $out/share/fusion360/MicrosoftEdgeWebView2RuntimeInstallerX64.exe
        # Bundle patched DLLs and the extracted Qt archive for runtime patching
        cp ${patchedQt6WebEngineCore} $out/share/fusion360/Qt6WebEngineCore-06-2025.7z
        install -Dm644 ${patchedSiappdll} $out/share/fusion360/siappdll.dll

        cp ${pkgs.winetricks}/bin/winetricks $out/bin/winetricks
        chmod 755 $out/bin/winetricks

        cat > $out/share/applications/fusion360.desktop <<EOF
        [Desktop Entry]
        Type=Application
        Name=Autodesk Fusion
        GenericName=CAD Application
        Comment=Autodesk Fusion through Wine
        Exec=$out/bin/fusion360 %U
        Icon=autodesk_fusion
        Categories=Education;Engineering;Graphics;Science;
        StartupNotify=true
        StartupWMClass=fusion360.exe
        EOF

        cat > $out/share/applications/fusion360-adskidmgr-opener.desktop <<EOF
        [Desktop Entry]
        Type=Application
        Name=Autodesk Fusion Identity Manager Scheme Handler
        Exec=$out/bin/fusion360-adskidmgr-opener %u
        MimeType=x-scheme-handler/adskidmgr;
        NoDisplay=true
        EOF

        cat > $out/bin/fusion360 <<EOF
        #!${pkgs.runtimeShell}
        set -euo pipefail

        export PATH=${runtimePath}:\$PATH
        wine_lib=$out/opt/fusion-wine-build/lib
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib:\$wine_lib/wine/x86_64-unix:\$wine_lib:${libraryPath}\''${LD_LIBRARY_PATH:+:}\''${LD_LIBRARY_PATH:-}
        export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d

        export WINE=$out/opt/fusion-wine-build/bin/wine
        export WINESERVER=$out/opt/fusion-wine-build/bin/wineserver
        export WINEDEBUG=\''${WINEDEBUG:--all}
        export WINEPREFIX=\''${FUSION360_WINEPREFIX:-\''${XDG_DATA_HOME:-\$HOME/.local/share}/fusion360/wineprefix}
        export WINETRICKS=$out/bin/winetricks
        export DISABLE_GPU_SANDBOX=1
        export CEF_DISABLE_GPU=1
        export PROTON_USE_WINED3D=1
        export WINEDLLOVERRIDES="adpclientservice.exe=native;msvcp140=native;mfc140u=native;bcp47langs=;*d3d10core=native;*d3d11=native;*d3d9=builtin;*dxgi=native"

        fusion_payload=$out/share/fusion360
        setup_marker=\$WINEPREFIX/.fusion360-nix-setup-v8
        setup_log="\$WINEPREFIX/fusion360-setup.log"

        if [ ! -e "\$WINEPREFIX/system.reg" ]; then
          mkdir -p "\$WINEPREFIX"
          "\$WINE" wineboot --init
          "\$WINESERVER" -w
        fi

        # Link host Downloads into Wine prefix (cryinkfly compatibility)
        mkdir -p "\$WINEPREFIX/drive_c/users/\$USER"
        rm -rf "\$WINEPREFIX/drive_c/users/\$USER/Downloads"
        ln -sf "\$HOME/Downloads" "\$WINEPREFIX/drive_c/users/\$USER/Downloads"

        if [ ! -e "\$setup_marker" ]; then
          rm -f "\$setup_marker"
          export PATH=${runtimePath}:${winetricksPath}:\$PATH

          "\$WINE" REG ADD 'HKCU\Software\Wine' /v Version /t REG_SZ /d win11 /f >> "\$setup_log" 2>&1

          printf '%s\n' 'Installing corefonts...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q corefonts >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing gdiplus...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q gdiplus >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing atmlib...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q atmlib >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing fontsmooth=rgb...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q fontsmooth=rgb >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing vcrun2022...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q vcrun2022 >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing msxml4 msxml6...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q msxml4 msxml6 >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing winhttp...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q winhttp >> "\$setup_log" 2>&1 || true
          printf '%s\n' 'Installing 7zip...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q 7zip >> "\$setup_log" 2>&1 || true

          "\$WINE" REG ADD 'HKCU\Software\Wine' /v Version /t REG_SZ /d win11 /f >> "\$setup_log" 2>&1
          "\$WINETRICKS" -q win11 >> "\$setup_log" 2>&1 || true

          printf '%s\n' 'Installing DXVK...' | tee -a "\$setup_log"
          "\$WINETRICKS" -q dxvk >> "\$setup_log" 2>&1 || true

          printf '%s\n' 'Installing Microsoft Edge WebView2 Runtime...' | tee -a "\$setup_log"
          cp "\$fusion_payload/MicrosoftEdgeWebView2RuntimeInstallerX64.exe" "\$WINEPREFIX/dosdevices/c:/windows/temp/WebView2Setup.exe"
          "\$WINE" "C:/windows/temp/WebView2Setup.exe" /silent /install >> "\$setup_log" 2>&1
          echo "WebView2 exit: \$?" >> "\$setup_log"

          # Run Fusion Admin Install.exe as Windows installer (like cryinkfly does)
          printf '%s\n' 'Running Fusion installer...' | tee -a "\$setup_log"
          cp "\$fusion_payload/FusionAdminInstall.exe" "\$WINEPREFIX/dosdevices/c:/windows/temp/FusionInstaller.exe"
          echo "Installer run 1 of 2..." >> "\$setup_log"
          timeout -k 10m 9m "\$WINE" "C:/windows/temp/FusionInstaller.exe" --quiet >> "\$setup_log" 2>&1
          echo "Installer run 1 exit: \$?" >> "\$setup_log"
          echo "Installer run 2 of 2..." >> "\$setup_log"
          timeout -k 5m 1m "\$WINE" "C:/windows/temp/FusionInstaller.exe" --quiet >> "\$setup_log" 2>&1
          echo "Installer run 2 exit: \$?" >> "\$setup_log"

          # Set DLL overrides and registry keys
          "\$WINE" REG ADD 'HKCU\Software\Wine\DllOverrides' /v adpclientservice.exe /t REG_SZ /d native /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Wine\DllOverrides' /v msvcp140 /t REG_SZ /d native /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Wine\DllOverrides' /v mfc140u /t REG_SZ /d native /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Wine\DllOverrides' /v bcp47langs /t REG_SZ /d "" /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Wine\X11 Driver' /v Managed /t REG_SZ /d Y /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d Y /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Classes\http\shell\open\command' /ve /t REG_SZ /d "/usr/bin/xdg-open %1" /f >> "\$setup_log" 2>&1
          "\$WINE" REG ADD 'HKCU\Software\Classes\https\shell\open\command' /ve /t REG_SZ /d "/usr/bin/xdg-open %1" /f >> "\$setup_log" 2>&1

          # Install 7-zip then extract patched Qt6WebEngineCore
          printf '%s\n' 'Patching Qt6WebEngineCore...' | tee -a "\$setup_log"
          cp "\$fusion_payload/Qt6WebEngineCore-06-2025.7z" "\$WINEPREFIX/dosdevices/c:/windows/temp/Qt6WebEngineCore-06-2025.7z"
          "\$WINE" "C:/Program Files/7-Zip/7z.exe" x "C:/windows/temp/Qt6WebEngineCore-06-2025.7z" -o"C:/windows/temp/" -y >> "\$setup_log" 2>&1 || true
          echo "7z exit: \$?" >> "\$setup_log"

          touch "\$setup_marker"
        fi

        # Apply runtime patches
        # Find Fusion360.exe from the installer
        fusion_exe=\$(find "\$WINEPREFIX" -name Fusion360.exe -printf "%T+ %p\n" 2>/dev/null | sort -r | head -n 1 | cut -d' ' -f2-)
        if [ -z "\$fusion_exe" ]; then
          echo "ERROR: Fusion360.exe not found in \$WINEPREFIX" >&2
          exit 1
        fi
        fusion_install=\$(dirname "\$fusion_exe")
        echo "Found Fusion at: \$fusion_install" >> "\$setup_log"

        fusion_install_win=\$(echo "\$fusion_install" | sed "s|\$WINEPREFIX/drive_c/|C:/|" | sed 's|/|\\\\|g')

        # Patch Qt6WebEngineCore and siappdll in the installed Fusion
        qt_dir=\$(find "\$fusion_install" -name Qt6WebEngineCore.dll -printf "%h\n" 2>/dev/null | head -1)
        if [ -n "\$qt_dir" ]; then
          cp -f "\$WINEPREFIX/dosdevices/c:/windows/temp/Qt6WebEngineCore.dll" "\$qt_dir/Qt6WebEngineCore.dll" 2>/dev/null || true
          cp -f "\$fusion_payload/siappdll.dll" "\$qt_dir/siappdll.dll" 2>/dev/null || true
        fi

        # Disable ADEXMTSV
        echo '@echo off' > "\$fusion_install/adexmtsv.exe" 2>/dev/null || true
        echo 'exit /b 0' >> "\$fusion_install/adexmtsv.exe" 2>/dev/null || true

        # DeviceSettingsProvider fix
        find "\$fusion_install" -path "*/ADPCER/DeviceSettingsProvider.dll" 2>/dev/null | while read -r dll_path; do
          expected="\$(dirname "\$(dirname "\$dll_path")")/DeviceSettingsProvider.dll"
          if [ ! -f "\$expected" ]; then
            ln -sf "\$dll_path" "\$expected"
          fi
        done

        # Copy NMachineSpecificOptions.xml
        for dir in \
          "\$WINEPREFIX/drive_c/users/\$USER/AppData/Roaming/Autodesk/Neutron Platform/Options" \
          "\$WINEPREFIX/drive_c/users/\$USER/AppData/Local/Autodesk/Neutron Platform/Options" \
          "\$WINEPREFIX/drive_c/users/\$USER/Application Data/Autodesk/Neutron Platform/Options"; do
          mkdir -p "\$dir"
          rm -f "\$dir/NMachineSpecificOptions.xml"
          install -m 0644 "$out/share/fusion360/NMachineSpecificOptions.xml" "\$dir/NMachineSpecificOptions.xml"
        done

        # Remove SafeMode files
        rm -f \
          "\$WINEPREFIX/drive_c/users/\$USER/AppData/Roaming/Autodesk/Autodesk Fusion 360/SafeModeSession" \
          "\$WINEPREFIX/drive_c/users/\$USER/AppData/Roaming/Autodesk/Autodesk Fusion 360/SafeModeCounter.json"

        # Set environment PATH inside Wine
        "\$WINE" REG ADD 'HKCU\Environment' /v PATH /t REG_EXPAND_SZ /d "\$fusion_install_win;%PATH%" /f >/dev/null 2>&1 || true

        "\$WINE" "\$fusion_exe" "\$@" &
        fusion_pid=\$!
        wait "\$fusion_pid"
        status=\$?
        "\$WINESERVER" -w 2>/dev/null || true
        exit "\$status"
        EOF
        chmod 755 $out/bin/fusion360

        cat > $out/bin/fusion360-uninstall <<EOF
        #!${pkgs.runtimeShell}
        set -euo pipefail
        rm -rf "\''${FUSION360_WINEPREFIX:-\''${XDG_DATA_HOME:-\$HOME/.local/share}/fusion360/wineprefix}"
        EOF
        chmod 755 $out/bin/fusion360-uninstall

        cat > $out/bin/fusion360-adskidmgr-opener <<EOF
        #!${pkgs.runtimeShell}
        set -euo pipefail

        export PATH=${runtimePath}:\$PATH
        opener_wine_lib=$out/opt/fusion-wine-build/lib
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib:\$opener_wine_lib/wine/x86_64-unix:\$opener_wine_lib:${libraryPath}\''${LD_LIBRARY_PATH:+:}\''${LD_LIBRARY_PATH:-}
        export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
        export WINEPREFIX=\''${FUSION360_WINEPREFIX:-\''${XDG_DATA_HOME:-\$HOME/.local/share}/fusion360/wineprefix}

        identity_manager="\$(find "\$WINEPREFIX" -name AdskIdentityManager.exe -print -quit)"
        if [ -z "\$identity_manager" ]; then
          echo "AdskIdentityManager.exe was not found in \$WINEPREFIX" >&2
          exit 1
        fi

        exec $out/opt/fusion-wine-build/bin/wine "\$identity_manager" "\$@"
        EOF
        chmod 755 $out/bin/fusion360-adskidmgr-opener

        runHook postInstall
      '';

      postFixup = ''
        # Set interpreter of main Wine binaries only (not x86_64-unix/wine which
        # is loaded by the statically-linked wine-preloader). The LD_LIBRARY_PATH
        # in the wrapper ensures all needed system libraries are found at runtime.
        wine_ld=${pkgs.glibc.out}/lib/ld-linux-x86-64.so.2
        echo "Patching Wine ELF interpreter for NixOS..."
        for f in "$out"/opt/fusion-wine-build/bin/*; do
          [ -f "$f" ] || continue
          patchelf --print-interpreter "$f" >/dev/null 2>&1 || continue
          patchelf --set-interpreter "$wine_ld" "$f"
        done
        echo "Done patching ELF binaries."
      '';

      meta = {
        description = "Autodesk Fusion packaged for Wine on NixOS";
        homepage = "https://www.autodesk.com/products/fusion-360";
        license = lib.licenses.unfreeRedistributable;
        mainProgram = "fusion360";
        platforms = ["x86_64-linux"];
      };
    };
in {
  perSystem = {pkgs, ...}: {
    packages.fusion360 = mkFusion360 pkgs;
  };

  flake.nixosModules.fusion360 = {pkgs, ...}: {
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;

    environment.systemPackages = [
      (mkFusion360 pkgs)
    ];

    xdg.mime.defaultApplications."x-scheme-handler/adskidmgr" = "fusion360-adskidmgr-opener.desktop";
  };
}
