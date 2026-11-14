{
  pkgs,
  source,
  dir,
  cpuFlags,
  clones,
}: let
  inherit (pkgs) lib;

  # Git submodules of the source, which a flake input does not fetch.
  ggml = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "ggml";
    rev = "a05c9922613c6a2230dbb1d0de679519ecafb4f0";
    hash = "sha256-a/NtFGX7jYITnj6EWE6+H2eyhsKutn0k4IiStihOagA=";
  };
  textnorm = pkgs.fetchFromGitHub {
    owner = "Zyphra";
    repo = "zyphra-textnorm";
    rev = "342e8f980bd472d02673fc616a6ea3b6cbe36474";
    hash = "sha256-SaLbHWjdUqq3dS8tr5vq1voqptNbeoj6eY832xM/jUo=";
  };

  package = pkgs.stdenv.mkDerivation {
    pname = "zonos3";
    version = "bcb6661";
    src = source;
    sourceRoot = "source";
    postUnpack = ''
      chmod -R u+w source
      cp -r ${ggml}/. source/servers/ggml/ggml
      cp -r ${textnorm}/. source/third_party/zyphra-textnorm
      chmod -R u+w source
    '';
    cmakeDir = "../servers/ggml";
    cargoRoot = "third_party/zyphra-textnorm";
    cargoDeps = pkgs.rustPlatform.importCargoLock {lockFile = textnorm + "/Cargo.lock";};
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.git
      pkgs.cargo
      pkgs.rustc
      pkgs.rustPlatform.cargoSetupHook
    ];
    cmakeFlags =
      [
        (lib.cmakeBool "GGML_NATIVE" false)
        (lib.cmakeBool "BUILD_SHARED_LIBS" false)
        (lib.cmakeBool "BUILD_TESTING" false)
        (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
      ]
      ++ map (flag: lib.cmakeBool flag true) cpuFlags;
    ninjaFlags = ["zonos3-server" "spk-encoder-cli"];
    installPhase = ''
      install -Dm755 -t $out/bin zonos3-server spk-encoder-cli
    '';
  };

  rev = "f68e6e470fd14d6d1bc50e8461ee4d4f64d6c513";
  repo = "Zyphra/ZONOS3-Mini";
  modelDir = "${dir}/Zyphra--ZONOS3-Mini";
  weight = name: sha256: {
    inherit repo rev sha256;
    file = "gguf/${name}";
    gated = false;
    dest = "${modelDir}/${name}";
  };
  files = [
    (weight "backbone-ptq.gguf" "66fceb6d73a8c30bde80249e4112bb308380ab7f3384fa11c8e4048115e4ceec")
    (weight "zac-keep2.gguf" "834e5b70b88294afc3c702a478487e0664dcc6b574c16fc6167d72444aabeafd")
  ];

  encoder = pkgs.fetchurl {
    url = "https://huggingface.co/${repo}/resolve/${rev}/gguf/spk-encoder.gguf";
    sha256 = "9539f340b70be246005403b9c254732e180e85e0b3c57fb1973f0d6bc6c59bdc";
  };
  clips = lib.mapAttrs (_: preset: preset.zonos.clip) (lib.filterAttrs (_: preset: preset ? zonos) clones.presets);

  voices = pkgs.runCommand "zonos3-voices" {nativeBuildInputs = [package pkgs.ffmpeg-headless];} ''
    mkdir $out
    ${lib.concatStrings (lib.mapAttrsToList (name: clip: ''
        SPK_THREADS=1 spk-encoder-cli ${encoder} --audio ${clip} $out/${name}.npy --cpu
      '')
      clips)}
  '';

  # The server names a default voice by the hash of its file name in the voices directory.
  voiceId = name: "default_${builtins.substring 0 16 (builtins.hashString "sha1" "${name}.npy")}";

  entry = name: {
    cmd = "${package}/bin/zonos3-server ${modelDir}/backbone-ptq.gguf --cpu --batch 1 --zac-threads 1 --tts-default-voices-dir ${voices} --host 127.0.0.1 --port \${PORT}";
    proxy = "http://127.0.0.1:\${PORT}";
    checkEndpoint = "/v2/health";
    ttl = 300;
    concurrencyLimit = 1;
    # The server answers only pcm and wav, but OpenAI clients ask for mp3.
    filters.setParams = {
      speaker_mode = "embedding";
      voice = voiceId name;
      response_format = "wav";
    };
  };
in {
  inherit files;
  swap = lib.mapAttrs' (name: _: lib.nameValuePair "zonos3-${name}" (entry name)) clips;
}
