# The clips the cloning TTS on teapot copies each character from, each with
# the exact words spoken in it. GLaDOS comes from the game audio. The others
# have no clean game audio here, so they are rendered by the voices this
# module already ships, which carry the right timbre.
pkgs: let
  inherit (pkgs) lib;
  glados = import ./glados pkgs;
  lines = import ./glados/lines.nix;
  piper = import ./piper.nix pkgs;
  rvc = import ./rvc pkgs;

  # Two calm lines back to back, about ten seconds.
  gladosLines = [0 1];

  said = {
    glados = lib.concatMapStringsSep " " (index: (builtins.elemAt lines index).text) gladosLines;
    cave = "Science is not about why, it is about why not. Why is so much of our science dangerous? Why not marry safe science if you love it so much.";
    ada = "Welcome, pioneer. I am ADA, your artificial directory and assistant. Please remember that productivity is the key to a successful FICSIT career.";
    elmo = "Hi! Elmo is so happy to see you! Elmo was just playing with Dorothy, and now Elmo wants to play with you too.";
  };

  words = lib.mapAttrs (name: text: pkgs.writeText "${name}-reference.txt" text) said;
in
  pkgs.runCommand "tts-voice-references" {
    nativeBuildInputs = [pkgs.sox pkgs.piper-tts];
  } ''
    mkdir -p $out
    export HOME=$TMPDIR

    sox ${lib.concatMapStringsSep " " (index: "${glados.audio}/${toString index}.wav") gladosLines} $out/glados.wav

    piper --model ${piper.dir}/cave-medium/voice.onnx --output-file $out/cave.wav < ${words.cave}

    ${lib.getExe rvc.ada.stream} < ${words.ada} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/ada.wav
    ${lib.getExe rvc.elmo.stream} < ${words.elmo} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/elmo.wav

    ${lib.concatStrings (lib.mapAttrsToList (name: text: "cp ${text} $out/${name}.txt\n") words)}
  ''
