"""Speaks into the TTS microphone and holds the speech back while the far end of a call is talking."""

import argparse
import array
import fcntl
import json
import os
import selectors
import struct
import subprocess
import sys
import termios
import threading
import time
import wave

CANCEL = "\x18"

PLAY_NODE = "tts-play"
PROBE_NODE = "tts-probe"

PROBE_RATE = 16000
PROBE_FRAME = 320
SPEECH_LEVEL = 0.012 * 32768.0
SPEECH_FRAMES = 2
SILENCE_RELEASE = 0.7

FADE_SECONDS = 0.01
# How far ahead of the speakers we are allowed to run. It has to cover a stall in
# this loop, and it is also how long a pause takes to become audible.
LEAD_SECONDS = 0.05
TICK = 0.01


def ramp(data, start, end):
    samples = array.array("h", data)
    if samples:
        step = (end - start) / len(samples)
        for index in range(len(samples)):
            samples[index] = int(samples[index] * (start + step * index))
    return samples.tobytes()


def playback(rate, channels, target):
    command = [
        "pw-cat", "--playback", "--raw",
        "--format", "s16", "--rate", str(rate), "--channels", str(channels),
        "--latency", "50ms", "-P", "{ node.name = " + PLAY_NODE + " }",
    ]
    if target:
        command += ["--target", target]
    command.append("-")
    return subprocess.Popen(command, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)


class Fanout:
    """One byte stream written to several pipes, each draining at its own pace."""

    def __init__(self, targets):
        self.targets = targets
        self.pipes = [target.stdin.fileno() for target in targets]
        for pipe in self.pipes:
            os.set_blocking(pipe, False)
        self.buffer = bytearray()
        self.cursor = [0] * len(self.pipes)

    def pending(self):
        """Audio not yet played. A pipe holds 64 kB, which is most of a second, so
        what the players have not read yet has to count towards the lead as well."""
        unread = 0
        for pipe in self.pipes:
            waiting = fcntl.ioctl(pipe, termios.FIONREAD, b"\0\0\0\0")
            unread = max(unread, struct.unpack("I", waiting)[0])
        return len(self.buffer) - min(self.cursor) + unread

    def push(self, data):
        self.buffer += data

    def flush(self):
        view = memoryview(self.buffer)
        try:
            for index, pipe in enumerate(self.pipes):
                while self.cursor[index] < len(self.buffer):
                    try:
                        self.cursor[index] += os.write(pipe, view[self.cursor[index]:])
                    except BlockingIOError:
                        break
        finally:
            view.release()

        spent = min(self.cursor)
        if spent:
            del self.buffer[:spent]
            self.cursor = [value - spent for value in self.cursor]

    def close(self):
        for target in self.targets:
            target.stdin.close()
            target.wait()

    def kill(self):
        for target in self.targets:
            target.kill()


