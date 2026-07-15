#!/usr/bin/env python3
import atexit
import json
import os
import re
import socket
import subprocess
import time
import uuid
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from mcp.server.fastmcp import FastMCP


ADDRESS_PATTERN = re.compile(r"0x[0-9a-fA-F]{40}")
HASH_PATTERN = re.compile(r"0x[0-9a-fA-F]{64}")
HEX_DATA_PATTERN = re.compile(r"0x(?:[0-9a-fA-F]{2})*")
HEX_QUANTITY_PATTERN = re.compile(r"0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)")
ENS_NAME_PATTERN = re.compile(r"(?:[a-zA-Z0-9-]+\.)+eth")
BLOCK_TAGS = frozenset({"latest", "earliest", "pending", "safe", "finalized"})
MAX_RESPONSE_BYTES = 1_048_576
MAX_BLOCKSCOUT_RECORDS = 100
MAX_LOG_BLOCK_RANGE = 10_000
REQUEST_TIMEOUT_SECONDS = 20
DOCUMENTATION_CACHE_TTL_SECONDS = 3_600

mcp = FastMCP("eth-data")


@dataclass(frozen=True)
class Network:
    rpc_url: str
    blockscout_url: str


@dataclass
class Fork:
    network: str
    block_number: int | None
    port: int
    process: subprocess.Popen[bytes]


forks: dict[str, Fork] = {}
documentation_cache: dict[str, tuple[float, str]] = {}


def fail(message: str) -> ValueError:
    return ValueError(message)


def load_networks() -> dict[str, Network]:
    try:
        values = json.loads(os.environ["ETH_DATA_NETWORKS"])
    except KeyError as error:
        raise RuntimeError("ETH_DATA_NETWORKS is not configured.") from error
    except json.JSONDecodeError as error:
        raise RuntimeError("ETH_DATA_NETWORKS must contain JSON.") from error

    networks: dict[str, Network] = {}
    if not isinstance(values, dict):
        raise RuntimeError("ETH_DATA_NETWORKS must map names to endpoints.")
    for name, endpoints in values.items():
        if not isinstance(name, str) or not isinstance(endpoints, dict):
            raise RuntimeError("Invalid network configuration.")
        rpc_url = endpoints.get("rpcUrl")
        blockscout_url = endpoints.get("blockscoutUrl")
        if not isinstance(rpc_url, str) or not rpc_url.startswith("https://"):
            raise RuntimeError(f"Network {name} must have an HTTPS RPC URL.")
        if not isinstance(blockscout_url, str) or not blockscout_url.startswith("https://"):
            raise RuntimeError(f"Network {name} must have an HTTPS Blockscout URL.")
        networks[name] = Network(rpc_url=rpc_url, blockscout_url=blockscout_url.rstrip("/"))
    return networks


NETWORKS = load_networks()


def network(name: str) -> Network:
    configured_network = NETWORKS.get(name)
    if configured_network is None:
        raise fail(f"Unknown network {name!r}. Choose one of: {', '.join(sorted(NETWORKS))}.")
    return configured_network


def require_address(address: str) -> str:
    if not ADDRESS_PATTERN.fullmatch(address):
        raise fail("Expected a 20-byte 0x-prefixed Ethereum address.")
    return address


def resolve_name(network_name: str, name: str) -> str:
    if not ENS_NAME_PATTERN.fullmatch(name):
        raise fail("Expected an Ethereum address or .eth ENS name.")
    result = subprocess.run(
        ["cast", "resolve-name", name, "--rpc-url", network(network_name).rpc_url],
        check=False,
        capture_output=True,
        text=True,
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or "ENS resolution failed.")[:2_000])
    return require_address(result.stdout.strip())


def address_or_name(network_name: str, value: str) -> str:
    if ADDRESS_PATTERN.fullmatch(value):
        return value
    return resolve_name(network_name, value)


