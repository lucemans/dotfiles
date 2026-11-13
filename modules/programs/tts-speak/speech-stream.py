"""Speak the text lines arriving on stdin in a cloned voice from an OpenAI-compatible speech API, as raw 16-bit mono audio on stdout."""

import argparse
import base64
import io
import json
import sys
import urllib.error
import urllib.request
import wave

# The clauses arrive one per line, and each request ends without the breath a
# speaker takes at a comma or a full stop.
PAUSES = {",": 0.2, ".": 0.45, "!": 0.45, "?": 0.45}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--api", required=True, help="base URL of the API")
parser.add_argument("--model", required=True, help="speech model")
parser.add_argument("--token", required=True, help="file that holds the API token")
parser.add_argument("--rate", type=int, default=24000, help="sample rate the model renders at, which the player is started with")
parser.add_argument("--timeout", type=float, default=30.0, help="seconds to wait for one clause")
voice = parser.add_mutually_exclusive_group(required=True)
voice.add_argument("--voice", help="cloned voice the server knows by name")
voice.add_argument("--reference", help="clip to clone the voice from, as <name>.wav next to <name>.txt with the words spoken in it")
args = parser.parse_args()

with open(args.token) as token:
    secret = token.read().strip()
out = sys.stdout.buffer

if args.voice:
    speaker = {"voice": args.voice}
else:
    with open(args.reference, "rb") as clip, open(args.reference.removesuffix(".wav") + ".txt") as words:
        speaker = {"voice_ref": {"type": "base64", "data": base64.b64encode(clip.read()).decode()},
                   "reference_text": words.read().strip()}

for line in sys.stdin:
    text = line.strip()
    if not text:
        continue

    request = urllib.request.Request(
        args.api + "/audio/speech",
        data=json.dumps({"model": args.model, "input": text, "response_format": "wav"} | speaker).encode(),
        headers={"Authorization": "Bearer " + secret, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            clip = response.read()
        with wave.open(io.BytesIO(clip)) as audio:
            if (audio.getframerate(), audio.getsampwidth(), audio.getnchannels()) != (args.rate, 2, 1):
                sys.exit(f"speech-stream expects {args.rate} Hz 16-bit mono, got {audio.getparams()}")
            out.write(audio.readframes(audio.getnframes()))
    except (OSError, wave.Error) as error:
        # The player stays on this line until audio arrives, so a failed line
        # still yields its pause and the conversation moves on.
        reason = error.reason if isinstance(error, urllib.error.URLError) else error
        print(f"speech-stream: {reason}", file=sys.stderr)

    out.write(bytes(int(PAUSES.get(text[-1], 0.0) * args.rate) * 2))
    out.flush()
