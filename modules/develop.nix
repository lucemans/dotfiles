{...}: {
  flake.nixosModules.develop = {pkgs, ...}: {
    systemd.tmpfiles.rules = [
      "d /home/luc/dev 0755 luc users -"
      "d /home/luc/dev/local 0755 luc users -"
      "d /home/luc/dev/archive 0755 luc users -"
      "d /home/luc/dev/demo 0755 luc users -"
    ];

    system.activationScripts.developDirectory = ''
      ${pkgs.coreutils}/bin/mkdir -p /home/luc/dev
      ${pkgs.coreutils}/bin/cat > /home/luc/dev/.directory <<'EOF'
      [Desktop Entry]
      Type=Directory
      Icon=folder-development
      EOF
      ${pkgs.coreutils}/bin/chown luc:users /home/luc/dev/.directory
      ${pkgs.coreutils}/bin/chmod 0644 /home/luc/dev/.directory
    '';

    environment.systemPackages = with pkgs; [
      android-tools
    ];
  };
}
