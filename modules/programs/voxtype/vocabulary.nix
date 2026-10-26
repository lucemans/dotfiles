# The system vocabulary file Voxtype reads at the start of every recording.
# One entry per line: a bare term is boosted; `heard => meant` rewrites the
# recognized words and boosts the replacement. The same format is used by the
# per-user file edited with voxtype-vocab.
{
  lib,
  pkgs,
  words,
  corrections,
}:
pkgs.writeText "voxtype-vocabulary.txt" (
  lib.concatStringsSep "\n" (
    ["# Generated from programs.voxtype.vocabulary. Add personal entries with voxtype-vocab."]
    ++ words
    ++ lib.mapAttrsToList (heard: meant: "${heard} => ${meant}") corrections
  )
  + "\n"
)
