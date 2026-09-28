_: {
  flake.nixosModules.ttsSpeak = {
    pkgs,
    lib,
    config,
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

    piper = import ./piper.nix pkgs;
    rvc = import ./rvc pkgs;
    glados = import ./glados pkgs;
    hear = import ./hear pkgs;
    inherit (import ../../network/services.nix) services;
    ada-google-speak =
      import ./ada-google pkgs config.sops.secrets.google_tts_key.path;

    # Voices the Qwen3-TTS server on teapot clones, named as it knows them.
    clones = ["glados" "cave" "ada" "elmo"];
    cloneNames = map (voice: "${voice}-clone") clones;

    voiceMenu = pkgs.writeText "tts-voice-menu" (
      lib.concatStringsSep "\n" (
        cloneNames
        ++ ["ada" "ada-google" "elmo"]
        ++ piper.names
        ++ ["ada-changer" "elmo-changer" "voicelines"]
      )
    );

    dictionary = pkgs.writeText "tts-replacements.sed" (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList
        (word: spoken: "s|\\b${lib.escapeRegex word}\\b|${lib.escape ["|" "&" "\\"] spoken}|gI")
        replacements
      )
    );

    # Handed to the model with every request, so the replies it proposes stay
    # in character. The piper voices are named <character>-<variant>.
    characters = {
      ada = "ADA, the Artificial Directory and Assistant of FICSIT Inc. from the factory game Satisfactory by Coffee Stain Studios. A calm, formal corporate AI who addresses pioneers about productivity, efficiency, compliance and FICSIT, with deadpan and faintly passive-aggressive humour.";
      elmo = "Elmo, the furry red three-and-a-half-year-old monster from Sesame Street. He always talks about himself in the third person, as in \"Elmo loves you!\", is endlessly cheerful, curious and giggly, and loves his goldfish Dorothy, crayons and hugs.";
      cave = "Cave Johnson, the founder and CEO of Aperture Science from Valve's Portal 2. A loud, brash, overconfident showman who announces reckless science, goes off on tangents, and rants about lemons, moon rocks and his assistant Caroline.";
      glados = "GLaDOS, the Genetic Lifeform and Disk Operating System, the AI who runs the Aperture Science Enrichment Center in Valve's Portal games. Coldly polite and passive-aggressive, with dry, cutting sarcasm about testing, science, cake and neurotoxin, and thinly veiled insults.";
    };
    personas = pkgs.linkFarm "tts-personas" (
      lib.genAttrs (["ada" "elmo"] ++ piper.names ++ cloneNames) (
        name: pkgs.writeText "tts-persona-${name}" characters.${lib.head (lib.splitString "-" name)}
      )
    );

    tts-type =
      pkgs.writers.writePython3Bin "tts-type" {flakeIgnore = ["E501"];}
      (builtins.readFile ./tts-type.py);

    tts-play =
      pkgs.writers.writePython3Bin "tts-play" {flakeIgnore = ["E501"];}
      (builtins.readFile ./tts-play.py);

    piper-stream = pkgs.writers.writePython3Bin "piper-stream" {
      libraries = [(pkgs.python3Packages.toPythonModule pkgs.piper-tts)];
      flakeIgnore = ["E501"];
    } (builtins.readFile ./piper-stream.py);

    speech-stream =
      pkgs.writers.writePython3Bin "speech-stream" {flakeIgnore = ["E501"];}
      (builtins.readFile ./speech-stream.py);

    # Each renderer keeps its voice loaded and turns every text line on stdin
    # into raw 16-bit mono audio on stdout, so clauses handed over while the
    # rest is still being typed start the audio long before the sentence is
    # complete. ada-google renders a whole clip in one cloud call and cannot
    # take part in this.
    tts-session = pkgs.writeShellApplication {
      name = "tts-session";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnused
        pkgs.pipewire
        tts-play
        tts-type
      ];
      text = ''
        persona=$1
        rate=$2
        shift 2

        scratch=$(mktemp -d)
        trap 'rm -rf "$scratch"' EXIT
        mkfifo "$scratch/status"

        tts-type \
            --status "$scratch/status" \
            --persona "$persona" \
            --api https://${services.inference.name}/v1 \
            --model v3x-m/nex-n2.5-mini-uncensored \
            --token ${config.sops.secrets.v3x_inference_token.path} \
          | sed -u -E -f ${dictionary} \
          | tts-play \
              --sink tts_mic_sink \
              --rate "$rate" \
              --status "$scratch/status" \
              --transcriber ${hear} \
              -- "$@"
      '';
    };

    tts-speak = pkgs.writeShellApplication {
      name = "tts-speak";
      runtimeInputs = [
        ada-google-speak
        pkgs.coreutils
        pkgs.gnused
        pkgs.kitty
        pkgs.pipewire
        pkgs.rofi
        tts-play
        tts-session
      ];
      text = ''
        choice=$(rofi -dmenu -i -no-custom -p "Voice" < ${voiceMenu}) || exit 0

        if [ "$choice" = "voicelines" ]; then
          line=$(rofi -dmenu -i -no-custom -format i -p "Line" < ${glados.menu}) || exit 0
          tts-play --sink tts_mic_sink --wav "${glados.audio}/$line.wav"
          exit 0
        fi

        case "$choice" in
          ada-google)
            text=$(rofi -dmenu -lines 0 -p "Say") || exit 0

            if [ -z "$text" ]; then
              exit 0
            fi

            clip=$(mktemp --suffix=.wav)
            trap 'rm -f "$clip"' EXIT

            printf '%s\n' "$text" \
              | sed -E -f ${dictionary} \
              | ada-google-speak "$clip"

            tts-play --sink tts_mic_sink --wav "$clip"
            exit 0
            ;;
          ada-changer)
            exec kitty --class tts-speak --title "Voice changer" ${lib.getExe rvc.ada.live} tts_mic_sink
            ;;
          elmo-changer)
            exec kitty --class tts-speak --title "Voice changer" ${lib.getExe rvc.elmo.live} tts_mic_sink
            ;;
          *-clone)
            session=(24000 ${lib.getExe speech-stream}
              --api https://${services.inference.name}/v1
              --model v3x-t/qwen3-tts
              --token ${config.sops.secrets.v3x_inference_token.path}
              --voice "''${choice%-clone}")
            ;;
          ada) session=(${toString rvc.rate} ${lib.getExe rvc.ada.stream}) ;;
          elmo) session=(${toString rvc.rate} ${lib.getExe rvc.elmo.stream}) ;;
          *)
            voice=${piper.dir}/$choice
            session=("$(cat "$voice/sample-rate")" ${lib.getExe piper-stream} "$voice/voice.onnx")
            ;;
        esac

        exec kitty --class tts-speak --title "Speak" tts-session "${personas}/$choice" "''${session[@]}"
      '';
    };
  in {
    imports = [./mic.nix];

    environment.systemPackages = [tts-speak];

    sops.secrets.google_tts_key = {
      owner = "luc";
      mode = "0400";
    };

    # Also declared by the opencode provider module. The same values merge, and
    # hosts without opencode still get the token.
    sops.secrets.v3x_inference_token = {
      owner = "luc";
      mode = "0400";
    };

    home-manager.users.luc = {
      programs.plasma.hotkeys.commands."tts-speak" = {
        name = "Speak Text Into Microphone";
        key = "Alt+T";
        # Plasma caches the Exec line of the hotkey until the next login, so a
        # store path here keeps running the build from before the last switch.
        command = "/run/current-system/sw/bin/tts-speak";
      };
    };
  };
}
