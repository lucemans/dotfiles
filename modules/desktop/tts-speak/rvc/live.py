"""Speak through an RVC voice: the microphone goes in, and the converted voice goes out to the TTS microphone."""

import fcntl
import os
import select
import struct
import subprocess
import sys
import termios
import tty
import types

import numpy as np
import torch

# Applio's realtime core imports pedalboard for post-processing effects that
# stay disabled here, and nixpkgs does not package it.
effects = types.ModuleType("pedalboard")
for name in ["Pedalboard", "Chorus", "Distortion", "Reverb", "PitchShift", "Limiter",
             "Gain", "Bitcrush", "Clipping", "Compressor", "Delay"]:
    setattr(effects, name, None)
sys.modules["pedalboard"] = effects

from rvc.realtime.core import AUDIO_SAMPLE_RATE, VoiceChanger  # noqa: E402

# A block is the unit the model converts, so it sets most of the delay. On
# the CPU a quarter second converts in under 0.1 s, which leaves room for a
# TTS renderer running at the same time.
BLOCK_SECONDS = 0.25
CROSSFADE_SECONDS = 0.05
CONTEXT_SECONDS = 0.5
SILENT_DB = -50
INDEX_RATE = 0.75
PROTECT = 0.5

# Named like the rest of the TTS streams, so the call probe in tts-play does
# not take this recorder and player for a voice call and duck the speech.
MIC_NODE = "tts-rvc-mic"
VOICE_NODE = "tts-rvc-voice"
MONITOR_NODE = "tts-rvc-monitor"

model_path, index_path, pitch, sink = sys.argv[1:5]
pitch = int(pitch)

torch.set_num_threads(max(1, os.cpu_count() // 2))

block = int(BLOCK_SECONDS * AUDIO_SAMPLE_RATE)
block_bytes = block * 4

screen = open("/dev/tty", "w")
screen.write("loading the voice...\r\n")
screen.flush()

embedder = torch.load(model_path, map_location="cpu", weights_only=True).get("embedder_model", "contentvec")
changer = VoiceChanger(block, CROSSFADE_SECONDS, CONTEXT_SECONDS, model_path=model_path, index_path=index_path,
                       f0_method="rmvpe", embedder_model=embedder, silent_threshold=SILENT_DB)

stream = ["--raw", "--format", "f32", "--rate", str(AUDIO_SAMPLE_RATE), "--channels", "1", "--latency", "20ms"]
mic = subprocess.Popen(["pw-cat", "--record", *stream, "-P", "{ node.name = " + MIC_NODE + " }", "-"],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)


def player(node, target=None):
    command = ["pw-cat", "--playback", *stream, "-P", "{ node.name = " + node + " }"]
    if target:
        command += ["--target", target]
    return subprocess.Popen([*command, "-"], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)


voice = player(VOICE_NODE, sink)
# Plays the converted voice on the default output as well, so it can be heard
# while speaking. Off at the start, because hearing yourself late makes it
# hard to keep talking.
monitor = None


def backlog():
    waiting = fcntl.ioctl(mic.stdout.fileno(), termios.FIONREAD, b"\0\0\0\0")
    return struct.unpack("I", waiting)[0]


def take(size):
    """Exactly size bytes from the microphone, or fewer once it has stopped."""
    data = b""
    while len(data) < size:
        chunk = os.read(mic.stdout.fileno(), size - len(data))
        if not chunk:
            break
        data += chunk
    return data


keys = sys.stdin.fileno()
saved = termios.tcgetattr(keys)
tty.setcbreak(keys, termios.TCSANOW)
dropped = 0
try:
    while True:
        # A block that takes longer to convert than to speak would push every
        # later block further behind, so the oldest audio goes instead.
        behind = backlog() - block_bytes
        if behind > 0:
            take(behind - behind % 4)
            dropped += 1

        data = take(block_bytes)
        if len(data) < block_bytes:
            break
        audio = np.frombuffer(data, dtype=np.float32)
        converted, level, timings = changer.on_request(audio, f0_up_key=pitch, index_rate=INDEX_RATE, protect=PROTECT)
        converted = converted.astype(np.float32).tobytes()
        voice.stdin.write(converted)
        voice.stdin.flush()
        if monitor:
            monitor.stdin.write(converted)
            monitor.stdin.flush()

        if select.select([keys], [], [], 0)[0]:
            for key in os.read(keys, 32).decode("utf-8", "ignore"):
                if key in "+=":
                    pitch += 1
                elif key == "-":
                    pitch -= 1
                elif key == "m" and monitor:
                    monitor.kill()
                    monitor = None
                elif key == "m":
                    monitor = player(MONITOR_NODE)
                elif key in "q\x1b":
                    raise KeyboardInterrupt

        bar = "#" * min(20, int(level * 200))
        screen.write(f"\r\x1b[Kpitch {pitch:+d} (+/-)   monitor {'on ' if monitor else 'off'} (m)   q stops   "
                     f"level {bar:<20}   convert {timings[1]:4.0f} ms of {BLOCK_SECONDS * 1000:.0f}   dropped {dropped}")
        screen.flush()
except KeyboardInterrupt:
    pass
finally:
    termios.tcsetattr(keys, termios.TCSADRAIN, saved)
    mic.kill()
    voice.kill()
    if monitor:
        monitor.kill()
