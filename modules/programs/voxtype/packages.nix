{
  pkgs,
  voxtype,
}: let
  upstream = voxtype.packages.${pkgs.system};
  upstreamPkgs = import voxtype.inputs.nixpkgs {system = pkgs.stdenv.hostPlatform.system;};
  # Give the patch its own store path so unrelated dotfiles edits do not
  # invalidate the patched UI.
  patch = builtins.path {
    path = ./live-preview.patch;
    name = "voxtype-live-preview.patch";
  };
  patched = package:
    package.overrideAttrs (old: {
      patches = (old.patches or []) ++ [patch];
      # Recognition runs in the speech server. Avoid upstream's expensive
      # single-unit fat LTO when rebuilding the control daemon and GTK overlay.
      env =
        (old.env or {})
        // {
          CARGO_PROFILE_RELEASE_LTO = "thin";
          CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
        };
    });
  vocab = pkgs.writeShellApplication {
    name = "voxtype-vocab";
    runtimeInputs = with pkgs; [coreutils gawk];
    text = builtins.readFile ./vocab.sh;
  };
in {
  # Patch the unwrapped derivation, preserving upstream's typing-tool wrapper.
  daemon = upstream.default.overrideAttrs (_: {
    paths = [(patched upstream.voxtype-unwrapped)];
  });
  osd = (patched upstream.osd-gtk4).overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ (with upstreamPkgs; [gtk4 cairo pango gdk-pixbuf graphene glib]);
  });

  inherit vocab;

  vocabTests = pkgs.runCommand "voxtype-vocab-tests" {nativeBuildInputs = [vocab pkgs.diffutils];} ''
    export HOME=$TMPDIR VOXTYPE_VOCABULARY=$TMPDIR/vocabulary.txt

    # A later fix for the same words replaces the earlier one, whatever its case.
    voxtype-vocab add Nextcloud kubectl
    voxtype-vocab fix "next cloud" Nextcloud
    voxtype-vocab fix "Next Cloud" Nextcloud
    voxtype-vocab add kubectl
    voxtype-vocab remove KUBECTL
    voxtype-vocab fix "vox type" Voxtype
    printf '%s\n' 'Nextcloud' 'Next Cloud => Nextcloud' 'vox type => Voxtype' > expected
    diff expected "$VOXTYPE_VOCABULARY"

    # An entry the one-line format cannot hold is refused, not written.
    if voxtype-vocab add 'a => b' 2>/dev/null; then echo 'accepted an entry containing =>' >&2; exit 1; fi
    diff expected "$VOXTYPE_VOCABULARY"
    touch $out
  '';
}
