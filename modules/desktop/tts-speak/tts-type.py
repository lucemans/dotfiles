"""Keyboard entry that hands finished clauses to the synthesiser while the rest of the line is still being typed,
and asks a language model for replies to what the far end of the call just said."""

import argparse
import codecs
import json
import os
import queue
import re
import select
import sys
import termios
import threading
import time
import tty
import urllib.error
import urllib.request

CANCEL = "\x18"

# A digit in front of the mark can make it a decimal point or a thousands
# separator, so there the mark only counts once whitespace follows it.
CLAUSE_END = re.compile(r"(?<![0-9])[,.!?]+|[,.!?]+(?=\s)")

PROMPT = ("\x1b[1mSay\x1b[0m   \x1b[2mreturn speaks · alt+1-3 picks · tab completes"
          " · ctrl+d finishes · esc stops\x1b[0m")

SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
SPIN_SECONDS = 0.08

LABELS = {
    "ducked": "\x1b[33mthey are talking, speaking softer\x1b[0m",
    "paused": "\x1b[31mpaused until they finish\x1b[0m",
}

TRANSCRIPT_ROWS = 6
CONTEXT_TURNS = 20
# Typing has to rest this long before the model is asked to finish the sentence,
# and completions start no closer together than the interval, so typing does
# not turn into a stream of requests against the gateway's rate limit.
COMPLETE_PAUSE = 1.0
COMPLETE_INTERVAL = 3.0
COMPLETE_WORDS = 2
REQUEST_SECONDS = 20.0
# How long to leave the gateway alone after it refuses for the rate limit,
# when it does not say how long itself.
RATE_LIMIT_REST = 15.0
# The model reasons before it answers and that cannot be turned off on the
# gateway, so the budget has to cover a few hundred tokens of reasoning first.
ANSWER_TOKENS = 1024

# The gateway constrains the answer to these shapes while the model writes it,
# so a reply is either exactly this or an error, never a lookalike.
ANSWERS = {
    "suggest": ("replies", {"type": "array", "items": {"type": "string"}, "minItems": 3, "maxItems": 3}),
    "complete": ("words", {"type": "string"}),
}

INSTRUCTIONS = """You are voicing a character on a live voice call. The user picks or types what the character says, and a text-to-speech voice speaks it aloud.

Character: {persona}

Stay fully in character. Write only words that are spoken aloud: no stage directions, emotes, emojis, markdown or quotation marks.

This is a conversation, not a speech. Match the length of the other person: answer a quick remark with a few words, and a long story with a few sentences of your own."""

SUGGEST = """The call so far:
{transcript}

Their last turn was {words} words long, so keep each reply about that long.
Propose three different things the character could say next, each with a different angle or tone."""

COMPLETE = """The call so far:
{transcript}

The character has started saying: {pending}
Continue it with the words that finish the sentence, without repeating what was already said."""


class Player:
    """What tts-play reports over the status pipe: its playback state, and each line the far end said."""

    def __init__(self, path):
        # Non-blocking, so opening does not wait for tts-play. Until tts-play
        # opens its end, select does not report the pipe at all.
        self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        self.state = "ready"
        self.partial = b""

    def watched(self):
        return [] if self.fd is None else [self.fd]

    def update(self):
        """The lines the far end said since the last update."""
        data = os.read(self.fd, 65536)
        if not data:
            os.close(self.fd)
            self.fd = None
            self.state = "ready"
            return []

        heard = []
        *lines, self.partial = (self.partial + data).split(b"\n")
        for line in lines:
            kind, _, text = line.decode("utf-8", "ignore").partition(" ")
            if kind == "state":
                self.state = text
            elif kind == "heard":
                heard.append(text)
        return heard

    def label(self):
        if self.state == "rendering":
            return spinner() + " rendering"
        return LABELS.get(self.state, "")


