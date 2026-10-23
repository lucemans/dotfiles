{
  perSystem = {pkgs, ...}: {
    packages.herdr-relay =
      pkgs.writers.writePython3Bin "herdr-relay" {flakeIgnore = ["E501"];}
      (builtins.readFile ./herdr-relay.py);
  };
}
