"""Expose herdr agent state reporting to a sandboxed agent.

The herdr API socket also launches panes and sends them keystrokes, and those
panes run on the host outside the sandbox. Binding it into the sandbox would
therefore hand the agent host execution, so the sandbox gets this relay
instead: one pinned pane id and the lifecycle methods the OMP extension needs.
"""
import json
import os
import socket
import sys
import threading
import time

ALLOWED = frozenset(
    (
        "ping",
        "pane.report_agent",
        "pane.report_agent_session",
        "pane.release_agent",
        "pane.report_metadata",
        "pane.rename",
    )
)

PANE_PARAM = "pane_id"


def log(message):
    sys.stderr.write("herdr-relay: " + message + "\n")
    sys.stderr.flush()


def refuse(request_id, method):
    log("refused " + repr(method))
    return json.dumps(
        {
            "id": request_id if isinstance(request_id, str) else "",
            "error": {
                "code": "forbidden",
                "message": "the agent sandbox only forwards herdr agent state reports",
            },
        }
    ).encode() + b"\n"


def rewrite(line, pane_id):
    """Returns the line to forward upstream, or an error line for the client."""
    try:
        request = json.loads(line)
    except ValueError:
        return None, refuse("", "<invalid json>")

    if not isinstance(request, dict):
        return None, refuse("", "<not an object>")

    request_id = request.get("id")
    method = request.get("method")
    if method not in ALLOWED:
        return None, refuse(request_id, method)

    if method != "ping":
        params = request.get("params")
        if not isinstance(params, dict):
            params = {}
        params[PANE_PARAM] = pane_id
        request["params"] = params

    return json.dumps(request).encode() + b"\n", None


def pump(source, sink):
    try:
        while True:
            chunk = source.recv(65536)
            if not chunk:
                break
            sink.sendall(chunk)
    except OSError:
        pass
    finally:
        for end in (source, sink):
            try:
                end.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def serve(client, upstream_path, pane_id):
    upstream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        upstream.connect(upstream_path)
    except OSError as error:
        log("upstream unreachable: " + str(error))
        client.close()
        return

    threading.Thread(target=pump, args=(upstream, client), daemon=True).start()

    with client.makefile("rb") as lines:
        try:
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                forward, error = rewrite(line, pane_id)
                if error is not None:
                    client.sendall(error)
                    continue
                upstream.sendall(forward)
        except OSError:
            pass

    for end in (upstream, client):
        try:
            end.close()
        except OSError:
            pass


def watch_parent():
    parent = os.getppid()
    while os.getppid() == parent:
        time.sleep(2)
    os._exit(0)


def main():
    if len(sys.argv) != 4:
        log("usage: herdr-relay <upstream-socket> <listen-socket> <pane-id>")
        return 2

    upstream_path, listen_path, pane_id = sys.argv[1:]

    try:
        os.unlink(listen_path)
    except FileNotFoundError:
        pass

    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(listen_path)
    os.chmod(listen_path, 0o600)
    listener.listen(8)

    threading.Thread(target=watch_parent, daemon=True).start()

    try:
        while True:
            client, _ = listener.accept()
            threading.Thread(
                target=serve,
                args=(client, upstream_path, pane_id),
                daemon=True,
            ).start()
    finally:
        listener.close()
        try:
            os.unlink(listen_path)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    sys.exit(main())
