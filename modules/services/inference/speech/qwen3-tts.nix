{
  pkgs,
  audio,
  dir,
  clones,
}: let
  filename = "Qwen3-TTS-12Hz-1.7B-Base-GGUF/qwen3-tts-12hz-1.7b-base-q8_0_v2.gguf";
  file = {
    repo = "audio-cpp/audio.cpp-gguf";
    rev = "73ce4162f6cce370dd533c6782b772135c1b2a8e";
    file = filename;
    sha256 = "92641a8022d521efd79a5db45e952589b3f2b781680f9abfcf26f075d37b86c6";
    gated = false;
    dest = "${dir}/audio-cpp--audio.cpp-gguf/${filename}";
  };
  presets =
    pkgs.lib.mapAttrs (_: preset: {
      voice_ref = preset.qwen.clip;
      reference_text = preset.qwen.text;
    })
    (pkgs.lib.filterAttrs (_: preset: preset ? qwen) clones.presets);
  serverConfig = (pkgs.formats.json {}).generate "qwen3-tts.json" {
    host = "127.0.0.1";
    backend = "cuda";
    device = 0;
    threads = 8;
    lazy_load = false;
    models = [
      {
        id = "qwen3-tts";
        family = "qwen3_tts";
        path = file.dest;
        task = "tts";
        mode = "offline";
        voice_presets = presets // pkgs.lib.genAttrs clones.openai (_: presets.cave);
      }
    ];
  };
in {
  inherit file;
  swap = {
    cmd = "${audio}/bin/audiocpp_server --config ${serverConfig} --no-ui --port \${PORT}";
    checkEndpoint = "/health";
    ttl = 300;
    concurrencyLimit = 1;
  };
}
