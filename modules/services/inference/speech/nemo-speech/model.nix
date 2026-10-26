{pkgs}: let
  # `main` at ebe59e5 holds the March 2026 checkpoint (the .nemo was replaced on
  # 2026-03-13). The branch `nemotron-speech-streaming-jan2026` is the
  # superseded January checkpoint.
  revision = "ebe59e5a817142986528bbbee5dba8db7b38ed50";

  checkpoint = pkgs.fetchurl {
    name = "nemotron-speech-streaming-en-0.6b.nemo";
    url = "https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b/resolve/${revision}/nemotron-speech-streaming-en-0.6b.nemo";
    # The LFS object id Hugging Face reports for this file.
    hash = "sha256-KDY4BUxE9nlOdP6a+QSNeKbZ1sBYwSExhWx4WaYqyc0=";
  };

  python = pkgs.python3.withPackages (ps: [
    ps.torch
    ps.numpy
    ps.pyyaml
    ps.gguf
    ps.sentencepiece
    ps.protobuf
  ]);

  converter = "${import ./source.nix {inherit (pkgs) fetchFromGitHub;}}/convert_model.py";
in
  # Converts the checkpoint instead of fetching the GGUF NVIDIA published next
  # to it (nemotron-speech-streaming-en-0.6b.q8_0.gguf in the same revision).
  # That file lacks asr.tokenizer.spm_model, so the server logs "word boosting
  # requested but no phrases could be tokenized" and ignores speech_contexts.
  # It also stores the pointwise convolutions as Q8_0, which upstream's
  # conversion notes name as a cause of speech decoded as long blank runs. The
  # converter at the pinned source embeds the tokenizer and keeps those
  # convolutions at F16.
  pkgs.runCommand "nemotron-speech-streaming-en-0.6b.q8_0.gguf" {
    nativeBuildInputs = [python];
    env.PYTHONDONTWRITEBYTECODE = "1";

    meta = {
      description = "NVIDIA Nemotron Speech Streaming EN 0.6B, cache-aware FastConformer-RNNT, Q8_0 GGUF for NeMo-Speech.cpp";
      homepage = "https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b";
      # NVIDIA Open Model License: commercial use and redistribution allowed
      # with attribution, so the weights may sit in a binary cache.
      license = {
        shortName = "nvidia-open-model-license";
        fullName = "NVIDIA Open Model License Agreement";
        url = "https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-open-model-license/";
        free = false;
        redistributable = true;
      };
      platforms = pkgs.lib.platforms.all;
    };
  } ''
    export HOME=$TMPDIR
    python ${converter} ${checkpoint} --outfile $out --outtype q8_0
  ''
