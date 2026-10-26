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
  # CUDA build, or the CPU-only one the checks run.
  cuda ? true,
  # Turing, Ampere (A4000, RTX 30), Ada and consumer Blackwell. A host that sets
  # nixpkgs.config.cudaCapabilities passes its own list here and compiles one
  # architecture instead of four, which is most of the build time.
  cudaCapabilities ? ["7.5" "8.6" "8.9" "12.0"],
}: let
  # llama.cpp provides ggml and cpp-httplib serves HTTP. Upstream wires both in
  # as submodules, which fetchFromGitHub leaves empty, so each is pinned at the
  # commit the pinned tree records for it (the same two as at v0.2.0).
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

  # nvcc only supports the host compilers its CUDA release was tested with.
  effectiveStdenv =
    if cuda
    then cudaPackages.backendStdenv
    else stdenv;

  # "8.6" becomes "86-real". ggml rewrites 12x to 12xa, which Blackwell needs
  # for its FP4 instructions. Real code only, since the capabilities list is
  # the set of GPUs the host owns.
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
        # cmake/llama_cpp.cmake runs `git apply` for patches/ on a copy of
        # llama.cpp at configure time. It works on a tree that is not a
        # checkout, but needs the binary.
        git
      ]
      ++ lib.optionals cuda [
        cudaPackages.cuda_nvcc
        autoAddDriverRunpath
      ];

    buildInputs =
      [
        sentencepiece
        # sentencepiece 0.2.1 headers include Abseil, and the ASR library links it.
        abseil-cpp
      ]
      ++ lib.optionals cuda (with cudaPackages; [
        cccl
        cuda_cudart
        libcublas
      ]);

    # The upstream cpu-server and cuda-server presets, minus what a dictation
    # server never calls: TTS, NMT, the microphone and the playground's
    # TLS. ASR, diarization, the CLI and the HTTP/WebSocket server stay.
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
        # -march=native would tie the store path to the builder's CPU.
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
