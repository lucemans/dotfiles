# The in-game ADA voice is Google's en-US-Wavenet-C put through Audacity's
# Multi-Voice Chorus and Delay effects, as described in
# https://satisfactory.guru/articles/read/index/id/47/name/ADA+Voice
# This reproduces that recipe: the same cloud voice, the same two effects.
pkgs: keyFile: let
  effects =
    pkgs.writers.writePython3Bin "ada-effects" {
      libraries = [pkgs.python3Packages.numpy];
      flakeIgnore = ["E501"];
    } (builtins.readFile ./ada-effects.py);
in
  pkgs.writeShellApplication {
    name = "ada-google-speak";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.jq effects];
    text = ''
      target=$1
      scratch=$(mktemp -d)
      trap 'rm -rf "$scratch"' EXIT

      # printf is a shell builtin, so the key never reaches a process table
      # entry, and curl reads the header from the file instead of its argv.
      umask 077
      printf 'header = "X-Goog-Api-Key: %s"\n' "$(cat ${keyFile})" > "$scratch/curl.conf"

      jq -Rs '{
        input: {text: .},
        voice: {languageCode: "en-US", name: "en-US-Wavenet-C"},
        audioConfig: {audioEncoding: "LINEAR16"}
      }' \
        | curl --silent --show-error --fail \
            --config "$scratch/curl.conf" \
            --header "Content-Type: application/json" \
            --data @- \
            https://texttospeech.googleapis.com/v1/text:synthesize \
        | jq -r .audioContent \
        | base64 --decode \
        | ada-effects > "$target"
    '';
  }
