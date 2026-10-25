# Every llama.cpp build a model can pick, by name, and the code that builds them.
#
# A model that sets no `llama-cpp` gets `default`. To try another version, a fork or a patch,
# add a chunk to `builds` and name it in the model.
#
#   version      what llama.cpp reports as its version
#   src          arguments for fetchFromGitHub
#   npmDepsHash  of the web UI that llama-server builds
#   patches      files applied on top, none when left out
#
# The CPU flags and the flash-attention KV types depend on the machine, so its model file passes
# them in.
let
  default = "v0.7.0";

  builds = {
    # /v1/systemone and the clef architecture first ship in v0.6.0, gemma-embedding2 in v0.7.0.
    "v0.7.0" = {
      version = "0.7.0";
      src = {
        owner = "ggml-org";
        repo = "llama.cpp";
        tag = "v0.7.0";
        hash = "sha256-pEDYgI3AMTU+cekvRX7NNt5wddznydQSNuerswvEpsA=";
      };
      npmDepsHash = "sha256-hqYzdp1FwPhYkBP278fQXgY9NCKB6Q3P6Gko7BfP0m0=";
      # The nixpkgs patch is a backport that v0.7.0 already contains.
      patches = [];
    };
  };
in
  # Builds every entry of `builds` for one machine, though only the ones a model names are
  # evaluated. `cpuFlags` matter for the layers and experts that stay on the CPU, since the
  # models run on the GPU. `flashAttnQuants` lists the KV cache type pairs the CUDA
  # flash-attention kernels are built for, as "k-v;k-v". A model that asks for a pair outside
  # the list fails to load.
  #
  # Returns `{ default, builds.<name> = { package, server }; }`.
  {
    lib,
    pkgs,
  }: {
    cpuFlags,
    flashAttnQuants,
  }: let
    build = chunk: let
      package =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          cpuArchDynamicDispatch = false;
        }).overrideAttrs (old: {
          inherit (chunk) version npmDepsHash;
          patches = chunk.patches or [];
          src = pkgs.fetchFromGitHub chunk.src;
          cmakeFlags =
            old.cmakeFlags
            ++ map (flag: lib.cmakeBool flag true) cpuFlags
            ++ [(lib.cmakeFeature "GGML_CUDA_FA_QUANTS" flashAttnQuants)];
          doCheck = false;
        });
    in {
      inherit package;
      server = lib.getExe' package "llama-server";
    };
  in {
    inherit default;
    builds = lib.mapAttrs (_: build) builds;
  }
