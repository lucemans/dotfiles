{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    neofetch
    micro
    telegram-desktop
    unstable.firefox-devedition-bin
    gnumake
    fish
    lm_sensors
    stress-ng
  ];
}
