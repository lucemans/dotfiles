{...}: {
  flake.nixosModules.develop = {pkgs, ...}: {
    systemd.tmpfiles.rules = [
      "d /develop 0755 root root -"
      "d /develop/local 0755 luc users -"
      "d /develop/config 0755 luc users -"
      "d /develop/demo 0755 luc users -"
    ];

    system.activationScripts.developDirectory = ''
      ${pkgs.coreutils}/bin/mkdir -p /develop
      ${pkgs.coreutils}/bin/cat > /develop/.directory <<'EOF'
      [Desktop Entry]
      Type=Directory
      Icon=folder-development
      EOF
      ${pkgs.coreutils}/bin/chown luc:users /develop/.directory
      ${pkgs.coreutils}/bin/chmod 0644 /develop/.directory
    '';
  };
}