class CallProbe:
    """Hears the playback streams of applications that also capture, which is what a
    voice call looks like in the graph, and so never hears our own speech."""

    def __init__(self):
        self.proc = subprocess.Popen(
            ["pw-cat", "--record", "--raw", "--target", "0",
             "--format", "s16", "--rate", str(PROBE_RATE), "--channels", "1",
             "--latency", "20ms", "-P", "{ node.name = " + PROBE_NODE + " }", "-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        os.set_blocking(self.proc.stdout.fileno(), False)
        self.tail = bytearray()
        self.loud = 0
        self.last_speech = float("-inf")
        self.links = set()
        threading.Thread(target=self._follow, daemon=True).start()

    def quiet_for(self, now):
        return now - self.last_speech

    def feed(self, data, now):
        self.tail += data
        step = PROBE_FRAME * 2
        while len(self.tail) >= step:
            frame = array.array("h", self.tail[:step])
            del self.tail[:step]
            energy = 0
            for sample in frame:
                energy += sample * sample
            if (energy / len(frame)) ** 0.5 >= SPEECH_LEVEL:
                self.loud += 1
                if self.loud >= SPEECH_FRAMES:
                    self.last_speech = now
            else:
                self.loud = 0

    def _follow(self):
        while self.proc.poll() is None:
            try:
                self._connect()
            except (OSError, ValueError, subprocess.SubprocessError):
                pass
            time.sleep(1.0)

    def _connect(self):
        dump = json.loads(subprocess.run(["pw-dump"], capture_output=True, check=True).stdout)

        nodes = {}
        ports = []
        for item in dump:
            props = (item.get("info") or {}).get("props") or {}
            kind = item.get("type", "")
            if kind.endswith(":Node"):
                nodes[item["id"]] = props
            elif kind.endswith(":Port"):
                ports.append((item["id"], props))

        capturing = set()
        for props in nodes.values():
            if props.get("media.class") == "Stream/Input/Audio":
                capturing.add(props.get("client.id"))
        capturing.discard(None)

        calls = set()
        for node, props in nodes.items():
            if props.get("media.class") != "Stream/Output/Audio":
                continue
            if props.get("client.id") not in capturing:
                continue
            if str(props.get("node.name", "")).startswith("tts-"):
                continue
            calls.add(node)

        ear = None
        for port, props in ports:
            if props.get("port.direction") != "in":
                continue
            if nodes.get(props.get("node.id"), {}).get("node.name") == PROBE_NODE:
                ear = port
                break
        if ear is None:
            return

        for port, props in ports:
            if props.get("port.direction") != "out" or props.get("node.id") not in calls:
                continue
            if (port, ear) in self.links:
                continue
            self.links.add((port, ear))
            subprocess.run(["pw-link", str(port), str(ear)], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_clip(path):
    with wave.open(path, "rb") as clip:
        if clip.getsampwidth() != 2:
            sys.exit("tts-play expects 16 bit audio")
        return (clip.getframerate(), clip.getnchannels(),
                bytearray(clip.readframes(clip.getnframes())))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sink", required=True, help="node name of the TTS microphone sink")
    parser.add_argument("--wav", help="clip to speak")
    parser.add_argument("--model", help="piper voice to speak the lines arriving on stdin")
    parser.add_argument("--rate", type=int, help="sample rate of the piper voice")
    args = parser.parse_args()
    if bool(args.wav) == bool(args.model):
        parser.error("pass either --wav or --model")

    piper = None
    if args.wav:
        rate, channels, source = open_clip(args.wav)
        source_done = True
    else:
        rate, channels, source, source_done = args.rate, 1, bytearray(), False
        piper = subprocess.Popen(["piper", "--model", args.model, "--output-raw"],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL)
        os.set_blocking(piper.stdout.fileno(), False)

    frame = 2 * channels
    lead = int(LEAD_SECONDS * rate) * frame
    fade = int(FADE_SECONDS * rate) * frame

    probe = CallProbe()
    fan = Fanout([playback(rate, channels, args.sink), playback(rate, channels, None)])

    selector = selectors.DefaultSelector()
    selector.register(probe.proc.stdout.fileno(), selectors.EVENT_READ, "probe")
    if piper:
        os.set_blocking(sys.stdin.fileno(), False)
        selector.register(sys.stdin.fileno(), selectors.EVENT_READ, "text")
        selector.register(piper.stdout.fileno(), selectors.EVENT_READ, "audio")

    speaking = True
    held = b""
    line = ""
    stopped = False

    while True:
        for key, _ in selector.select(TICK):
            chunk = os.read(key.fd, 65536)
            if not chunk:
                selector.unregister(key.fd)
                if key.data == "audio":
                    source_done = True
                elif key.data == "text":
                    piper.stdin.close()
                continue

            if key.data == "probe":
                probe.feed(chunk, time.monotonic())
            elif key.data == "audio":
                source += chunk
            else:
                line += chunk.decode("utf-8", "ignore")
                while "\n" in line:
                    said, _, line = line.partition("\n")
                    if said == CANCEL:
                        stopped = True
                    else:
                        piper.stdin.write((said + "\n").encode())
                        piper.stdin.flush()

        if stopped:
            break

        now = time.monotonic()
        wanted = probe.quiet_for(now) >= SILENCE_RELEASE
        if wanted != speaking:
            speaking = wanted
            if speaking:
                fan.push(ramp(held, 0.0, 1.0))
                held = b""
            else:
                # Held back rather than dropped, so the pause costs no words.
                held = bytes(source[:fade])
                del source[:fade]
                fan.push(ramp(held, 1.0, 0.0))

        room = lead - fan.pending()
        room -= room % frame
        if room > 0:
            block = b""
            if speaking:
                block = bytes(source[:room])
                del source[:room]
            if not speaking or not source_done:
                block += bytes(room - len(block))
            fan.push(block)

        fan.flush()
        if speaking and source_done and not source and not fan.pending():
            break

    if stopped:
        piper.kill()
        fan.kill()
        probe.proc.kill()
        return 1

    fan.close()
    if piper:
        piper.wait()
    probe.proc.kill()
    return 0


sys.exit(main())
