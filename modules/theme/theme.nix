# Wallpaper, launcher icon, and base16 palette (kitty and future apps).
let
  themeName = "dracula";

  themes = {
    catppuccinMocha = {
      base00 = "#1e1e2e";
      base01 = "#181825";
      base02 = "#313244";
      base03 = "#45475a";
      base04 = "#6c7086";
      base05 = "#cdd6f4";
      base06 = "#f5e0dc";
      base07 = "#b4befe";
      base08 = "#f38ba8";
      base0A = "#f9e2af";
      base0B = "#a6e3a1";
      base0C = "#94e2d5";
      base0D = "#89b4fa";
      base0E = "#cba6f7";
      base0F = "#f2cdcd";
    };

    gruvboxDarkHard = {
      base00 = "#1d2021";
      base01 = "#3c3836";
      base02 = "#504945";
      base03 = "#665c54";
      base04 = "#bdae93";
      base05 = "#d5c4a1";
      base06 = "#ebdbb2";
      base07 = "#fbf1c7";
      base08 = "#fb4934";
      base0A = "#fabd2f";
      base0B = "#b8bb26";
      base0C = "#8ec07c";
      base0D = "#83a598";
      base0E = "#d3869b";
      base0F = "#d65d0e";
    };

    tokyoNight = {
      base00 = "#1a1b26";
      base01 = "#16161e";
      base02 = "#2f3549";
      base03 = "#444b6a";
      base04 = "#787c99";
      base05 = "#a9b1d6";
      base06 = "#cbccd1";
      base07 = "#d5d6db";
      base08 = "#c0caf5";
      base0A = "#e0af68";
      base0B = "#9ece6a";
      base0C = "#1abc9c";
      base0D = "#7aa2f7";
      base0E = "#bb9af7";
      base0F = "#f7768e";
    };

    nord = {
      base00 = "#2e3440";
      base01 = "#3b4252";
      base02 = "#434c5e";
      base03 = "#4c566a";
      base04 = "#d8dee9";
      base05 = "#e5e9f0";
      base06 = "#eceff4";
      base07 = "#8fbcbb";
      base08 = "#88c0d0";
      base0A = "#ebcb8b";
      base0B = "#a3be8c";
      base0C = "#88c0d0";
      base0D = "#81a1c1";
      base0E = "#b48ead";
      base0F = "#bf616a";
    };

    dracula = {
      base00 = "#282a36";
      base01 = "#363447";
      base02 = "#44475a";
      base03 = "#6272a4";
      base04 = "#62d6e8";
      base05 = "#f8f8f2";
      base06 = "#f8f8f0";
      base07 = "#ffffff";
      base08 = "#ff5555";
      base0A = "#f1fa8c";
      base0B = "#50fa7b";
      base0C = "#8be9fd";
      base0D = "#80bfff";
      base0E = "#ff79c6";
      base0F = "#ffb86c";
    };
  };
in {
  flake.wallpaper = ./bg.png;
  flake.startIcon = ./vista.png;

  flake.themes = themes;
  flake.theme = themes.${themeName};
}
