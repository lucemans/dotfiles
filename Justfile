switch-point:
  nix flake update
  nixos-rebuild switch --flake /etc/nixos#v3x-point

switch-fighter:
  nix flake update
  nixos-rebuild switch --flake /etc/nixos#v3x-fighter
