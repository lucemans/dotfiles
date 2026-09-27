{
  flake.nixosModules.gnupg = {pkgs, ...}: {
    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      # An empty value renders as `grab ` with no argument, the bare flag gpg-agent expects.
      settings.grab = "";
    };

    systemd.tmpfiles.rules = [
      "d /home/luc/.gnupg 0700 luc users -"
      "L+ /home/luc/.gnupg/gpg.conf - - - - ${pkgs.writeText "gpg.conf" ''
        cert-digest-algo SHA512
        default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
        display-charset utf-8
        keyid-format 0xlong
        list-options show-uid-validity
        no-comments
        no-emit-version
        no-symkey-cache
        personal-cipher-preferences AES256 AES192 AES
        personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
        personal-digest-preferences SHA512 SHA384 SHA256
        require-cross-certification
        s2k-cipher-algo AES256
        s2k-digest-algo SHA512
        verify-options show-uid-validity
        with-fingerprint
      ''}"
    ];
  };
}
