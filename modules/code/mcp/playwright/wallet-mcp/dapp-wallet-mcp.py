#!/usr/bin/env python3
import base64
import hashlib
import json
import socket
import struct
import subprocess
import threading
import time
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from mcp.server.fastmcp import FastMCP


BROKER_HOST = "127.0.0.1"
BROKER_PORT = 47621
MAX_MESSAGE_BYTES = 1_048_576
REQUEST_TTL_SECONDS = 120
TEST_ACCOUNT_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
TEST_ACCOUNT_PRIVATE_KEY = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
READ_ONLY_METHODS = frozenset({
    "eth_blockNumber",
    "eth_call",
    "eth_estimateGas",
    "eth_feeHistory",
    "eth_gasPrice",
    "eth_getBalance",
    "eth_getBlockByHash",
    "eth_getBlockByNumber",
    "eth_getCode",
    "eth_getLogs",
    "eth_getStorageAt",
    "eth_getTransactionByHash",
    "eth_getTransactionCount",
    "eth_getTransactionReceipt",
    "eth_maxPriorityFeePerGas",
})

mcp = FastMCP("dapp-wallet")
state_lock = threading.Lock()
connections: set["Connection"] = set()
pending_requests: dict[str, "PendingRequest"] = {}
account: str | None = None
signer_enabled = False
chain_id = 31337
rpc_url = "http://127.0.0.1:8545"


def fail(message: str) -> ValueError:
    return ValueError(message)


def json_text(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def fingerprint(payload: dict[str, Any]) -> str:
    return hashlib.sha256(json_text(payload).encode("utf-8")).hexdigest()


def hex_chain_id(value: int) -> str:
    return hex(value)


def validate_address(value: str) -> str:
    if not isinstance(value, str) or len(value) != 42 or not value.startswith("0x"):
        raise fail("Expected a 20-byte 0x-prefixed Ethereum address.")
    try:
        int(value[2:], 16)
    except ValueError as error:
        raise fail("Expected a 20-byte 0x-prefixed Ethereum address.") from error
    return value


def validate_rpc_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise fail("RPC URL must be an explicit HTTP or HTTPS URL without credentials.")
    return value


def current_state() -> dict[str, Any]:
    with state_lock:
        return {"type": "state", "account": account, "chainId": hex_chain_id(chain_id)}


def broadcast_state() -> None:
    message = current_state()
    with state_lock:
        active_connections = list(connections)
    for connection in active_connections:
        connection.send(message)


class Connection:
    def __init__(self, client: socket.socket):
        self.client = client
        self.send_lock = threading.Lock()
        self.origin = "null"

    def send(self, message: dict[str, Any]) -> None:
        payload = json_text(message).encode("utf-8")
        if len(payload) > MAX_MESSAGE_BYTES:
            return
        header = bytes([0x81])
        if len(payload) < 126:
            header += bytes([len(payload)])
        elif len(payload) <= 0xFFFF:
            header += bytes([126]) + struct.pack("!H", len(payload))
        else:
            header += bytes([127]) + struct.pack("!Q", len(payload))
        try:
            with self.send_lock:
                self.client.sendall(header + payload)
        except OSError:
            pass

    def close(self) -> None:
        with state_lock:
            connections.discard(self)
            stale = [request_id for request_id, request in pending_requests.items() if request.connection is self]
            for request_id in stale:
                pending_requests.pop(request_id, None)
        try:
            self.client.close()
        except OSError:
            pass


@dataclass
class PendingRequest:
    request_id: str
    connection: Connection
    origin: str
    method: str
    params: list[Any]
    created_at: float

    def payload(self) -> dict[str, Any]:
        return {"origin": self.origin, "method": self.method, "params": self.params}


def receive_exact(client: socket.socket, count: int) -> bytes:
    payload = b""
    while len(payload) < count:
        chunk = client.recv(count - len(payload))
        if not chunk:
            raise ConnectionError("WebSocket connection closed.")
        payload += chunk
    return payload


def receive_frame(client: socket.socket) -> tuple[int, bytes]:
    first, second = receive_exact(client, 2)
    opcode = first & 0x0F
    masked = second & 0x80
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", receive_exact(client, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", receive_exact(client, 8))[0]
    if length > MAX_MESSAGE_BYTES:
        raise ValueError("WebSocket message exceeds 1 MiB.")
    if not masked:
        raise ValueError("Client WebSocket frames must be masked.")
    key = receive_exact(client, 4)
    payload = receive_exact(client, length)
    return opcode, bytes(byte ^ key[index % 4] for index, byte in enumerate(payload))


