{...}: {
  perSystem = {pkgs, ...}: {
    # framesh on wayland struggles with registering keybindings, this patches that by unsetting the ozone wayland environment variable
    packages.frame-sh-wayland =
      pkgs.runCommand "frame-sh-wayland" {
        nativeBuildInputs = [pkgs.makeWrapper];
        meta = pkgs.framesh.meta;
      } ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.framesh}/bin/framesh $out/bin/framesh \
          --unset NIXOS_OZONE_WL
        ln -s ${pkgs.framesh}/share $out/share
      '';
  };
}
