# The game voicelines tts-speak plays on request from its voicelines menu, per
# character. Only GLaDOS has any. Each has its words and the file it plays,
# in ./glados/lines.nix.
pkgs: {
  glados = import ./glados pkgs;
}