def websocket_handshake(client: socket.socket) -> None:
    request = b""
    while b"\r\n\r\n" not in request:
        request += client.recv(4096)
        if len(request) > 16_384:
            raise ValueError("WebSocket handshake is too large.")
    headers = request.decode("ascii", errors="replace").split("\r\n")
    values = {}
    for header in headers[1:]:
        if ":" in header:
            name, value = header.split(":", maxsplit=1)
            values[name.lower()] = value.strip()
    key = values.get("sec-websocket-key")
    if not key or values.get("upgrade", "").lower() != "websocket":
        raise ValueError("Invalid WebSocket handshake.")
    accept = base64.b64encode(hashlib.sha1(f"{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11".encode()).digest()).decode()
    client.sendall(
        b"HTTP/1.1 101 Switching Protocols\r\n"
        b"Upgrade: websocket\r\n"
        b"Connection: Upgrade\r\n"
        + f"Sec-WebSocket-Accept: {accept}\r\n\r\n".encode()
    )


def rpc(method: str, params: list[Any]) -> Any:
    with state_lock:
        endpoint = rpc_url
    body = json_text({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode("utf-8")
    request = Request(endpoint, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urlopen(request, timeout=20) as response:
            payload = response.read(MAX_MESSAGE_BYTES + 1)
    except OSError as error:
        raise fail(f"RPC request failed: {error}") from error
    if len(payload) > MAX_MESSAGE_BYTES:
        raise fail("RPC response exceeds 1 MiB.")
    try:
        response = json.loads(payload)
    except json.JSONDecodeError as error:
        raise fail("RPC returned invalid JSON.") from error
    if not isinstance(response, dict):
        raise fail("RPC response must be an object.")
    if isinstance(response.get("error"), dict):
        error = response["error"]
        raise fail(f"RPC {method} failed ({error.get('code', 'unknown')}): {error.get('message', 'Unknown error')}")
    if "result" not in response:
        raise fail(f"RPC {method} returned neither result nor error.")
    return response["result"]


def respond(request: PendingRequest, result: Any = None, error: dict[str, Any] | None = None) -> None:
    message: dict[str, Any] = {"type": "response", "id": request.request_id}
    if error is not None:
        message["error"] = error
    else:
        message["result"] = result
    request.connection.send(message)


def queue_request(connection: Connection, message: dict[str, Any]) -> None:
    request_id = message.get("id")
    method = message.get("method")
    params = message.get("params", [])
    origin = message.get("origin")
    if not isinstance(request_id, str) or not isinstance(method, str) or not isinstance(params, list) or not isinstance(origin, str):
        raise ValueError("Invalid wallet request.")
    if method == "eth_chainId":
        respond(PendingRequest(request_id, connection, origin, method, params, time.monotonic()), hex_chain_id(chain_id))
        return
    if method == "eth_accounts":
        respond(PendingRequest(request_id, connection, origin, method, params, time.monotonic()), [account] if account else [])
        return
    if method in READ_ONLY_METHODS:
        try:
            result = rpc(method, params)
        except ValueError as error:
            respond(PendingRequest(request_id, connection, origin, method, params, time.monotonic()), error={"code": -32603, "message": str(error)})
        else:
            respond(PendingRequest(request_id, connection, origin, method, params, time.monotonic()), result)
        return
    request = PendingRequest(request_id, connection, origin, method, params, time.monotonic())
    with state_lock:
        pending_requests[request_id] = request


def handle_connection(client: socket.socket) -> None:
    connection = Connection(client)
    try:
        websocket_handshake(client)
        with state_lock:
            connections.add(connection)
        connection.send(current_state())
        while True:
            opcode, payload = receive_frame(client)
            if opcode == 0x8:
                return
            if opcode == 0x9:
                client.sendall(b"\x8A" + bytes([len(payload)]) + payload)
                continue
            if opcode != 0x1:
                continue
            message = json.loads(payload)
            if message.get("type") == "register":
                origin = message.get("origin")
                if isinstance(origin, str):
                    connection.origin = origin
                connection.send(current_state())
            elif message.get("type") == "request":
                queue_request(connection, message)
    except (ConnectionError, OSError, ValueError, json.JSONDecodeError):
        pass
    finally:
        connection.close()


def serve_broker() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((BROKER_HOST, BROKER_PORT))
        listener.listen()
        while True:
            client, _ = listener.accept()
            threading.Thread(target=handle_connection, args=(client,), daemon=True).start()


def remove_expired_requests() -> None:
    now = time.monotonic()
    expired: list[PendingRequest] = []
    with state_lock:
        for request_id, request in list(pending_requests.items()):
            if now - request.created_at > REQUEST_TTL_SECONDS:
                expired.append(request)
                pending_requests.pop(request_id, None)
    for request in expired:
        respond(request, error={"code": 4001, "message": "Wallet request expired without approval."})


def pending(request_id: str, approval_fingerprint: str) -> PendingRequest:
    remove_expired_requests()
    with state_lock:
        request = pending_requests.get(request_id)
    if request is None:
        raise fail("Unknown, expired, or already resolved wallet request.")
    if fingerprint(request.payload()) != approval_fingerprint:
        raise fail("Approval fingerprint does not match the pending wallet request.")
    return request


def sign_personal_message(params: list[Any]) -> str:
    if len(params) != 2 or not all(isinstance(value, str) for value in params):
        raise fail("personal_sign requires a message and account address.")
    message, requested_account = params
    if requested_account.lower() != (account or "").lower():
        raise fail("personal_sign requested an account other than the selected account.")
    result = subprocess.run(
        ["cast", "wallet", "sign", "--private-key", TEST_ACCOUNT_PRIVATE_KEY, message],
        check=False,
        capture_output=True,
        text=True,
        timeout=20,
    )
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or "Cast failed to sign the message.").strip()[:2_000])
    return result.stdout.strip()


def send_transaction(params: list[Any]) -> str:
    if len(params) != 1 or not isinstance(params[0], dict):
        raise fail("eth_sendTransaction requires exactly one transaction object.")
    transaction = params[0]
    recipient = transaction.get("to")
    if not isinstance(recipient, str):
        raise fail("This basic wallet requires a transaction recipient.")
    validate_address(recipient)
    sender = transaction.get("from")
    if sender is not None and (not isinstance(sender, str) or sender.lower() != (account or "").lower()):
        raise fail("Transaction sender does not match the selected account.")
    command = ["cast", "send", "--rpc-url", rpc_url, "--private-key", TEST_ACCOUNT_PRIVATE_KEY, recipient]
    if isinstance(transaction.get("value"), str):
        command.extend(["--value", transaction["value"]])
    data = transaction.get("data", transaction.get("input"))
    if isinstance(data, str):
        command.extend(["--data", data])
    result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or "Cast failed to submit the transaction.").strip()[:2_000])
    for line in result.stdout.splitlines():
        if line.startswith("transactionHash"):
            return line.split(maxsplit=1)[-1]
    return result.stdout.strip()


