"""Speak the text lines arriving on stdin in a piper voice, as raw 16-bit mono audio on stdout."""

import sys

from piper import PiperVoice, SynthesisConfig

# Stretch on top of the phoneme length the voice ships with.
PACE = 1.2
# The clauses arrive one per line, and piper ends each one without the breath
# a speaker takes at a comma or a full stop.
PAUSES = {",": 0.2, ".": 0.45, "!": 0.45, "?": 0.45}

voice = PiperVoice.load(sys.argv[1])
pace = SynthesisConfig(length_scale=voice.config.length_scale * PACE)
out = sys.stdout.buffer

for line in sys.stdin:
    text = line.strip()
    if not text:
        continue
    for chunk in voice.synthesize(text, pace):
        out.write(chunk.audio_int16_bytes)
        out.flush()
    out.write(bytes(int(PAUSES.get(text[-1], 0.0) * voice.config.sample_rate) * 2))
    out.flush()
