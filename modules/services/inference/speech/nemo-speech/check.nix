{
  pkgs,
  package,
  model,
}: let
  python = pkgs.python3.withPackages (ps: [ps.websockets]);
  # NVIDIA's own regression clip: JFK, "ask not what your country can do for
  # you", 16 kHz mono PCM16.
  speech = "${package.src}/test_files/asr/wav/test/jfk.wav";
in
  pkgs.runCommand "nemo-speech-check" {} ''
    ${python}/bin/python ${./test_server.py} ${pkgs.lib.getExe package} ${model} ${speech}
    touch $out
  ''