def require_hash(value: str, label: str) -> str:
    if not HASH_PATTERN.fullmatch(value):
        raise fail(f"Expected {label} to be a 32-byte 0x-prefixed hash.")
    return value


def require_hex_data(value: str, label: str = "data") -> str:
    if not HEX_DATA_PATTERN.fullmatch(value):
        raise fail(f"Expected {label} to be even-length 0x-prefixed hex data.")
    return value


def quantity(value: str | int, label: str) -> str:
    if isinstance(value, bool):
        raise fail(f"Expected {label} to be a non-negative quantity.")
    if isinstance(value, int):
        if value < 0:
            raise fail(f"Expected {label} to be a non-negative quantity.")
        return hex(value)
    if not isinstance(value, str):
        raise fail(f"Expected {label} to be a quantity.")
    if value.isdecimal():
        return hex(int(value))
    if HEX_QUANTITY_PATTERN.fullmatch(value):
        return hex(int(value, 16))
    raise fail(f"Expected {label} to be decimal or 0x-prefixed hexadecimal.")


def block_identifier(value: str | int) -> str:
    if isinstance(value, str) and value in BLOCK_TAGS:
        return value
    return quantity(value, "block")


def read_response(response: Any) -> bytes:
    content_length = response.headers.get("Content-Length")
    if content_length is not None and int(content_length) > MAX_RESPONSE_BYTES:
        raise fail("Upstream response exceeds the 1 MiB limit.")
    payload = response.read(MAX_RESPONSE_BYTES + 1)
    if len(payload) > MAX_RESPONSE_BYTES:
        raise fail("Upstream response exceeds the 1 MiB limit.")
    return payload


def request_json(url: str, body: dict[str, Any] | None = None) -> Any:
    headers = {"Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    request = Request(url, data=data, headers=headers, method="POST" if data is not None else "GET")
    try:
        with urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            payload = read_response(response)
    except HTTPError as error:
        detail = error.read(2_000).decode("utf-8", errors="replace")
        raise fail(f"Upstream request failed with HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise fail(f"Upstream request failed: {error.reason}") from error
    except TimeoutError as error:
        raise fail("Upstream request timed out.") from error
    try:
        return json.loads(payload)
    except json.JSONDecodeError as error:
        raise fail("Upstream returned invalid JSON.") from error


def request_text(url: str) -> str:
    cached = documentation_cache.get(url)
    if cached is not None and time.monotonic() - cached[0] < DOCUMENTATION_CACHE_TTL_SECONDS:
        return cached[1]
    request = Request(url, headers={"Accept": "text/plain, text/html;q=0.9"})
    try:
        with urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            text = read_response(response).decode("utf-8", errors="replace")
    except HTTPError as error:
        raise fail(f"Documentation request failed with HTTP {error.code}.") from error
    except URLError as error:
        raise fail(f"Documentation request failed: {error.reason}") from error
    except TimeoutError as error:
        raise fail("Documentation request timed out.") from error
    documentation_cache[url] = (time.monotonic(), text)
    return text


def rpc(url: str, method: str, parameters: list[Any]) -> Any:
    response = request_json(
        url,
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": parameters},
    )
    if not isinstance(response, dict):
        raise fail("RPC response must be an object.")
    error = response.get("error")
    if isinstance(error, dict):
        code = error.get("code", "unknown")
        message = error.get("message", "Unknown RPC error")
        raise fail(f"RPC {method} failed ({code}): {message}")
    if "result" not in response:
        raise fail(f"RPC {method} returned neither result nor error.")
    return response["result"]


def cast_rpc(url: str, method: str, parameters: list[Any]) -> Any:
    command = ["cast", "rpc", method, *(json.dumps(parameter, separators=(",", ":")) for parameter in parameters), "--rpc-url", url]
    try:
        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=REQUEST_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as error:
        raise fail(f"Cast RPC {method} timed out.") from error
    output_size = len(result.stdout.encode("utf-8")) + len(result.stderr.encode("utf-8"))
    if output_size > MAX_RESPONSE_BYTES:
        raise fail("Cast RPC response exceeds the 1 MiB limit.")
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or f"Cast RPC {method} failed.")[:2_000])
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return result.stdout.strip()


