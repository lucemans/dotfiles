"""Audacity Multi-Voice Chorus followed by Delay, on 16-bit mono WAV."""

import io
import sys
import wave

import numpy as np

# Plug-in control values from the recipe. The arithmetic that turns them into
# seconds, hertz and gain is the arithmetic in MultiVoiceChorus.ny and delay.ny.
CHORUS_SPEED = 1.90
CHORUS_DEPTH = 2.90
CHORUS_MIX = 3.40
ECHO_LEVEL_DB = -18.70
ECHO_PITCH_SEMITONES = -0.120
ECHO_COUNT = 2


def chorus(signal, rate):
    """One sine-swept delay tap mixed back in, which is Voices=1."""
    depth = 1.0e-5 * CHORUS_DEPTH**3.0
    speed = 5.0e-3 * CHORUS_SPEED**3.0

    frames = np.arange(signal.size)
    swept = depth * (1.0 + np.sin(2.0 * np.pi * speed * frames / rate)) * rate
    read = frames - swept

    floor = np.floor(read)
    index = floor.astype(np.int64)
    fraction = read - floor

    def tap(step):
        taken = index + step
        inside = (taken >= 0) & (taken < signal.size)
        return np.where(inside, signal[np.clip(taken, 0, signal.size - 1)], 0.0)

    wet = tap(0) * (1.0 - fraction) + tap(1) * fraction

    # The wet tap is a delayed copy, so this sum can never exceed the input
    # peak and the plug-in's output limiter has nothing to do.
    return (CHORUS_MIX * wet + signal) / (1.0 + CHORUS_MIX)


def change_speed(signal, ratio):
    """Pitch/Tempo shift, which is resampling, so duration scales by 1/ratio."""
    length = int(round(signal.size / ratio))
    return np.interp(
        np.arange(length) * ratio,
        np.arange(signal.size),
        signal,
        left=0.0,
        right=0.0,
    )


def delay(signal):
    """Regular delay at a delay time of zero: the echoes stack on the dry signal."""
    echoes = []
    for echo in range(1, ECHO_COUNT + 1):
        level = 10.0 ** (echo * ECHO_LEVEL_DB / 20.0)
        ratio = 2.0 ** (echo * ECHO_PITCH_SEMITONES / 12.0)
        echoes.append(level * change_speed(signal, ratio))

    mixed = np.zeros(max(part.size for part in [signal, *echoes]))
    for part in [signal, *echoes]:
        mixed[: part.size] += part
    return mixed


with wave.open(io.BytesIO(sys.stdin.buffer.read()), "rb") as source:
    if source.getsampwidth() != 2 or source.getnchannels() != 1:
        raise SystemExit("ada-effects expects 16-bit mono audio")
    rate = source.getframerate()
    frames = source.readframes(source.getnframes())

signal = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0
audio = delay(chorus(signal, rate))

# The echoes add up to 1.13 of the dry peak, and the render arrives near full
# scale, so the 16-bit conversion would clip without this.
peak = np.max(np.abs(audio))
if peak > 1.0:
    audio /= peak

sink = io.BytesIO()
with wave.open(sink, "wb") as target:
    target.setnchannels(1)
    target.setsampwidth(2)
    target.setframerate(rate)
    target.writeframes(np.round(audio * 32767.0).astype("<i2").tobytes())

sys.stdout.buffer.write(sink.getvalue())