class Assistant:
    """Asks the model on background threads, and makes a pipe readable whenever an answer lands."""

    def __init__(self, api, model, token, persona):
        self.api = api
        self.model = model
        self.token = token
        self.persona = persona
        self.wake, self.waker = os.pipe()
        self.answers = queue.SimpleQueue()
        self.asking = set()
        self.resting_until = 0.0
        self.error = ""
        # Kinds the rate limit refused, for the caller to ask again once rested.
        self.limited = set()

    def can_ask(self, kind):
        """One request of each kind at a time, and none while resting from the rate limit."""
        return kind not in self.asking and time.monotonic() >= self.resting_until

    def ask(self, kind, key, prompt, temperature):
        self.asking.add(kind)
        messages = [
            {"role": "system", "content": INSTRUCTIONS.format(persona=self.persona)},
            {"role": "user", "content": prompt},
        ]
        threading.Thread(target=self._ask, args=(kind, key, messages, temperature), daemon=True).start()

    def _ask(self, kind, key, messages, temperature):
        field, shape = ANSWERS[kind]
        schema = {"type": "object", "properties": {field: shape}, "required": [field],
                  "additionalProperties": False}
        try:
            with open(self.token) as token:
                secret = token.read().strip()
            request = urllib.request.Request(
                self.api + "/chat/completions",
                data=json.dumps({
                    "model": self.model, "messages": messages,
                    "temperature": temperature, "max_tokens": ANSWER_TOKENS,
                    "response_format": {"type": "json_schema",
                                        "json_schema": {"name": field, "strict": True, "schema": schema}},
                }).encode(),
                headers={"Authorization": "Bearer " + secret, "Content-Type": "application/json"})
            with urllib.request.urlopen(request, timeout=REQUEST_SECONDS) as response:
                reply = json.load(response)
            choice = reply["choices"][0]
            content = choice["message"]["content"]
            if not content:
                raise ValueError(f"empty answer, finish reason {choice.get('finish_reason')}")
            answer = json.loads(content)
            if not isinstance(answer, dict) or field not in answer:
                raise ValueError(f"answer has no {field}")
            value = answer[field]
            if kind == "suggest" and not (isinstance(value, list) and all(isinstance(item, str) for item in value)):
                raise ValueError("replies are not a list of strings")
            if kind == "complete" and not isinstance(value, str):
                raise ValueError("words are not a string")
            self.answers.put((kind, key, value, ""))
        except urllib.error.HTTPError as error:
            if error.code == 429:
                rest = float(error.headers.get("Retry-After") or RATE_LIMIT_REST)
                self.resting_until = time.monotonic() + rest
                self.limited.add(kind)
                self.answers.put((kind, key, None, f"model: rate limited, waiting {rest:.0f} s"))
            else:
                self.answers.put((kind, key, None, f"model: HTTP {error.code} {error.reason}"))
        except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
            reason = error.reason if isinstance(error, urllib.error.URLError) else error
            self.answers.put((kind, key, None, f"model: {reason}"))
        os.write(self.waker, b"x")

    def collect(self):
        os.read(self.wake, 1024)
        landed = []
        while not self.answers.empty():
            kind, key, value, error = self.answers.get()
            self.asking.discard(kind)
            self.error = error
            if not error:
                landed.append((kind, key, value))
        return landed


def spinner():
    return SPINNER[int(time.monotonic() / SPIN_SECONDS) % len(SPINNER)]


def ready_prefix(pending):
    """The longest part of the line that ends on a clause boundary."""
    end = 0
    for match in CLAUSE_END.finditer(pending):
        end = match.end()
    return pending[:end]


def clauses(text):
    start = 0
    for match in CLAUSE_END.finditer(text):
        yield text[start:match.end()]
        start = match.end()
    yield text[start:]


def continuation(pending, text):
    """The words that follow what is already typed, joined so they read on from it."""
    text = " ".join(text.split()).strip('"')
    if text.lower().startswith(pending.strip().lower()):
        text = text[len(pending.strip()):]
    text = text.strip()
    if not text or pending.endswith(" ") or text[0] in ",.!?;:'":
        return text
    return " " + text


def transcript_text(transcript):
    turns = transcript[-CONTEXT_TURNS:]
    if not turns:
        return "(nothing said yet)"
    return "\n".join(("Them: " if who == "them" else "You: ") + text for who, text in turns)


