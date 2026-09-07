{...}: {
  flake.nixosModules.piperSpeech = {
    pkgs,
    lib,
    ...
  }: let
    port = 8083;

    voices = {
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
    voiceDir = pkgs.runCommand "piper-voices" {} (
      lib.concatStringsSep "\n" (
        ["mkdir -p $out"]
        ++ lib.concatLists (
          lib.mapAttrsToList (name: voice: [
            "ln -s ${pkgs.fetchurl voice.model} $out/${name}.onnx"
            "ln -s ${pkgs.fetchurl voice.config} $out/${name}.onnx.json"
          ])
          voices
        )
      )
    );

    # The training and alignment extras pull torch and onnx, which triple the
    # closure for code this server never reaches.
    piper = pkgs.piper-tts.override {
      withTrain = false;
      withAlignment = false;
    };

    speechServer =
      pkgs.writers.writePython3Bin "piper-speech" {
        libraries = [
          (pkgs.python3Packages.toPythonModule piper)
          pkgs.python3Packages.flask
        ];
        flakeIgnore = ["E501"];
      } ''
        """OpenAI-compatible /v1/audio/speech backed by piper ONNX voices."""

        import io
        import subprocess
        import wave
        from pathlib import Path

        from flask import Flask, Response, jsonify, request
        from piper import PiperVoice

        ENCODERS = {
            "mp3": (["-f", "mp3"], "audio/mpeg"),
            "opus": (["-f", "ogg", "-c:a", "libopus"], "audio/ogg"),
            "aac": (["-f", "adts"], "audio/aac"),
            "flac": (["-f", "flac"], "audio/flac"),
            "pcm": (["-f", "s16le"], "audio/pcm"),
        }

        voices = {
            path.stem: PiperVoice.load(path)
            for path in sorted(Path("${voiceDir}").glob("*.onnx"))
        }

        app = Flask(__name__)


        @app.post("/v1/audio/speech")
        def speech():
            body = request.get_json(force=True)

            text = (body.get("input") or "").strip()
            if not text:
                return jsonify(error={"message": "input is required"}), 400

            name = body.get("voice")
            voice = voices.get(name)
            if voice is None:
                return jsonify(error={"message": f"unknown voice {name!r}, expected one of {sorted(voices)}"}), 400

            audio_format = body.get("response_format", "mp3")
            if audio_format != "wav" and audio_format not in ENCODERS:
                return jsonify(error={"message": f"unsupported response_format {audio_format!r}"}), 400

            with io.BytesIO() as buffer:
                with wave.open(buffer, "wb") as wav_file:
                    voice.synthesize_wav(text, wav_file)
                audio = buffer.getvalue()

            if audio_format == "wav":
                return Response(audio, mimetype="audio/wav")

            encoder_args, mimetype = ENCODERS[audio_format]
            encoded = subprocess.run(
                ["${lib.getExe pkgs.ffmpeg}", "-loglevel", "error", "-i", "pipe:0", *encoder_args, "pipe:1"],
                input=audio,
                capture_output=True,
                check=True,
            ).stdout
            return Response(encoded, mimetype=mimetype)


        app.run(host="127.0.0.1", port=${toString port})
      '';
  in {
    systemd.services.piper-speech = {
      description = "Piper text to speech API";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${speechServer}/bin/piper-speech";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
