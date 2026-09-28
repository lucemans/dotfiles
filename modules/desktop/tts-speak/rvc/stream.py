"""Speak the text lines arriving on stdin in an RVC voice, as raw 16-bit mono audio on stdout."""

import os
import sys
from types import SimpleNamespace

import faiss
import librosa
import numpy as np
import torch
from piper import PiperVoice, SynthesisConfig
from rvc.configs.config import Config
from rvc.infer import pipeline as applio
from rvc.lib.algorithm.synthesizers import Synthesizer
from rvc.lib.utils import load_embedding

INDEX_RATE = 0.75
PROTECT = 0.5
RVC_RATE = 16000

# RVC keeps the timing of the source, so the pace is set on the piper render.
PACE = 1.2
# The clauses arrive one per line, and piper ends each one without the breath
# a speaker takes at a comma or a full stop.
PAUSES = {",": 0.2, ".": 0.45, "!": 0.45, "?": 0.45}

model_path, index_path, pitch, source_path, rate = sys.argv[1:6]
rate = int(rate)

# Applio and its libraries print to stdout, which here carries the audio.
audio_out = os.fdopen(os.dup(1), "wb")
os.dup2(2, 1)

# Torch starts a thread per logical CPU, and the convolutions run at half the
# speed when SMT siblings compete, which makes a clause render slower than it
# plays.
torch.set_num_threads(max(1, os.cpu_count() // 2))

config = Config()
checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)

# The speaker count stored in the config is a training artefact. The generator
# has to be built against the speaker embedding table that actually shipped.
checkpoint["config"][-3] = checkpoint["weight"]["emb_g.weight"].shape[0]
model_rate = checkpoint["config"][-1]

generator = Synthesizer(
    *checkpoint["config"],
    use_f0=checkpoint["f0"],
    text_enc_hidden_dim=768,
    vocoder=checkpoint["vocoder"],
)
del generator.enc_q
generator.load_state_dict(checkpoint["weight"], strict=False)
generator = generator.to(config.device).float().eval()

embedder = load_embedding(checkpoint["embedder_model"])
embedder = embedder.to(config.device).float().eval()

# Pipeline.pipeline loads the pitch predictor and reads the index from disk on
# every call, which takes longer than the conversion of a short clause. Both
# are loaded once here and handed back to each call.
predictor = applio.RMVPE(device=config.device, sample_rate=RVC_RATE, hop_size=160)
applio.RMVPE = lambda **_: predictor
index = faiss.read_index(index_path)
applio.faiss = SimpleNamespace(read_index=lambda _: index)

converter = applio.Pipeline(model_rate, config)
# The pipeline pads every call with a second of reflected audio on each side,
# which is sized for whole files and triples the work on one clause. A quarter
# second is enough context for the edges.
converter.t_pad = RVC_RATE // 4
converter.t_pad2 = converter.t_pad * 2
converter.t_pad_tgt = model_rate // 4
voice = PiperVoice.load(source_path)
pace = SynthesisConfig(length_scale=voice.config.length_scale * PACE)

for line in sys.stdin:
    text = line.strip()
    if not text:
        continue

    source = np.concatenate([chunk.audio_float_array for chunk in voice.synthesize(text, pace)])
    source = librosa.resample(source, orig_sr=voice.config.sample_rate, target_sr=RVC_RATE)
    loudest = np.abs(source).max() / 0.95
    if loudest > 1:
        source /= loudest

    converted = converter.pipeline(
        model=embedder,
        net_g=generator,
        sid=0,
        audio=source,
        pitch=int(pitch),
        f0_method="rmvpe",
        file_index=index_path,
        index_rate=INDEX_RATE,
        pitch_guidance=checkpoint["f0"],
        volume_envelope=1.0,
        version=checkpoint["version"],
        protect=PROTECT,
        f0_autotune=False,
        f0_autotune_strength=1.0,
        proposed_pitch=False,
        proposed_pitch_threshold=155.0,
    )
    converted = librosa.resample(converted, orig_sr=model_rate, target_sr=rate)

    audio_out.write((np.clip(converted, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
    audio_out.write(bytes(int(PAUSES.get(text[-1], 0.0) * rate) * 2))
    audio_out.flush()