@mcp.tool()
def wallet_status() -> dict[str, Any]:
    """Return the active Dapp QA Wallet account, signer state, RPC endpoint, and pending-request count."""
    remove_expired_requests()
    with state_lock:
        return {
            "account": account,
            "chainId": chain_id,
            "rpcUrl": rpc_url,
            "signerEnabled": signer_enabled,
            "pendingRequestCount": len(pending_requests),
        }


@mcp.tool()
def wallet_set_mock_account(address: str) -> dict[str, Any]:
    """Impersonate a public address without a private key. Mock accounts can never sign messages or submit transactions; use this for read-only wallet QA."""
    global account, signer_enabled
    with state_lock:
        account = validate_address(address)
        signer_enabled = False
    broadcast_state()
    return wallet_status()


@mcp.tool()
def wallet_use_test_account(account_index: int = 0) -> dict[str, Any]:
    """Select account zero from the built-in Anvil test mnemonic. It is test-only and is the only account that can sign in this basic implementation."""
    global account, signer_enabled
    if account_index != 0:
        raise fail("This basic implementation currently supports only test account index 0.")
    with state_lock:
        account = TEST_ACCOUNT_ADDRESS
        signer_enabled = True
    broadcast_state()
    return wallet_status()


@mcp.tool()
def wallet_set_rpc(new_chain_id: int, new_rpc_url: str) -> dict[str, Any]:
    """Set the active chain and explicit HTTP(S) RPC endpoint. All signing and transaction requests still require individual approval."""
    global chain_id, rpc_url
    if new_chain_id < 1:
        raise fail("Chain ID must be positive.")
    with state_lock:
        chain_id = new_chain_id
        rpc_url = validate_rpc_url(new_rpc_url)
    broadcast_state()
    return wallet_status()


