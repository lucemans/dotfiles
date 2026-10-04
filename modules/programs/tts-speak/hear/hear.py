"""Transcribe utterances arriving on stdin, each a 4-byte little-endian length and 16 kHz mono 16-bit audio, into one line of text each."""

import struct
import sys

import numpy as np
from faster_whisper import WhisperModel

# The voice renderer keeps the other half of the cores while the far end talks
# over it.
THREADS = 8

model = WhisperModel(sys.argv[1], device="cpu", compute_type="int8", cpu_threads=THREADS)
source = sys.stdin.buffer

while True:
    header = source.read(4)
    if len(header) < 4:
        break
    pcm = source.read(struct.unpack("<I", header)[0])
    audio = np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0

    # Whisper invents a "Thank you." for a burst of noise, and the VAD filter
    # drops those bursts before the decoder sees them.
    segments, _ = model.transcribe(audio, language="en", beam_size=1, vad_filter=True,
                                   condition_on_previous_text=False, without_timestamps=True)
    text = " ".join(segment.text.strip() for segment in segments)
    sys.stdout.write(" ".join(text.split()) + "\n")
    sys.stdout.flush()
