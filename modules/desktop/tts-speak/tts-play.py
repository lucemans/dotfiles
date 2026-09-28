"""Speaks into the TTS microphone and gives way while the far end of a call is talking."""

import argparse
import array
import fcntl
import json
import math
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
SPEECH_LEVEL = 0.008 * 32768.0
SPEECH_FRAMES = 2
# Words inside one utterance of the far end are closer together than this.
UTTERANCE_GAP = 0.5
# Backchannels like "yeah" or "hmm" end before this and only lower the speech.
INTERRUPT_SECONDS = 0.5
# The far end has finished its turn once it has been quiet this long.
SILENCE_RELEASE = 0.7
PREROLL_BYTES = int(0.3 * PROBE_RATE) * 2
# A turn this long goes to the transcriber in parts, so the text keeps up.
LONGEST_BYTES = 20 * PROBE_RATE * 2

# The whole output sits this far below the level the voices render at.
LEVEL = 0.75
DUCK_GAIN = 0.2
DUCK_SECONDS = 0.08
TRAIL_SECONDS = 0.2
RESUME_SECONDS = 0.02

# After an interruption the speech picks back up at the start of the sentence
# that was talked over, like a speaker would, or at the start of its phrase
# when the sentence began further back than this.
REWIND_SECONDS = 6.0
HISTORY_SECONDS = REWIND_SECONDS + INTERRUPT_SECONDS + 1.0
PAUSE_WINDOW = 0.02
PAUSE_RATIO = 0.1
# The renderers leave 0.45 s after a sentence and 0.2 s after a comma, and a
# gap between words is shorter than either.
SENTENCE_PAUSE = 0.35
PHRASE_PAUSE = 0.15
# Silence kept in front of the restart, so it does not begin on the first syllable.
BREATH_SECONDS = 0.15

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


def trail_off(data, start):
    """Fade to nothing on a cosine curve, which falls slowly at first like a voice that is still finishing its syllable."""
    samples = array.array("h", data)
    count = len(samples)
    for index in range(count):
        samples[index] = int(samples[index] * start * (1.0 + math.cos(math.pi * index / count)) / 2.0)
    return samples.tobytes()


