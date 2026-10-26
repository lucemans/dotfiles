{
  imports = [
    ./models/teapot.nix
    ./models/mediabus.nix
    ./gateway/litellm.nix
    ./gateway/cliproxy.nix
    ./speech/piper.nix
    ./speech/nemo-speech.nix
    ./speech/qwen3-speech.nix
    ./ui/librechat.nix
    ./ui/usage.nix
  ];
}
