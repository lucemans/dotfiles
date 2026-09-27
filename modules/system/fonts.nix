{
  flake.nixosModules.fonts = {
    lib,
    pkgs,
    ...
  }: let
    # Each generic family resolves to its Latin face first, then the CJK face
    # for the text's language, so Latin letters never come from a CJK font.
    generics = {
      sans-serif = {
        latin = "Noto Sans";
        cjk = "Noto Sans CJK";
      };
      serif = {
        latin = "Noto Serif";
        cjk = "Noto Serif CJK";
      };
      monospace = {
        latin = "Hack Nerd Font Mono";
        cjk = "Noto Sans Mono CJK";
      };
    };

    # Han characters are shared across these languages but drawn differently
    # in each, so a tagged page gets its own region's glyphs. Untagged text,
    # and zh-TW or zh-Hant, gets Traditional Chinese.
    regions = [
      {
        langs = ["zh-cn" "zh-sg" "zh-hans"];
        region = "SC";
      }
      {
        langs = ["zh-hk" "zh-mo"];
        region = "HK";
      }
      {
        langs = ["ja"];
        region = "JP";
      }
      {
        langs = ["ko"];
        region = "KR";
      }
    ];
    fallback = "TC";

    # `prepend` inserts right before the matched generic name, so each rule
    # lands after the ones before it: Latin, then the tagged region, then the
    # fallback. These run ahead of the stock language lists in 65-nonlatin.conf,
    # which would otherwise pick a Korean or Japanese face for Chinese text.
    prepend = generic: family: tests: ''
      <match target="pattern">
        ${tests}<test name="family"><string>${generic}</string></test>
        <edit name="family" mode="prepend" binding="strong"><string>${family}</string></edit>
      </match>
    '';
    lang = l: ''<test name="lang" compare="contains"><string>${l}</string></test>'';
    rules = generic: faces:
      prepend generic faces.latin ""
      + lib.concatMapStrings (r: lib.concatMapStrings (l: prepend generic "${faces.cjk} ${r.region}" (lang l)) r.langs) regions
      + prepend generic "${faces.cjk} ${fallback}" "";
  in {
    fonts.packages = [
      pkgs.nerd-fonts.hack
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji
    ];

    fonts.fontconfig = {
      defaultFonts.emoji = ["Noto Color Emoji"];
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
        ${lib.concatStrings (lib.mapAttrsToList rules generics)}</fontconfig>
      '';
    };
  };
}
