"""Start `nemo-speech serve` on a loopback port and exercise HTTP, boosting and the realtime socket.

usage: test_server.py <nemo-speech> <model.gguf> <speech.wav>

The WAV has to be 16 kHz mono PCM16 and say "ask not what your country can do
for you". Audio goes to the realtime socket as fast as the server takes it, so
the assertions do not depend on timing.
"""

import json
import subprocess
import sys
import time
import urllib.request
import uuid
import wave

from websockets.sync.client import connect

BINARY, MODEL, WAV = sys.argv[1:4]
PORT = 18010
PHRASE = "country can do for you"
DELTA = "conversation.item.input_audio_transcription.delta"
COMPLETED = "conversation.item.input_audio_transcription.completed"

server = subprocess.Popen(
    [
        BINARY,
        "serve",
        "--asr-model",
        MODEL,
        "--host",
        "127.0.0.1",
        "--port",
        str(PORT),
        "--no-ui",
        "--gpu",
        "-1",
    ],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
)


def fail(message):
    server.terminate()
    output = server.communicate(timeout=30)[0]
    sys.exit(f"{message}\n--- server output ---\n{output}")


def wait_ready(limit=900):
    # The server binds its port after loading and warming up the model.
    deadline = time.monotonic() + limit
    while time.monotonic() < deadline:
        if server.poll() is not None:
            fail("server exited before /ready")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/ready", timeout=5) as response:
                if response.status == 200 and json.load(response)["ready"]:
                    return
        except OSError:
            pass
        time.sleep(0.5)
    fail("server was not ready in time")


def transcribe(**fields):
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    with open(WAV, "rb") as handle:
        body += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="speech.wav"\r\n'
            "Content-Type: audio/wav\r\n\r\n"
        ).encode() + handle.read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    request = urllib.request.Request(
        f"http://127.0.0.1:{PORT}/v1/audio/transcriptions",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.load(response)["text"]


def realtime(contexts):
    with wave.open(WAV, "rb") as handle:
        assert (handle.getframerate(), handle.getnchannels(), handle.getsampwidth()) == (16000, 1, 2)
        pcm = handle.readframes(handle.getnframes())

    events = []
    with connect(f"ws://127.0.0.1:{PORT}/v1/audio/transcriptions/realtime", max_size=None, ping_interval=None) as ws:
        events.append(json.loads(ws.recv(timeout=60)))
        assert events[0]["type"] == "session.created", events[0]
        ws.send(
            json.dumps(
                {
                    "type": "session.update",
                    "session": {"sample_rate": 16000, "speech_contexts": contexts},
                }
            )
        )
        events.append(json.loads(ws.recv(timeout=60)))
        assert events[1]["type"] == "session.updated", events[1]

        step = 3200  # 100 ms
        for offset in range(0, len(pcm), step):
            ws.send(pcm[offset : offset + step])
        ws.send(json.dumps({"type": "input_audio_buffer.commit"}))

        deadline = time.monotonic() + 600
        while not any(event["type"] == COMPLETED for event in events):
            event = json.loads(ws.recv(timeout=max(1, deadline - time.monotonic())))
            assert event["type"] != "error", event
            events.append(event)
    return events


wait_ready()

try:
    plain = transcribe()
    assert PHRASE in plain.lower(), f"HTTP transcript: {plain!r}"

    # An unknown phrase must be accepted and must not break recognition.
    boosted = transcribe(speech_contexts=json.dumps([{"phrases": ["Kowalczyk"], "boost": 2.5}]))
    assert PHRASE in boosted.lower(), f"boosted HTTP transcript: {boosted!r}"

    events = realtime([{"phrases": ["Kowalczyk"], "boost": 2.5}])
    deltas = [event for event in events if event["type"] == DELTA and event["delta"]]
    completed = [event for event in events if event["type"] == COMPLETED]
    assert deltas, f"no delta event with text: {events}"
    assert completed, f"no completed event: {events}"
    assert PHRASE in completed[-1]["transcript"].lower(), f"realtime transcript: {completed[-1]['transcript']!r}"
    assert PHRASE in "".join(event["delta"] for event in deltas).lower(), "deltas do not carry the phrase"
except BaseException as error:
    fail(f"{type(error).__name__}: {error}")

server.terminate()
output = server.communicate(timeout=60)[0]
# A GGUF without the embedded tokenizer accepts speech_contexts and logs this
# line instead of boosting.
assert "boosting disabled" not in output, f"word boosting is inactive\n{output}"
print("ok:", plain)