def public_rpc(network_name: str, method: str, parameters: list[Any]) -> Any:
    return cast_rpc(network(network_name).rpc_url, method, parameters)


def fork(fork_id: str) -> Fork:
    instance = forks.get(fork_id)
    if instance is None:
        raise fail("Unknown or expired fork ID.")
    if instance.process.poll() is not None:
        forks.pop(fork_id, None)
        raise fail("The Anvil process for this fork has exited.")
    return instance


def fork_rpc(fork_id: str, method: str, parameters: list[Any]) -> Any:
    instance = fork(fork_id)
    return rpc(f"http://127.0.0.1:{instance.port}", method, parameters)


def transaction_request(to: str, data: str, from_address: str | None, value: str | None) -> dict[str, str]:
    request = {"to": require_address(to), "data": require_hex_data(data)}
    if from_address is not None:
        request["from"] = require_address(from_address)
    if value is not None:
        request["value"] = quantity(value, "value")
    return request


def allocate_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def stop_fork(instance: Fork) -> None:
    if instance.process.poll() is None:
        instance.process.terminate()
        try:
            instance.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            instance.process.kill()
            instance.process.wait(timeout=5)


def stop_all_forks() -> None:
    for instance in list(forks.values()):
        stop_fork(instance)
    forks.clear()


atexit.register(stop_all_forks)


@mcp.resource("eth-data://wallet-page")
def wallet_page() -> str:
    """Wallet.page reference material for Ethereum wallet integrations."""
    return request_text("https://wallet.page/")


@mcp.resource("eth-data://eips")
def ethereum_improvement_proposals() -> str:
    """The official Ethereum Improvement Proposal index."""
    return request_text("https://eips.ethereum.org/")


@mcp.resource("eth-data://foundry-docs")
def foundry_docs() -> str:
    """Foundry's LLM-oriented documentation."""
    return request_text("https://getfoundry.sh/llms-full.txt")


@mcp.tool()
def network_status(network_name: str) -> dict[str, Any]:
    """Return chain identity, client version, gas price, and latest block for a configured network."""
    network(network_name)
    return {
        "network": network_name,
        "chainId": public_rpc(network_name, "eth_chainId", []),
        "clientVersion": public_rpc(network_name, "web3_clientVersion", []),
        "gasPrice": public_rpc(network_name, "eth_gasPrice", []),
        "latestBlock": public_rpc(network_name, "eth_blockNumber", []),
    }


@mcp.tool()
def get_block(network_name: str, block: str | int = "latest", include_transactions: bool = False) -> Any:
    """Read a block by configured-network block number, tag, or 32-byte hash."""
    if isinstance(block, str) and HASH_PATTERN.fullmatch(block):
        return public_rpc(network_name, "eth_getBlockByHash", [block, include_transactions])
    return public_rpc(network_name, "eth_getBlockByNumber", [block_identifier(block), include_transactions])


@mcp.tool()
def get_transaction(network_name: str, transaction_hash: str) -> Any:
    """Read a transaction by hash from a configured network."""
    return public_rpc(network_name, "eth_getTransactionByHash", [require_hash(transaction_hash, "transaction hash")])


@mcp.tool()
def get_receipt(network_name: str, transaction_hash: str) -> Any:
    """Read a transaction receipt by hash from a configured network."""
    return public_rpc(network_name, "eth_getTransactionReceipt", [require_hash(transaction_hash, "transaction hash")])


@mcp.tool()
def resolve_ens_name(network_name: str, name: str) -> str:
    """Resolve a .eth ENS name to an address through a configured network."""
    return resolve_name(network_name, name)


