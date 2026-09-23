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
    ada-google-speak =
      import ./ada-google pkgs config.sops.secrets.google_tts_key.path;

    voiceMenu = pkgs.writeText "tts-voice-menu" (
      lib.concatStringsSep "\n" (
        ["ada" "ada-google" "elmo"] ++ piper.names ++ ["voicelines"]
      )
    );

    dictionary = pkgs.writeText "tts-replacements.sed" (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList
        (word: spoken: "s|\\b${lib.escapeRegex word}\\b|${lib.escape ["|" "&" "\\"] spoken}|gI")
        replacements
      )
    );

    tts-type =
      pkgs.writers.writePython3Bin "tts-type" {flakeIgnore = ["E501"];}
      (builtins.readFile ./tts-type.py);

    tts-play =
      pkgs.writers.writePython3Bin "tts-play" {flakeIgnore = ["E501"];}
      (builtins.readFile ./tts-play.py);

    # piper keeps the voice loaded and renders one line at a time, so feeding it
    # finished words as they are typed starts the audio long before the sentence
    # is complete. The other voices render a whole clip in one call and cannot
    # take part in this.
    tts-session = pkgs.writeShellApplication {
      name = "tts-session";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnused
        pkgs.piper-tts
        pkgs.pipewire
        tts-play
        tts-type
      ];
      text = ''
        model=$1

        tts-type \
          | sed -u -E -f ${dictionary} \
          | tts-play \
              --sink tts_mic_sink \
              --model "$model/voice.onnx" \
              --rate "$(cat "$model/sample-rate")"
      '';
    };

    tts-speak = pkgs.writeShellApplication {
      name = "tts-speak";
      runtimeInputs = [
        rvc.ada
        ada-google-speak
        rvc.elmo
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
          ada) render=ada-speak ;;
          ada-google) render=ada-google-speak ;;
          elmo) render=elmo-speak ;;
          *) render="" ;;
        esac

        if [ -n "$render" ]; then
          text=$(rofi -dmenu -lines 0 -p "Say") || exit 0

          if [ -z "$text" ]; then
            exit 0
          fi

          clip=$(mktemp --suffix=.wav)
          trap 'rm -f "$clip"' EXIT

          printf '%s\n' "$text" \
            | sed -E -f ${dictionary} \
            | "$render" "$clip"

          tts-play --sink tts_mic_sink --wav "$clip"
          exit 0
        fi

        exec kitty --class tts-speak --title "Speak" tts-session "${piper.dir}/$choice"
      '';
    };
  in {
    imports = [./mic.nix];

    environment.systemPackages = [tts-speak];

    sops.secrets.google_tts_key = {
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
