"""Convert a neutral speech render onto the ADASatisfactory RVC voice."""

import sys

import librosa
import numpy as np
import soundfile as sf
import torch
from rvc.configs.config import Config
from rvc.infer.pipeline import Pipeline
from rvc.lib.algorithm.synthesizers import Synthesizer
from rvc.lib.utils import load_embedding

INDEX_RATE = 0.75
PROTECT = 0.5

model_path, index_path, source_path, target_path = sys.argv[1:5]

config = Config()
checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)

# The speaker count stored in the config is a training artefact. The generator
# has to be built against the speaker embedding table that actually shipped.
checkpoint["config"][-3] = checkpoint["weight"]["emb_g.weight"].shape[0]
rate = checkpoint["config"][-1]

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

source = librosa.load(source_path, sr=16000)[0].flatten()
loudest = np.abs(source).max() / 0.95
if loudest > 1:
    source /= loudest

converted = Pipeline(rate, config).pipeline(
    model=embedder,
    net_g=generator,
    sid=0,
    audio=source,
    pitch=0,
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

sf.write(target_path, converted, rate, format="WAV")
