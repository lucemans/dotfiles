pkgs: let
  inherit (pkgs) lib;

  voices = {
    cave-low = {
      model = {
        url = "https://huggingface.co/davet2001/cave_johnson1/resolve/main/cave_johnson1.onnx";
        hash = "sha256-LHuP+f/Zw0Gk0waaUd0f9ooeXi0d4Fw0jmBCrfIINj8=";
      };
      config = {
        url = "https://huggingface.co/davet2001/cave_johnson1/resolve/main/cave_johnson1.onnx.json";
        hash = "sha256-Ezikbm5l4hdOzVK7N1yZARB6E0sAGEHpq/pq55UKjXU=";
      };
    };

    cave-medium = {
      model = {
        url = "https://huggingface.co/lucemans/cave-johnson/resolve/main/models/en_US-cave_johnson-medium-v1.onnx";
        hash = "sha256-wZtLtufhM+/M6XRuLnJwuwP5X6pVbKzo3+eyi0sOVBs=";
      };
      config = {
        url = "https://huggingface.co/lucemans/cave-johnson/resolve/main/models/en_US-cave_johnson-medium-v1.onnx.json";
        hash = "sha256-3Gfl7BnN9Kz4qgzl5c2FmL+JDoxH0Gz3BX8BambSaXE=";
      };
    };

    cave-medium2 = {
      model = {
        url = "https://huggingface.co/lucemans/cave-johnson/resolve/main/models/en_US-cave_johnson-medium-v2.onnx";
        hash = "sha256-CO9/f78QXkmWks74S0IOjFdyL4ubXTHmaocgON+BUXs=";
      };
      config = {
        url = "https://huggingface.co/lucemans/cave-johnson/resolve/main/models/en_US-cave_johnson-medium-v2.onnx.json";
        hash = "sha256-C0hIs37k66xmXdTH9gdXx7p1+U7axeR7l2+mXew6JHA=";
      };
    };

    glados-high = {
      model = {
        url = "https://huggingface.co/csukuangfj/vits-piper-en_US-glados-high/resolve/main/en_US-glados-high.onnx";
        hash = "sha256-64nlLsaNFsN2PMzuazgbsK3HKiwtvkGwEfVwL3gDAuQ=";
      };
      config = {
        url = "https://huggingface.co/csukuangfj/vits-piper-en_US-glados-high/resolve/main/en_US-glados-high.onnx.json";
        hash = "sha256-+DdE/2qmE4663hNXtls/hFa8ALntuROreGdOsyPKMtA=";
      };
    };

    glados-medium = {
      model = {
        url = "https://huggingface.co/Stoned-Code/piper-en_US-glados-medium/resolve/main/model.onnx";
        hash = "sha256-3R0VX4hxRSpU/H2zmTkGkdAlLlOiyEBCzUDTPoZ4kL4=";
      };
      config = {
        url = "https://huggingface.co/Stoned-Code/piper-en_US-glados-medium/resolve/main/config.json";
        hash = "sha256-DvB5Z/vci5Zlt6gV2+lfFwQI094EILcr1ytD+X4gy7s=";
      };
    };

    glados-original = {
      model = {
        url = "https://huggingface.co/DavesArmoury/GLaDOS_TTS/resolve/main/glados_piper_medium.onnx";
        hash = "sha256-s1oH+m/HiOxK1jfsmLdNZvBuZku7Q2a0A10d6qwzCNM=";
      };
      config = {
        url = "https://huggingface.co/DavesArmoury/GLaDOS_TTS/resolve/main/glados_piper_medium.onnx.json";
        hash = "sha256-d6EDN3yXHoe/rGqDm+sN6VQz84rPH7ksIB3Nxyhi9CI=";
      };
    };
  };

  # piper reads the voice configuration from <model>.onnx.json next to the
  # model, so both files must share one directory. Upstream repositories name
  # the pair inconsistently, hence the rename.
  mkVoice = name: voice:
    pkgs.runCommand "piper-voice-${name}" {nativeBuildInputs = [pkgs.jq];} ''
      mkdir -p $out
      ln -s ${pkgs.fetchurl voice.model} $out/voice.onnx
      ln -s ${pkgs.fetchurl voice.config} $out/voice.onnx.json
      jq -r '.audio.sample_rate' $out/voice.onnx.json > $out/sample-rate
    '';
in {
  names = lib.attrNames voices;

  dir = pkgs.runCommand "piper-voices" {} (
    lib.concatStringsSep "\n" (
      ["mkdir -p $out"]
      ++ lib.mapAttrsToList (name: voice: "ln -s ${mkVoice name voice} $out/${name}") voices
    )
  );
}