@mcp.tool()
def get_balance(network_name: str, address_or_ens_name: str, block: str | int = "latest") -> Any:
    """Read an address or .eth ENS name balance from a configured network."""
    return public_rpc(network_name, "eth_getBalance", [address_or_name(network_name, address_or_ens_name), block_identifier(block)])


@mcp.tool()
def get_nonce(network_name: str, address: str, block: str | int = "latest") -> Any:
    """Read an address transaction count from a configured network."""
    return public_rpc(network_name, "eth_getTransactionCount", [require_address(address), block_identifier(block)])


@mcp.tool()
def get_code(network_name: str, address: str, block: str | int = "latest") -> Any:
    """Read deployed bytecode from a configured network."""
    return public_rpc(network_name, "eth_getCode", [require_address(address), block_identifier(block)])


@mcp.tool()
def get_storage(network_name: str, address: str, slot: str | int, block: str | int = "latest") -> Any:
    """Read one contract storage slot from a configured network."""
    return public_rpc(network_name, "eth_getStorageAt", [require_address(address), quantity(slot, "slot"), block_identifier(block)])


@mcp.tool()
def call(network_name: str, to: str, data: str = "0x", from_address: str | None = None, value: str | None = None, block: str | int = "latest") -> Any:
    """Execute a read-only eth_call against a configured network."""
    return public_rpc(network_name, "eth_call", [transaction_request(to, data, from_address, value), block_identifier(block)])


@mcp.tool()
def estimate_gas(network_name: str, to: str, data: str = "0x", from_address: str | None = None, value: str | None = None) -> Any:
    """Estimate gas without broadcasting a transaction on a configured network."""
    return public_rpc(network_name, "eth_estimateGas", [transaction_request(to, data, from_address, value)])


@mcp.tool()
def get_logs(network_name: str, from_block: int, to_block: int, address: str | None = None, topics: list[str | None] | None = None) -> Any:
    """Read logs from a bounded block range on a configured network."""
    if from_block < 0 or to_block < from_block or to_block - from_block > MAX_LOG_BLOCK_RANGE:
        raise fail(f"Log ranges must be between zero and {MAX_LOG_BLOCK_RANGE} blocks.")
    filter_value: dict[str, Any] = {"fromBlock": hex(from_block), "toBlock": hex(to_block)}
    if address is not None:
        filter_value["address"] = require_address(address)
    if topics is not None:
        if len(topics) > 4:
            raise fail("At most four log topics are supported.")
        filter_value["topics"] = [None if topic is None else require_hash(topic, "topic") for topic in topics]
    return public_rpc(network_name, "eth_getLogs", [filter_value])


@mcp.tool()
def encode_calldata(signature: str, arguments: list[str] | None = None) -> str:
    """Encode a Solidity function signature and arguments with the local Cast binary."""
    if not signature or len(signature) > 1_000:
        raise fail("Function signature must be between one and 1,000 characters.")
    result = subprocess.run(["cast", "calldata", signature, *(arguments or [])], check=False, capture_output=True, text=True, timeout=REQUEST_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or "Cast calldata failed.")[:2_000])
    return require_hex_data(result.stdout.strip(), "encoded calldata")


