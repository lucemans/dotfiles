"""Speak the text lines arriving on stdin in a cloned voice from an OpenAI-compatible speech API, as raw 16-bit mono audio on stdout."""

import argparse
import io
import json
import sys
import urllib.error
import urllib.request
import wave

# Qwen3-TTS renders at 24 kHz, and the player is started at this rate.
RATE = 24000
# The clauses arrive one per line, and each request ends without the breath a
# speaker takes at a comma or a full stop.
PAUSES = {",": 0.2, ".": 0.45, "!": 0.45, "?": 0.45}
REQUEST_SECONDS = 30.0

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--api", required=True, help="base URL of the API")
parser.add_argument("--model", required=True, help="speech model")
parser.add_argument("--token", required=True, help="file that holds the API token")
parser.add_argument("--voice", required=True, help="cloned voice the server knows by name")
args = parser.parse_args()

with open(args.token) as token:
    secret = token.read().strip()
out = sys.stdout.buffer

for line in sys.stdin:
    text = line.strip()
    if not text:
        continue

    request = urllib.request.Request(
        args.api + "/audio/speech",
        data=json.dumps({"model": args.model, "input": text, "voice": args.voice,
                         "response_format": "wav"}).encode(),
        headers={"Authorization": "Bearer " + secret, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_SECONDS) as response:
            clip = response.read()
        with wave.open(io.BytesIO(clip)) as audio:
            if (audio.getframerate(), audio.getsampwidth(), audio.getnchannels()) != (RATE, 2, 1):
                sys.exit(f"speech-stream expects {RATE} Hz 16-bit mono, got {audio.getparams()}")
            out.write(audio.readframes(audio.getnframes()))
    except (OSError, wave.Error) as error:
        # The player stays on this line until audio arrives, so a failed line
        # still yields its pause and the conversation moves on.
        reason = error.reason if isinstance(error, urllib.error.URLError) else error
        print(f"speech-stream: {reason}", file=sys.stderr)

    out.write(bytes(int(PAUSES.get(text[-1], 0.0) * RATE) * 2))
    out.flush()
