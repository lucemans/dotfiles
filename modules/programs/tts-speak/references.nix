# The clips the cloning TTS on teapot copies each character from, each with
# the exact words spoken in it. GLaDOS and Cave come from the game audio. The
# others have no clean game audio here, so they are rendered by the voices
# this module already ships, which carry the right timbre.
pkgs: let
  inherit (pkgs) lib;
  glados = import ./glados pkgs;
  lines = import ./glados/lines.nix;
  cave = pkgs.fetchurl {
    url = "https://huggingface.co/datasets/lucemans/cave-johnson/resolve/1159e788bfead6604b19f2433f6bcb3df867fa44/data/wav-44100/Cave_Johnson_fifties_intro01.wav";
    sha256 = "2c1505ec9eae5658dfbff605e4447cc7d16dcb008b03657cff1098ef2b6c6b23";
  };
  rvc = import ./rvc pkgs;

  # Two calm lines back to back, about ten seconds.
  gladosLines = [0 1];

  said = {
    glados = lib.concatMapStringsSep " " (index: (builtins.elemAt lines index).text) gladosLines;
    cave = "Welcome, gentlemen, to Aperture Science. Astronauts, war heroes, Olympians--you're here because we want the best, and you are it. So: Who is ready to make some science?";
    ada = "Welcome, pioneer. I am ADA, your artificial directory and assistant. Please remember that productivity is the key to a successful FICSIT career.";
    elmo = "Hi! Elmo is so happy to see you! Elmo was just playing with Dorothy, and now Elmo wants to play with you too.";
  };

  words = lib.mapAttrs (name: text: pkgs.writeText "${name}-reference.txt" text) said;
in
  pkgs.runCommand "tts-voice-references" {
    nativeBuildInputs = [pkgs.sox];
    passthru = {inherit said;};
  } ''
    mkdir -p $out
    export HOME=$TMPDIR

    sox ${lib.concatMapStringsSep " " (index: "${glados.audio}/${toString index}.wav") gladosLines} $out/glados.wav

    cp ${cave} $out/cave.wav

    ${lib.getExe rvc.ada.stream} < ${words.ada} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/ada.wav
    ${lib.getExe rvc.elmo.stream} < ${words.elmo} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/elmo.wav

    ${lib.concatStrings (lib.mapAttrsToList (name: text: "cp ${text} $out/${name}.txt\n") words)}
  ''