@mcp.tool()
def decode_abi(signature: str, data: str, input_data: bool = False) -> str:
    """Decode ABI data with the local Cast binary."""
    if not signature or len(signature) > 1_000:
        raise fail("ABI signature must be between one and 1,000 characters.")
    arguments = ["cast", "abi-decode"]
    if input_data:
        arguments.append("--input")
    arguments.extend([signature, require_hex_data(data)])
    result = subprocess.run(arguments, check=False, capture_output=True, text=True, timeout=REQUEST_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise fail((result.stderr or result.stdout or "Cast ABI decode failed.")[:2_000])
    return result.stdout.strip()


@mcp.tool()
def fork_create(network_name: str, block_number: int | None = None) -> dict[str, Any]:
    """Start an isolated Anvil fork of a configured network in the server sandbox."""
    configured_network = network(network_name)
    if block_number is not None and block_number < 0:
        raise fail("Fork block number must be non-negative.")
    port = allocate_port()
    command = ["anvil", "--host", "127.0.0.1", "--port", str(port), "--fork-url", configured_network.rpc_url]
    if block_number is not None:
        command.extend(["--fork-block-number", str(block_number)])
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    fork_id = uuid.uuid4().hex
    instance = Fork(network=network_name, block_number=block_number, port=port, process=process)
    for _ in range(30):
        if process.poll() is not None:
            break
        try:
            chain_id = rpc(f"http://127.0.0.1:{port}", "eth_chainId", [])
            forks[fork_id] = instance
            return {"forkId": fork_id, "network": network_name, "blockNumber": block_number, "chainId": chain_id}
        except ValueError:
            time.sleep(0.1)
    stop_fork(instance)
    raise fail("Anvil did not start a fork successfully.")


@mcp.tool()
def fork_status(fork_id: str) -> dict[str, Any]:
    """Return the current status and head block of an isolated Anvil fork."""
    instance = fork(fork_id)
    return {"forkId": fork_id, "network": instance.network, "forkBlockNumber": instance.block_number, "blockNumber": fork_rpc(fork_id, "eth_blockNumber", []), "chainId": fork_rpc(fork_id, "eth_chainId", [])}


@mcp.tool()
def fork_close(fork_id: str) -> None:
    """Stop and remove an isolated Anvil fork."""
    instance = fork(fork_id)
    stop_fork(instance)
    forks.pop(fork_id, None)


@mcp.tool()
def fork_get_accounts(fork_id: str) -> Any:
    """List Anvil-funded development accounts for an isolated fork."""
    return fork_rpc(fork_id, "eth_accounts", [])


@mcp.tool()
def fork_get_balance(fork_id: str, address: str) -> Any:
    """Read an address balance from an isolated fork."""
    return fork_rpc(fork_id, "eth_getBalance", [require_address(address), "latest"])


@mcp.tool()
def fork_call(fork_id: str, to: str, data: str = "0x", from_address: str | None = None, value: str | None = None) -> Any:
    """Execute a read-only eth_call against an isolated fork."""
    return fork_rpc(fork_id, "eth_call", [transaction_request(to, data, from_address, value), "latest"])


@mcp.tool()
def fork_mine(fork_id: str, blocks: int = 1, interval_seconds: int | None = None) -> None:
    """Mine blocks only in an isolated fork."""
    if blocks < 1:
        raise fail("Blocks must be positive.")
    parameters = [hex(blocks)]
    if interval_seconds is not None:
        if interval_seconds < 1:
            raise fail("Interval must be positive.")
        parameters.append(hex(interval_seconds))
    fork_rpc(fork_id, "anvil_mine", parameters)


@mcp.tool()
def fork_set_balance(fork_id: str, address: str, balance: str | int) -> None:
    """Set an address balance only in an isolated fork."""
    fork_rpc(fork_id, "anvil_setBalance", [require_address(address), quantity(balance, "balance")])


@mcp.tool()
def fork_set_code(fork_id: str, address: str, code: str) -> None:
    """Set contract bytecode only in an isolated fork."""
    fork_rpc(fork_id, "anvil_setCode", [require_address(address), require_hex_data(code, "code")])


@mcp.tool()
def fork_set_storage(fork_id: str, address: str, slot: str | int, value: str) -> None:
    """Set a storage slot only in an isolated fork."""
    fork_rpc(fork_id, "anvil_setStorageAt", [require_address(address), quantity(slot, "slot"), require_hex_data(value, "storage value")])


@mcp.tool()
def fork_impersonate_account(fork_id: str, address: str) -> None:
    """Enable account impersonation only in an isolated fork."""
    fork_rpc(fork_id, "anvil_impersonateAccount", [require_address(address)])


@mcp.tool()
def fork_stop_impersonating_account(fork_id: str, address: str) -> None:
    """Stop account impersonation only in an isolated fork."""
    fork_rpc(fork_id, "anvil_stopImpersonatingAccount", [require_address(address)])


@mcp.tool()
def fork_snapshot(fork_id: str) -> Any:
    """Create a state snapshot in an isolated fork."""
    return fork_rpc(fork_id, "evm_snapshot", [])


@mcp.tool()
def fork_revert(fork_id: str, snapshot_id: str) -> Any:
    """Revert an isolated fork to a prior snapshot."""
    return fork_rpc(fork_id, "evm_revert", [quantity(snapshot_id, "snapshot ID")])


@mcp.tool()
def fork_set_next_block_timestamp(fork_id: str, timestamp: int) -> None:
    """Set the next block timestamp only in an isolated fork."""
    if timestamp < 1:
        raise fail("Timestamp must be positive.")
    fork_rpc(fork_id, "evm_setNextBlockTimestamp", [timestamp])


@mcp.tool()
def fork_increase_time(fork_id: str, seconds: int) -> None:
    """Increase time only in an isolated fork."""
    if seconds < 1:
        raise fail("Seconds must be positive.")
    fork_rpc(fork_id, "evm_increaseTime", [seconds])


@mcp.tool()
def fork_set_automine(fork_id: str, enabled: bool) -> None:
    """Toggle automining only in an isolated fork."""
    fork_rpc(fork_id, "evm_setAutomine", [enabled])


@mcp.tool()
def fork_reset(fork_id: str, block_number: int | None = None) -> None:
    """Reset an isolated fork to its configured network and optional block."""
    instance = fork(fork_id)
    if block_number is not None and block_number < 0:
        raise fail("Fork block number must be non-negative.")
    configuration: dict[str, Any] = {"forking": {"jsonRpcUrl": network(instance.network).rpc_url}}
    if block_number is not None:
        configuration["forking"]["blockNumber"] = block_number
    fork_rpc(fork_id, "anvil_reset", [configuration])


def blockscout(network_name: str, path: str, query: dict[str, str] | None = None) -> Any:
    configured_network = network(network_name)
    suffix = f"?{urlencode(query)}" if query else ""
    return request_json(f"{configured_network.blockscout_url}{path}{suffix}")


def blockscout_page_size(page_size: int) -> int:
    if not 1 <= page_size <= MAX_BLOCKSCOUT_RECORDS:
        raise fail(f"Page size must be between one and {MAX_BLOCKSCOUT_RECORDS}.")
    return page_size


@mcp.tool()
def get_address_overview(network_name: str, address: str) -> Any:
    """Get Blockscout discovery metadata for an address on a configured network."""
    return blockscout(network_name, f"/addresses/{require_address(address)}")


@mcp.tool()
def list_address_transactions(network_name: str, address: str, page_size: int = 50, cursor: str | None = None) -> Any:
    """List a bounded page of Blockscout address transactions for discovery."""
    query = {"items_count": str(blockscout_page_size(page_size))}
    if cursor is not None:
        if len(cursor) > 1_000:
            raise fail("Blockscout cursor exceeds 1,000 characters.")
        query["cursor"] = cursor
    return blockscout(network_name, f"/addresses/{require_address(address)}/transactions", query)


@mcp.tool()
def list_address_token_balances(network_name: str, address: str, page_size: int = 50, cursor: str | None = None) -> Any:
    """List a bounded page of Blockscout-discovered token balances for an address."""
    query = {"items_count": str(blockscout_page_size(page_size))}
    if cursor is not None:
        if len(cursor) > 1_000:
            raise fail("Blockscout cursor exceeds 1,000 characters.")
        query["cursor"] = cursor
    return blockscout(network_name, f"/addresses/{require_address(address)}/token-balances", query)


if __name__ == "__main__":
    mcp.run(transport="stdio")
