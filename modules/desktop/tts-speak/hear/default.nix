# Turns what the far end of a call says into text, so the typing window can
# follow the conversation. faster-whisper runs on the CPU in int8, which keeps
# a few seconds of speech well under a second.
pkgs: let
  revision = "d1d751a5f8271d482d14ca55d9e2deeebbae577f";
  file = name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/Systran/faster-whisper-small.en/resolve/${revision}/${name}";
      inherit hash;
    };

  model = pkgs.linkFarm "faster-whisper-small.en" {
    "config.json" = file "config.json" "sha256-ZmqWBVMKwfYfqBd/NwK02s7JlmdJ5CYQg5/MMmYdX64=";
    "model.bin" = file "model.bin" "sha256-YrKkWwXuWay0pTQbM+414EE5XTeNQYoYrP5MnnaO43o=";
    "tokenizer.json" = file "tokenizer.json" "sha256-kpxSUkCUNtzhs4p10au8teEy0XDY4yTk4E7ZFfotIt8=";
    "vocabulary.txt" = file "vocabulary.txt" "sha256-/3dYh0bTolldMqtbaf/XuVziRBrFdTPLZvw+tXWhFc8=";
  };

  hear = pkgs.writers.writePython3Bin "tts-hear" {
    libraries = with pkgs.python3Packages; [faster-whisper numpy];
    flakeIgnore = ["E501"];
  } (builtins.readFile ./hear.py);
in
  pkgs.writeShellScript "tts-hear-small-en" ''
    exec ${hear}/bin/tts-hear ${model}
  ''
