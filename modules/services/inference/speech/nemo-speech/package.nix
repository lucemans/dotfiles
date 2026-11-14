{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  git,
  sentencepiece,
  abseil-cpp,
  cudaPackages,
  autoAddDriverRunpath,
  cuda ? true,
  cudaCapabilities ? ["7.5" "8.6" "8.9" "12.0"],
}: let
  llamaCpp = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "bd4f514db14d87fded667787a7a963bfbaa98e89";
    hash = "sha256-iYK2+ukOODgTMSO9shS4l5dSJ1jnVYy78W+EDdUq+Nk=";
  };
  httplib = fetchFromGitHub {
    owner = "yhirose";
    repo = "cpp-httplib";
    rev = "62d899feac3cf9215a55f2b43da250fdd98d2156";
    hash = "sha256-4Y3BSo4LvCBwO6tsCYUlmFt/HrieS1p1MViN0Ac+Isk=";
  };

  effectiveStdenv =
    if cuda
    then cudaPackages.backendStdenv
    else stdenv;

  cudaArchitectures = lib.concatMapStringsSep ";" (capability: "${lib.replaceStrings ["."] [""] capability}-real") cudaCapabilities;
in
  effectiveStdenv.mkDerivation {
    pname = "nemo-speech${lib.optionalString (!cuda) "-cpu"}";
    version = "0.2.0-unstable-2026-10-24";

    src = import ./source.nix {inherit fetchFromGitHub;};

    postPatch = ''
      rmdir llama.cpp third_party/cpp-httplib
      cp -r --no-preserve=mode ${llamaCpp} llama.cpp
      cp -r --no-preserve=mode ${httplib} third_party/cpp-httplib
    '';

    nativeBuildInputs =
      [
        cmake
        ninja
        git
      ]
      ++ lib.optionals cuda [
        cudaPackages.cuda_nvcc
        autoAddDriverRunpath
      ];

    buildInputs =
      [
        sentencepiece
        abseil-cpp
      ]
      ++ lib.optionals cuda (with cudaPackages; [
        cccl
        cuda_cudart
        libcublas
      ]);

    cmakeFlags =
      [
        (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
        (lib.cmakeBool "NEMO_SPEECH_GGML_PATCHED" true)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_ASR" true)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_DIAR" true)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_TTS" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_NMT" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_HTTP" true)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_GRPC" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_MIC_CAPTURE" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_EXAMPLES" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_TESTS" false)
        (lib.cmakeBool "NEMO_SPEECH_BUILD_TOOLS" false)
        (lib.cmakeBool "GGML_LLAMAFILE" true)
        (lib.cmakeBool "GGML_NATIVE" false)
        (lib.cmakeBool "GGML_CUDA" cuda)
      ]
      ++ lib.optionals cuda [
        (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaArchitectures)
      ];

    meta = {
      description = "NVIDIA NeMo-Speech.cpp, a ggml runtime for streaming speech recognition${lib.optionalString cuda " on CUDA"}";
      homepage = "https://github.com/NVIDIA/NeMo-Speech.cpp";
      license = lib.licenses.asl20;
      mainProgram = "nemo-speech";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
