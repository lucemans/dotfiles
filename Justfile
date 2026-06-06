vm:
  nix build .#nixosConfigurations.fighter-vm.config.system.build.vm
  mkdir -p .vm-state
  # Keep empty0.qcow2 (preservation backing store) across VM runs.
  TMPDIR="$(pwd)/.vm-state" USE_TMPDIR=1 GDK_BACKEND=x11 ./result/bin/run-v3x-fighter-vm

switch-point:
  nix flake update
  nixos-rebuild switch --flake /etc/nixos#point