def rewind_point(history, onset, rate, channels):
    """Byte offset in the history where speech that the far end talked over should resume.

    That is the pause in front of the sentence that was talked over, or in
    front of its phrase when the sentence began out of reach. The end of the
    history when nothing was talked over."""
    window = int(PAUSE_WINDOW * rate) * channels
    samples = array.array("h", history)
    levels = []
    for start in range(0, len(samples) - window + 1, window):
        levels.append(sum(sample * sample for sample in samples[start:start + window]))

    quiet = max(levels, default=0) * PAUSE_RATIO ** 2
    last = min(onset // 2 // window, len(levels) - 1)
    if all(level <= quiet for level in levels[last:]):
        return len(history)

    first = max(0, last - int(REWIND_SECONDS / PAUSE_WINDOW))
    pauses = []
    index = last
    while index >= first:
        if levels[index] > quiet:
            index -= 1
            continue
        end = index + 1
        while end < len(levels) and levels[end] <= quiet:
            end += 1
        start = index
        while start > 0 and levels[start - 1] <= quiet:
            start -= 1
        pauses.append((start, end))
        index = start - 1

    breath = int(BREATH_SECONDS / PAUSE_WINDOW)
    for shortest in (SENTENCE_PAUSE, PHRASE_PAUSE):
        for start, end in pauses:
            if (end - start) * PAUSE_WINDOW >= shortest:
                return max(start, end - breath) * window * 2
    if first == 0:
        return 0
    return min(range(first, last + 1), key=levels.__getitem__) * window * 2


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
        self.onset = float("-inf")
        # Audio from just before the speech was loud enough to count, so the
        # first syllable reaches the transcriber too.
        self.recent = bytearray()
        self.utterance = None
        self.heard = []
        self.links = set()
        threading.Thread(target=self._follow, daemon=True).start()

    def quiet_for(self, now):
        return now - self.last_speech

    def talk_length(self, now):
        """How long the far end has been talking, 0 once its utterance is over."""
        if self.quiet_for(now) >= UTTERANCE_GAP:
            return 0.0
        return now - self.onset

    def feed(self, data, now):
        self.tail += data
        step = PROBE_FRAME * 2
        while len(self.tail) >= step:
            raw = bytes(self.tail[:step])
            del self.tail[:step]
            frame = array.array("h", raw)
            energy = 0
            for sample in frame:
                energy += sample * sample
            if (energy / len(frame)) ** 0.5 >= SPEECH_LEVEL:
                self.loud += 1
                if self.loud >= SPEECH_FRAMES:
                    if self.quiet_for(now) >= UTTERANCE_GAP:
                        self.onset = now
                    self.last_speech = now
                    if self.utterance is None:
                        self.utterance = bytearray(self.recent)
            else:
                self.loud = 0

            if self.utterance is None:
                self.recent += raw
                del self.recent[:-PREROLL_BYTES]
                continue
            self.utterance += raw
            if self.quiet_for(now) >= SILENCE_RELEASE:
                self.heard.append(bytes(self.utterance))
                self.utterance = None
            elif len(self.utterance) >= LONGEST_BYTES:
                self.heard.append(bytes(self.utterance))
                self.utterance = bytearray()

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
    parser.add_argument("--rate", type=int, help="sample rate of the renderer output")
    parser.add_argument("--status", help="pipe that learns the playback state and what the far end said")
    parser.add_argument("--transcriber",
                        help="command that turns length-prefixed 16 kHz utterances on stdin into text lines")
    parser.add_argument("render", nargs="*",
                        help="command that turns the text lines arriving on stdin into raw 16 bit mono audio")
    args = parser.parse_args()
    if bool(args.wav) == bool(args.render):
        parser.error("pass either --wav or a renderer")
    if args.render and not args.rate:
        parser.error("a renderer needs --rate")

    renderer = None
    if args.wav:
        rate, channels, source = open_clip(args.wav)
        source_done = True
    else:
        rate, channels, source, source_done = args.rate, 1, bytearray(), False
        renderer = subprocess.Popen(args.render, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                    stderr=subprocess.DEVNULL)
        os.set_blocking(renderer.stdout.fileno(), False)

    status = open(args.status, "w", buffering=1) if args.status else None

    def tell(kind, text):
        nonlocal status
        if status:
            try:
                status.write(kind + " " + text + "\n")
            except BrokenPipeError:
                status = None

    transcriber = None
    if args.transcriber:
        transcriber = subprocess.Popen([args.transcriber], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.DEVNULL)
        os.set_blocking(transcriber.stdout.fileno(), False)
        # Buffered like the playback, so a long turn never stalls the audio.
        ear = Fanout([transcriber])

    frame = 2 * channels
    lead = int(LEAD_SECONDS * rate) * frame
    trail = int(TRAIL_SECONDS * rate) * frame
    resume = int(RESUME_SECONDS * rate) * frame
    remembered = int(HISTORY_SECONDS * rate) * frame

    probe = CallProbe()
    fan = Fanout([playback(rate, channels, args.sink), playback(rate, channels, None)])

    selector = selectors.DefaultSelector()
    selector.register(probe.proc.stdout.fileno(), selectors.EVENT_READ, "probe")
    if renderer:
        os.set_blocking(sys.stdin.fileno(), False)
        selector.register(sys.stdin.fileno(), selectors.EVENT_READ, "text")
        selector.register(renderer.stdout.fileno(), selectors.EVENT_READ, "audio")
    if transcriber:
        selector.register(transcriber.stdout.fileno(), selectors.EVENT_READ, "heard")

    held = False
    gain = LEVEL
    # Everything played since the last interruption, so the next one can go back.
    history = bytearray()
    waiting = False
    reported = "ready"
    line = ""
    heard = ""
    stopped = False

    while True:
        for key, _ in selector.select(TICK):
            chunk = os.read(key.fd, 65536)
            if not chunk:
                selector.unregister(key.fd)
                if key.data == "audio":
                    source_done = True
                elif key.data == "text":
                    renderer.stdin.close()
                continue

            if key.data == "probe":
                probe.feed(chunk, time.monotonic())
            elif key.data == "audio":
                source += chunk
                waiting = False
            elif key.data == "heard":
                heard += chunk.decode("utf-8", "ignore")
                while "\n" in heard:
                    said, _, heard = heard.partition("\n")
                    if said:
                        tell("heard", said)
            else:
                line += chunk.decode("utf-8", "ignore")
                while "\n" in line:
                    said, _, line = line.partition("\n")
                    if said == CANCEL:
                        stopped = True
                    else:
                        renderer.stdin.write((said + "\n").encode())
                        renderer.stdin.flush()
                        waiting = True

        if stopped:
            break

        if transcriber:
            for utterance in probe.heard:
                ear.push(struct.pack("<I", len(utterance)) + utterance)
            try:
                ear.flush()
            except BrokenPipeError:
                # The speech matters more than the transcript, so it carries on without one.
                transcriber = None
        probe.heard.clear()

        now = time.monotonic()
        if not held and probe.talk_length(now) >= INTERRUPT_SECONDS:
            held = True
            cut = bytes(source[:trail])
            del source[:trail]
            fan.push(trail_off(cut, gain))
            onset = len(history) - int((now - probe.onset + LEAD_SECONDS) * rate) * frame
            history += cut
            source[:0] = history[rewind_point(history, max(0, onset), rate, channels):]
            history.clear()
        elif held and probe.quiet_for(now) >= SILENCE_RELEASE:
            held = False
            opening = bytes(source[:resume])
            del source[:resume]
            fan.push(ramp(opening, 0.0, LEVEL))
            history += opening
            gain = LEVEL

        room = lead - fan.pending()
        room -= room % frame
        if room > 0:
            block = b""
            if not held:
                block = bytes(source[:room])
                del source[:room]
            if len(block) < room and (source or not source_done):
                block += bytes(room - len(block))
            if not held:
                history += block
                del history[:-remembered]
                target = LEVEL * (DUCK_GAIN if probe.quiet_for(now) < UTTERANCE_GAP else 1.0)
                step = len(block) / frame / rate / DUCK_SECONDS * LEVEL * (1.0 - DUCK_GAIN)
                following = max(gain - step, target) if target < gain else min(gain + step, target)
                block = ramp(block, gain, following)
                gain = following
            fan.push(block)

        fan.flush()

        if held:
            state = "paused"
        elif probe.quiet_for(now) < UTTERANCE_GAP:
            state = "ducked"
        elif waiting and not source:
            state = "rendering"
        else:
            state = "ready"
        if state != reported:
            reported = state
            tell("state", state)

        if source_done and not source and not fan.pending():
            break

    if stopped:
        renderer.kill()
        fan.kill()
        probe.proc.kill()
        if transcriber:
            transcriber.kill()
        return 1

    fan.close()
    if renderer:
        renderer.wait()
    probe.proc.kill()
    if transcriber:
        transcriber.kill()
    if status:
        status.close()
    return 0


sys.exit(main())
