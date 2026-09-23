{
  pkgs,
  lib,
  ...
}: let
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
}