def read_events(fd, decoder):
    data = os.read(fd, 1024)
    if not data:
        return [("cancel", "")]

    text = decoder.decode(data)
    events = []
    index = 0
    while index < len(text):
        key = text[index]
        index += 1
        if key == "\x1b":
            # Alt with a key and the arrow keys arrive as one burst, a lone escape does not.
            if index < len(text) and text[index] in "123":
                events.append(("pick", text[index]))
                index += 1
            elif index < len(text):
                index = len(text)
            elif select.select([fd], [], [], 0.02)[0]:
                os.read(fd, 64)
            else:
                events.append(("cancel", ""))
        elif key in ("\r", "\n"):
            events.append(("finish", ""))
        elif key == "\x04":
            events.append(("close", ""))
        elif key == "\t":
            events.append(("complete", ""))
        elif key == "\x03":
            events.append(("cancel", ""))
        elif key in ("\x7f", "\x08"):
            events.append(("erase", ""))
        elif key == "\x17":
            events.append(("erase-word", ""))
        elif key == "\x15":
            events.append(("erase-all", ""))
        elif key >= " ":
            events.append(("type", key))
    return events


def draw(screen, player, assistant, transcript, spoken, pending, ghost, suggestions):
    status = player.label() or ("\x1b[31m" + assistant.error + "\x1b[0m" if assistant.error else "")
    out = ["\x1b[H" + PROMPT + "   " + status + "\x1b[K\r\n\x1b[K\r\n"]
    for who, text in transcript[-TRANSCRIPT_ROWS:]:
        if who == "them":
            out.append("\x1b[36mthem\x1b[0m  " + text + "\x1b[K\r\n")
        else:
            out.append("\x1b[2myou   " + text + "\x1b[0m\x1b[K\r\n")
    if transcript:
        out.append("\x1b[K\r\n")
    # The cursor goes back to the end of the typed text, in front of the ghost.
    out.append("\x1b[2m" + spoken + "\x1b[0m" + pending + "\x1b7\x1b[2;3m" + ghost + "\x1b[0m\x1b[K\r\n\x1b[K\r\n")
    for number, text in enumerate(suggestions, 1):
        out.append("\x1b[1m" + str(number) + "\x1b[0m  " + text + "\x1b[K\r\n")
    if assistant.asking:
        out.append("\x1b[2m" + spinner() + " thinking\x1b[0m\x1b[K\r\n")
    out.append("\x1b[0J\x1b8")
    screen.write("".join(out))
    screen.flush()


