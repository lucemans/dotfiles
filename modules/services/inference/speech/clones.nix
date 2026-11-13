# The voice-clone presets. Per preset name and per model: the reference audio
# file and the words spoken in it. A model offers the presets that have its
# key and no others. ZONOS3 clones from the audio alone, so it has no text.
pkgs: let
  inherit (pkgs) lib;
  references = import ../../../programs/tts-speak/references.nix pkgs;
  rvc = import ../../../programs/tts-speak/rvc pkgs;

  caveDataset = "https://huggingface.co/datasets/lucemans/cave-johnson/resolve/1159e788bfead6604b19f2433f6bcb3df867fa44/data/wav-44100";
  caveIntro = pkgs.fetchurl {
    url = "${caveDataset}/Cave_Johnson_fifties_intro01.wav";
    sha256 = "2c1505ec9eae5658dfbff605e4447cc7d16dcb008b03657cff1098ef2b6c6b23";
  };
  caveOutro05 = pkgs.fetchurl {
    url = "${caveDataset}/Cave_Johnson_fifties_outro05.wav";
    sha256 = "f8a00fa2029003cd522c4b53e96d4105882458ffdadc8ed83709deef85ebefd0";
  };
  caveOutro02 = pkgs.fetchurl {
    url = "${caveDataset}/Cave_Johnson_fifties_outro02.wav";
    sha256 = "ab778384c160a9b3668bb7cbd94f9582b8cf88599a2fbae925f5274af8bd87f1";
  };
  caveIntroText = "Welcome, gentlemen, to Aperture Science. Astronauts, war heroes, Olympians--you're here because we want the best, and you are it. So: Who is ready to make some science?";
  caveOutro05Text = "As founder and CEO of Aperture Science, I thank you for your participation and hope we can count on you for another round of tests.";
  caveOutro02Text = "Congratulations! The simple fact that you're standing here listening to me means you've made a glorious contribution to science.";
  caveLong = pkgs.runCommand "cave-reference.wav" {nativeBuildInputs = [pkgs.sox];} ''
    sox ${caveIntro} ${caveOutro05} ${caveOutro02} $out
  '';

  # The first two GLaDOS voicelines back to back, about ten seconds.
  gladosText = "${(builtins.elemAt references.glados.lines 0).text} ${(builtins.elemAt references.glados.lines 1).text}";

  # ada and elmo have no clean game audio, so the voice changers of tts-speak
  # render them from these words.
  adaText = "Welcome, pioneer. I am ADA, your artificial directory and assistant. Please remember that productivity is the key to a successful FICSIT career.";
  elmoText = "Hi! Elmo is so happy to see you! Elmo was just playing with Dorothy, and now Elmo wants to play with you too.";

  words = lib.mapAttrs (name: text: pkgs.writeText "${name}-reference.txt" text) {
    glados = gladosText;
    cave = caveIntroText;
    ada = adaText;
    elmo = elmoText;
  };

  # One directory of <name>.wav and <name>.txt, which tts-speak hands to the
  # speech server as a reference.
  files = pkgs.runCommand "tts-voice-references" {nativeBuildInputs = [pkgs.sox];} ''
    mkdir -p $out
    export HOME=$TMPDIR

    sox ${references.glados.audio}/0.wav ${references.glados.audio}/1.wav $out/glados.wav

    cp ${caveIntro} $out/cave.wav

    ${lib.getExe rvc.ada.stream} < ${words.ada} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/ada.wav
    ${lib.getExe rvc.elmo.stream} < ${words.elmo} \
      | sox -t raw -r ${toString rvc.rate} -e signed -b 16 -c 1 - $out/elmo.wav

    ${lib.concatStrings (lib.mapAttrsToList (name: file: "cp ${file} $out/${name}.txt\n") words)}
  '';
in {
  inherit files;

  presets = {
    glados.qwen = {
      clip = "${files}/glados.wav";
      text = gladosText;
    };

    cave = {
      fish = {
        clip = caveIntro;
        text = caveIntroText;
      };
      qwen = {
        clip = caveIntro;
        text = caveIntroText;
      };
      zonos.clip = caveIntro;
    };

    cave-long.fish = {
      clip = caveLong;
      text = "${caveIntroText} ${caveOutro05Text} ${caveOutro02Text}";
    };

    ada = {
      fish = {
        clip = "${files}/ada.wav";
        text = adaText;
      };
      qwen = {
        clip = "${files}/ada.wav";
        text = adaText;
      };
      zonos.clip = "${files}/ada.wav";
    };

    elmo.qwen = {
      clip = "${files}/elmo.wav";
      text = elmoText;
    };
  };

  # The voice names OpenAI clients send, which fish and qwen answer with the cave preset.
  openai = ["alloy" "ash" "ballad" "coral" "echo" "fable" "nova" "onyx" "sage" "shimmer" "verse"];
}
