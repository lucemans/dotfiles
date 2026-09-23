pkgs: let
  inherit (pkgs) lib;

  lines = import ./lines.nix;

  # A clip is addressed by its position in lines.nix, which is also the line
  # rofi reports with -format i, so the menu and the audio cannot drift apart.
  fetch = pkgs.writeText "glados-voicelines.curl" (
    lib.concatStringsSep "\n" (
      lib.imap0 (index: line: ''
        url = "${line.url}"
        output = "${toString index}.wav"
      '')
      lines
    )
  );
in {
  audio =
    pkgs.runCommand "glados-voicelines" {
      nativeBuildInputs = [pkgs.curl];
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = "sha256-4HJNXWBB2/pHtHOGFNhZe63FQ7Ph98Jp/Ravrmv9psk=";
    } ''
      mkdir -p $out
      cd $out
      curl --config ${fetch} \
        --parallel --parallel-max 8 \
        --location --fail --retry 3 --silent --show-error
    '';

  menu = pkgs.writeText "tts-voiceline-menu" (
    lib.concatStringsSep "\n" (map (line: line.text) lines)
  );
}