def converse(fd, screen, decoder, player, assistant, emit):
    """Runs until the window closes, and tells whether it closed by cancelling."""
    transcript = []
    spoken = ""
    pending = ""
    suggestions = []
    ghost = ""
    ghost_for = None
    asked_for = None
    completed_at = float("-inf")
    # Lines from the far end that arrive while suggestions are being written
    # are answered together in one request once that one returns.
    want_suggestions = False
    typed_at = 0.0

    def say(text):
        """Speaks the text and adds it to the character's current turn, which a line from the far end ends."""
        nonlocal suggestions
        for clause in clauses(text):
            emit(clause)
        text = " ".join(text.split())
        if not any(char.isalnum() for char in text):
            return
        suggestions = []
        if transcript and transcript[-1][0] == "me":
            transcript[-1] = ("me", transcript[-1][1] + " " + text)
        else:
            transcript.append(("me", text))

    while True:
        draw(screen, player, assistant, transcript, spoken, pending,
             ghost if ghost_for == pending else "", suggestions)

        now = time.monotonic()
        completable = len(pending.split()) >= COMPLETE_WORDS and asked_for != pending
        wake_at = []
        if completable:
            wake_at.append(max(typed_at + COMPLETE_PAUSE, completed_at + COMPLETE_INTERVAL, assistant.resting_until))
        if want_suggestions:
            wake_at.append(assistant.resting_until)
        due = max(0.0, min(wake_at) - now) if wake_at else None
        if player.state == "rendering" or assistant.asking:
            due = SPIN_SECONDS if due is None else min(due, SPIN_SECONDS)

        ready = select.select([fd, assistant.wake] + player.watched(), [], [], due)[0]

        if player.fd in ready:
            heard = player.update()
            for text in heard:
                transcript.append(("them", text))
            if heard:
                want_suggestions = True

        if assistant.wake in ready:
            for kind, key, value in assistant.collect():
                if kind == "suggest":
                    suggestions = value
                elif kind == "complete":
                    ghost, ghost_for = continuation(key, value), key
            if "suggest" in assistant.limited:
                want_suggestions = True
            if "complete" in assistant.limited:
                asked_for = None
            assistant.limited.clear()

        if fd in ready:
            typed_at = time.monotonic()
            for action, key in read_events(fd, decoder):
                if action == "type":
                    pending += key
                elif action == "erase":
                    pending = pending[:-1]
                elif action == "erase-word":
                    trimmed = pending.rstrip()
                    pending = trimmed[:trimmed.rfind(" ") + 1]
                elif action == "erase-all":
                    pending = ""
                elif action == "complete" and ghost_for == pending and ghost:
                    pending += ghost
                elif action == "complete":
                    asked_for = None
                    typed_at = 0.0
                elif action == "pick" and int(key) <= len(suggestions):
                    say(suggestions[int(key) - 1])
                elif action == "finish":
                    say(pending)
                    spoken = pending = ""
                elif action == "close":
                    say(pending)
                    return False
                elif action == "cancel":
                    return True

        chunk = ready_prefix(pending)
        if chunk:
            say(chunk)
            spoken += chunk
            pending = pending[len(chunk):]

        now = time.monotonic()
        if want_suggestions and assistant.can_ask("suggest"):
            want_suggestions = False
            words = 0
            for who, text in reversed(transcript):
                if who != "them":
                    break
                words += len(text.split())
            prompt = SUGGEST.format(transcript=transcript_text(transcript), words=words)
            assistant.ask("suggest", None, prompt, 0.9)

        completable = len(pending.split()) >= COMPLETE_WORDS and asked_for != pending
        rested = now >= typed_at + COMPLETE_PAUSE and now >= completed_at + COMPLETE_INTERVAL
        if completable and rested and assistant.can_ask("complete"):
            asked_for = pending
            completed_at = now
            prompt = COMPLETE.format(transcript=transcript_text(transcript), pending=spoken + pending)
            assistant.ask("complete", pending, prompt, 0.7)


def linger(screen, player):
    """Show the spinner until tts-play has spoken the rest and closed its end of the status pipe."""
    while player.fd is not None:
        screen.write("\r" + player.label() + "\x1b[K")
        screen.flush()
        timeout = SPIN_SECONDS if player.state == "rendering" else None
        if select.select(player.watched(), [], [], timeout)[0]:
            player.update()
    screen.write("\r\x1b[K")
    screen.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", required=True, help="pipe on which tts-play reports")
    parser.add_argument("--persona", required=True, help="file that describes the character the voice plays")
    parser.add_argument("--api", required=True, help="base URL of an OpenAI-compatible API")
    parser.add_argument("--model", required=True, help="model that proposes replies")
    parser.add_argument("--token", required=True, help="file that holds the API token")
    args = parser.parse_args()

    fd = sys.stdin.fileno()
    if not os.isatty(fd):
        sys.exit("tts-type needs a terminal")
    player = Player(args.status)
    with open(args.persona) as persona:
        assistant = Assistant(args.api, args.model, args.token, persona.read().strip())

    def emit(chunk):
        line = chunk.strip()
        # A mark typed after a clause that already went out, like the second
        # dot of an ellipsis, carries nothing to speak.
        if any(char.isalnum() for char in line):
            sys.stdout.write(line + "\n")
            sys.stdout.flush()

    screen = open("/dev/tty", "w")
    decoder = codecs.getincrementaldecoder("utf-8")("ignore")
    saved = termios.tcgetattr(fd)

    screen.write("\x1b[?1049h")
    screen.flush()
    # TCSANOW rather than the TCSAFLUSH that setraw defaults to, which would
    # throw away whatever was typed while the window was still opening.
    tty.setraw(fd, termios.TCSANOW)
    try:
        cancelled = converse(fd, screen, decoder, player, assistant, emit)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        screen.write("\x1b[?1049l")
        screen.flush()

    if cancelled:
        sys.stdout.write(CANCEL + "\n")
        sys.stdout.flush()
        return

    # The end of the text is what lets tts-play finish once it has spoken the rest.
    sys.stdout.close()
    linger(screen, player)


main()