@mcp.tool()
def wallet_pending() -> list[dict[str, Any]]:
    """Inspect every request awaiting an explicit decision. Call this before wallet_approve and use its fingerprint unchanged."""
    remove_expired_requests()
    with state_lock:
        requests = list(pending_requests.values())
    return [
        {
            "requestId": request.request_id,
            "fingerprint": fingerprint(request.payload()),
            "origin": request.origin,
            "method": request.method,
            "params": request.params,
            "ageSeconds": round(time.monotonic() - request.created_at, 1),
        }
        for request in requests
    ]


@mcp.tool()
def wallet_approve(request_id: str, approval_fingerprint: str) -> dict[str, Any]:
    """Approve one inspected request. Signing or transaction submission occurs only for this exact request and fingerprint."""
    request = pending(request_id, approval_fingerprint)
    try:
        if request.method == "eth_requestAccounts":
            result = [account] if account else []
        elif request.method == "personal_sign":
            if not signer_enabled:
                raise fail("The selected account is mock-only and can never sign.")
            result = sign_personal_message(request.params)
        elif request.method == "eth_sendTransaction":
            if not signer_enabled:
                raise fail("The selected account is mock-only and can never submit transactions.")
            result = send_transaction(request.params)
        else:
            raise fail(f"{request.method} is not implemented by the basic wallet. Deny it or extend the wallet implementation.")
    except ValueError as error:
        respond(request, error={"code": 4200, "message": str(error)})
        with state_lock:
            pending_requests.pop(request_id, None)
        raise
    respond(request, result=result)
    with state_lock:
        pending_requests.pop(request_id, None)
    return {"requestId": request_id, "approved": True, "result": result}


@mcp.tool()
def wallet_deny(request_id: str, approval_fingerprint: str) -> dict[str, bool]:
    """Reject one inspected request with EIP-1193 user-rejected error 4001."""
    request = pending(request_id, approval_fingerprint)
    respond(request, error={"code": 4001, "message": "User rejected the wallet request."})
    with state_lock:
        pending_requests.pop(request_id, None)
    return {"denied": True}


if __name__ == "__main__":
    threading.Thread(target=serve_broker, daemon=True).start()
    mcp.run(transport="stdio")
