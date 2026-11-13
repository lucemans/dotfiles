{
  pkgs,
  audio,
  dir,
}: let
  references = import ../../../programs/tts-speak/references.nix pkgs;
  caveLines = [
    {
      file = "Cave_Johnson_fifties_intro01.wav";
      sha256 = "2c1505ec9eae5658dfbff605e4447cc7d16dcb008b03657cff1098ef2b6c6b23";
      text = "Welcome, gentlemen, to Aperture Science. Astronauts, war heroes, Olympians--you're here because we want the best, and you are it. So: Who is ready to make some science?";
    }
    {
      file = "Cave_Johnson_fifties_outro05.wav";
      sha256 = "f8a00fa2029003cd522c4b53e96d4105882458ffdadc8ed83709deef85ebefd0";
      text = "As founder and CEO of Aperture Science, I thank you for your participation and hope we can count on you for another round of tests.";
    }
    {
      file = "Cave_Johnson_fifties_outro02.wav";
      sha256 = "ab778384c160a9b3668bb7cbd94f9582b8cf88599a2fbae925f5274af8bd87f1";
      text = "Congratulations! The simple fact that you're standing here listening to me means you've made a glorious contribution to science.";
    }
  ];
  caveClips = map (line:
    pkgs.fetchurl {
      url = "https://huggingface.co/datasets/lucemans/cave-johnson/resolve/1159e788bfead6604b19f2433f6bcb3df867fa44/data/wav-44100/${line.file}";
      inherit (line) sha256;
    })
  caveLines;
  caveLong = pkgs.runCommand "cave-reference.wav" {nativeBuildInputs = [pkgs.sox];} ''
    sox ${toString caveClips} $out
  '';
  filename = "drama-3-backbone-8bit-experts-Q2_K.gguf";
  file = {
    repo = "Jmica/Drama-3-GGUF";
    rev = "060acc8e5d9e5d16baf647c775dfe1a1438f5f35";
    file = filename;
    sha256 = "5cb86588eff6404f4482830cfd3d69713f27115c02530a29f772535262fb7826";
    gated = false;
    dest = "${dir}/Jmica--Drama-3-GGUF/${filename}";
  };
  serverConfig = (pkgs.formats.json {}).generate "fish-drama3.json" {
    host = "127.0.0.1";
    backend = "cuda";
    device = 0;
    threads = 8;
    lazy_load = false;
    ui = true;
    models = [
      {
        id = "fish-drama3";
        family = "fish_drama3";
        path = file.dest;
        task = "tts";
        mode = "offline";
        session_options = {
          "fish_drama3.cpu_expert_layers" = 8;
          "fish_drama3.context_length" = 2048;
          "fish_drama3.codec_encoder_chunk_samples" = 131072;
        };
        default_request_options.max_tokens = 500;
        voice_presets = rec {
          cave = {
            voice_ref = "${builtins.head caveClips}";
            reference_text = (builtins.head caveLines).text;
          };
          cave-long = {
            voice_ref = "${caveLong}";
            reference_text = pkgs.lib.concatMapStringsSep " " (line: line.text) caveLines;
          };
          ada = {
            voice_ref = "${references}/ada.wav";
            reference_text = references.said.ada;
          };
          alloy = cave;
          ash = cave;
          ballad = cave;
          coral = cave;
          echo = cave;
          fable = cave;
          nova = cave;
          onyx = cave;
          sage = cave;
          shimmer = cave;
          verse = cave;
        };
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
