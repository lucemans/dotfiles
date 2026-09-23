"""Keyboard entry that hands finished words to the synthesiser while the rest of the line is still being typed."""

import codecs
import os
import re
import select
import sys
import termios
import time
import tty

CANCEL = "\x18"

# The first chunk is short so speech starts while the sentence is still being
# written. Later chunks are longer because the audio already in flight buys the
# time that a phrase-sized chunk needs to carry its own intonation.
FIRST_WORDS = 4
NEXT_WORDS = 10
PAUSE_WORDS = 2
PAUSE_SECONDS = 0.6

# A digit in front of the stop makes it a decimal number, not a sentence end.
SENTENCE_END = re.compile(r'(?<![0-9])[.!?]+["\')\]]*\s')

PROMPT = "\x1b[1mSay\x1b[0m   \x1b[2mreturn speaks the rest, escape stops\x1b[0m"


def ready_prefix(pending, started, stalled):
    """The longest part of the line that can be spoken without losing a word that is still being typed."""
    finished, space, _ = pending.rpartition(" ")
    if not space:
        return ""
    finished += " "

    end = 0
    for match in SENTENCE_END.finditer(finished):
        end = match.end()
    if end:
        return finished[:end]

    words = len(finished.split())
    if words >= (NEXT_WORDS if started else FIRST_WORDS):
        return finished
    if stalled and words >= PAUSE_WORDS:
        return finished
    return ""


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
            # Arrow keys and friends arrive as one burst, a lone escape does not.
            if index < len(text):
                index = len(text)
            elif select.select([fd], [], [], 0.02)[0]:
                os.read(fd, 64)
            else:
                events.append(("cancel", ""))
        elif key in ("\r", "\n", "\x04"):
            events.append(("finish", ""))
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


def draw(screen, spoken, pending):
    screen.write("\x1b[H" + PROMPT + "\r\n\r\n\x1b[2m" + spoken + "\x1b[0m" + pending + "\x1b[0J")
    screen.flush()


def converse(fd, screen, decoder, emit):
    spoken = ""
    pending = ""
    started = False
    waited = False
    deadline = 0.0

    while True:
        draw(screen, spoken, pending)

        timeout = None
        if pending and not waited:
            timeout = max(0.0, deadline - time.monotonic())
        stalled = not select.select([fd], [], [], timeout)[0]

        if stalled:
            waited = True
        else:
            waited = False
            deadline = time.monotonic() + PAUSE_SECONDS
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
                elif action == "finish":
                    emit(pending)
                    return spoken + pending, False
                elif action == "cancel":
                    return spoken, True

        chunk = ready_prefix(pending, started, stalled)
        if chunk:
            emit(chunk)
            spoken += chunk
            pending = pending[len(chunk):]
            started = True


def main():
    fd = sys.stdin.fileno()
    if not os.isatty(fd):
        sys.exit("tts-type needs a terminal")

    def emit(chunk):
        line = chunk.strip()
        if line:
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
        spoken, cancelled = converse(fd, screen, decoder, emit)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        screen.write("\x1b[?1049l")
        screen.flush()

    if cancelled:
        sys.stdout.write(CANCEL + "\n")
        sys.stdout.flush()
    else:
        screen.write(spoken.strip() + "\n")
        screen.flush()


main()
