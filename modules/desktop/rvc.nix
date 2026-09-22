# Piper reads the line in a neutral voice and an RVC model replaces the timbre.
# One argument set describes one voice: the archive it ships in, the checkpoint
# and index names inside that archive, and the transpose in semitones that puts
# the neutral render into the pitch range the model was trained on.
pkgs: let
  python = pkgs.python3Packages;

  torchfcpe = python.buildPythonPackage rec {
    pname = "torchfcpe";
    version = "0.0.4";
    format = "wheel";
    src = python.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-8ELEY9hQ12xvSJmguE8LaUu1YK3wX03pUQl6dW0XRy0=";
    };
    propagatedBuildInputs = with python; [torch torchaudio numpy einops local-attention];
    doCheck = false;
  };

  applioSource = pkgs.fetchFromGitHub {
    owner = "IAHispano";
    repo = "Applio";
    rev = "55fe0b976a6990bb75261c32ccecf6bfca3198f1";
    hash = "sha256-ITFZqe9Qm/O7O5ZXbHLwVdzhifd8l6fmf1Jc49VJdf4=";
  };

  # Applio looks for its embedder and pitch predictor at fixed paths under the
  # working directory and downloads them when they are missing, so the checkout
  # and the weights have to be assembled into one tree up front.
  applio = pkgs.runCommand "applio-inference" {} ''
    mkdir -p $out
    cp -r ${applioSource}/rvc $out/rvc
    chmod -R u+w $out/rvc
    mkdir -p $out/rvc/models/embedders/contentvec $out/rvc/models/predictors
    ln -s ${pkgs.fetchurl {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/pytorch_model.bin";
      hash = "sha256-2N1ADgVN305r512rWiVJ23SMyZ51agl8SWwJn2WkhU4=";
    }} $out/rvc/models/embedders/contentvec/pytorch_model.bin
    ln -s ${pkgs.fetchurl {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/embedders/contentvec/config.json";
      hash = "sha256-Ld3gY7eV042QUachWgkv7PTP4Ui1QlHjjeUdiNNWiYs=";
    }} $out/rvc/models/embedders/contentvec/config.json
    ln -s ${pkgs.fetchurl {
      url = "https://huggingface.co/IAHispano/Applio/resolve/main/Resources/predictors/rmvpe.pt";
      hash = "sha256-bWIhX0MG48ongkYYhgcgnwmvPcd+1CMu/dBpeYxOwZM=";
    }} $out/rvc/models/predictors/rmvpe.pt
  '';

  # RVC keeps the wording, pacing and pitch contour of the source and rewrites
  # only the timbre. Flatter sources were tried and lost on listening, so this
  # one is chosen by ear.
  source = pkgs.runCommand "rvc-source-voice" {} ''
    mkdir -p $out
    ln -s ${pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx";
      hash = "sha256-TKv3w6Y4AXE380oVFlIgMtT+PzgiioQ8ybdk3cvNngk=";
    }} $out/voice.onnx
    ln -s ${pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json";
      hash = "sha256-20K5fZhZ8le8FWG47ZgOf7I5hAIFCnTd1svskxqSQS8=";
    }} $out/voice.onnx.json
  '';

  convert = pkgs.writers.writePython3Bin "rvc-convert" {
    libraries =
      [torchfcpe]
      ++ (with python; [
        faiss
        librosa
        local-attention
        numpy
        scipy
        soundfile
        soxr
        torch
        torchaudio
        torchcrepe
        transformers
        wget
      ]);
    flakeIgnore = ["E501"];
  } (builtins.readFile ./rvc-convert.py);
in
  {
    name,
    archive,
    model,
    index,
    pitch,
  }: let
    voice =
      pkgs.runCommand "${name}-rvc-voice" {
        nativeBuildInputs = [pkgs.unzip];
      } ''
        mkdir -p $out
        unzip -j ${pkgs.fetchurl archive} -d $out
      '';
  in
    pkgs.writeShellApplication {
      name = "${name}-speak";
      runtimeInputs = [pkgs.coreutils pkgs.piper-tts convert];
      text = ''
        target=$(realpath -m "$1")
        scratch=$(mktemp -d)
        trap 'rm -rf "$scratch"' EXIT

        piper --model ${source}/voice.onnx --output-file "$scratch/source.wav"

        # Applio resolves rvc/models/... against the working directory, and both
        # transformers and numba write caches that must not land in the store.
        cd ${applio}
        PYTHONPATH=${applio} HF_HOME=$scratch NUMBA_CACHE_DIR=$scratch \
          rvc-convert \
          ${voice}/${model} \
          ${voice}/${index} \
          ${toString pitch} \
          "$scratch/source.wav" \
          "$target"
      '';
    }
