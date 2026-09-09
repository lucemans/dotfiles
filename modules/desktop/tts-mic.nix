_: {
  flake.nixosModules.ttsMic = {
    pkgs,
    lib,
    ...
  }: let
    replacements = {
      pov = "p o v";
      omg = "oh my god";
      ffs = "for fucks sake";
      im = "i am";
      lgtm = "looks good to me";
      idk = "i dont know";
      idc = "i dont care";
      idm = "i dont mind";
      omfg = "oh my fucking god";
    };

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

    voicelines = import ./glados.nix;

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

    voiceDir = pkgs.runCommand "piper-voices" {} (
      lib.concatStringsSep "\n" (
        ["mkdir -p $out"]
        ++ lib.mapAttrsToList (name: voice: "ln -s ${mkVoice name voice} $out/${name}") voices
      )
    );

    voiceMenu = pkgs.writeText "tts-voice-menu" (
      lib.concatStringsSep "\n" (lib.attrNames voices ++ ["voicelines"])
    );

    # A clip is addressed by its position in glados.nix, which is also the line
    # rofi reports with -format i, so the menu and the audio cannot drift apart.
    voicelineFetch = pkgs.writeText "glados-voicelines.curl" (
      lib.concatStringsSep "\n" (
        lib.imap0 (index: line: ''
          url = "${line.url}"
          output = "${toString index}.wav"
        '')
        voicelines
      )
    );

    voicelineAudio =
      pkgs.runCommand "glados-voicelines" {
        nativeBuildInputs = [pkgs.curl];
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-4HJNXWBB2/pHtHOGFNhZe63FQ7Ph98Jp/Ravrmv9psk=";
      } ''
        mkdir -p $out
        cd $out
        curl --config ${voicelineFetch} \
          --parallel --parallel-max 8 \
          --location --fail --retry 3 --silent --show-error
      '';

    voicelineMenu = pkgs.writeText "tts-voiceline-menu" (
      lib.concatStringsSep "\n" (map (line: line.text) voicelines)
    );

    dictionary = pkgs.writeText "tts-replacements.sed" (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList
        (word: spoken: "s|\\b${lib.escapeRegex word}\\b|${lib.escape ["|" "&" "\\"] spoken}|gI")
        replacements
      )
    );

    tts-speak = pkgs.writeShellApplication {
      name = "tts-speak";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnused
        pkgs.piper-tts
        pkgs.pipewire
        pkgs.rofi
      ];
      text = ''
        play() {
          local clip=$1
          shift
          pw-cat --playback "$@" --target tts_mic_sink "$clip" &
          pw-cat --playback "$@" "$clip" &
          wait
        }

        choice=$(rofi -dmenu -i -no-custom -p "Voice" < ${voiceMenu}) || exit 0

        if [ "$choice" = "voicelines" ]; then
          line=$(rofi -dmenu -i -no-custom -format i -p "Line" < ${voicelineMenu}) || exit 0
          play "${voicelineAudio}/$line.wav"
          exit 0
        fi

        text=$(rofi -dmenu -lines 0 -p "Say") || exit 0

        if [ -z "$text" ]; then
          exit 0
        fi

        model="${voiceDir}/$choice"

        clip=$(mktemp --suffix=.raw)
        trap 'rm -f "$clip"' EXIT

        printf '%s\n' "$text" \
          | sed -E -f ${dictionary} \
          | piper --model "$model/voice.onnx" --output-raw > "$clip"

        play "$clip" --raw --channels 1 --format s16 --rate "$(cat "$model/sample-rate")"
      '';
    };

    # media.class Audio/Source/Virtual on the playback side segfaults pipewire
    # 1.6.8 in spa audioconvert reconfigure_mode. Audio/Source is equivalent
    # here and does not crash.
    loopback = lib.concatStringsSep " " [
      "${pkgs.pipewire}/bin/pw-loopback"
      "-c 1 -m '[ MONO ]'"
      "--capture-props='media.class=Audio/Sink node.name=tts_mic_sink node.description=\"TTS Speech Sink\"'"
      "--playback-props='media.class=Audio/Source node.name=tts_mic node.description=\"TTS Microphone\"'"
    ];
  in {
    environment.systemPackages = [tts-speak];

    # Running the loopback as a client keeps a crash inside it away from the
    # daemon, which otherwise takes all system audio down with it.
    systemd.user.services.tts-mic = {
      description = "TTS virtual microphone";
      after = ["pipewire.service"];
      bindsTo = ["pipewire.service"];
      wantedBy = ["pipewire.service"];
      serviceConfig = {
        ExecStart = loopback;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    home-manager.users.luc = {
      programs.plasma.hotkeys.commands."tts-speak" = {
        name = "Speak Text Into Microphone";
        key = "Alt+T";
        command = "${tts-speak}/bin/tts-speak";
      };
    };
  };
}
