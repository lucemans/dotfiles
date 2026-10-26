{fetchFromGitHub}:
# e680fc3, the head of main on 2026-10-24: v0.2.0 plus nine commits. The runtime
# and the model converter live in this tree and change together, so both build
# from this one pin.
#
# v0.2.0 (6a3ca36) has the realtime route, speech_contexts and
# rnnt_right_context as well, but streams worse. With the same GGUF and a clip
# that starts speaking at once, it returned an empty transcript where e680fc3
# returned the whole sentence. The likely cause is #46, which fixes the first
# chunk's alignment and keeps the pointwise convolutions of cache-aware Q8_0
# models at F16.
fetchFromGitHub {
  owner = "NVIDIA";
  repo = "NeMo-Speech.cpp";
  rev = "e680fc30ac7404ba3acd58532f713becf8625894";
  hash = "sha256-jRzV5nfRdjDFrUDX+fskS3IuTS1ALAnBc/w+wKv/qrU=";
}
