#!/usr/bin/env python3
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path
from urllib.parse import urlparse

from mcp.server.fastmcp import FastMCP


SERVER_ROOT = Path("/workspace/repositories")
ALLOWED_HOSTS = frozenset({"github.com", "gitlab.com"})
MAX_FILE_SIZE_BYTES = 1_048_576
MAX_LISTED_FILES = 1_000
MAX_SEARCH_RESULTS = 100
REVISION_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/@-]{0,255}")
checkouts: dict[str, Path] = {}
mcp = FastMCP("repo-reader")


def fail(message: str) -> ValueError:
    return ValueError(message)


def run_git(*arguments: str, cwd: Path | None = None) -> None:
    result = subprocess.run(
        ["git", "-c", "protocol.file.allow=never", "-c", "protocol.ext.allow=never", *arguments],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "Git failed without an error message."
        raise fail(detail[:2_000])


def validate_repository_url(repository: str) -> str:
    parsed = urlparse(repository)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise fail("Repository must be an HTTPS URL hosted on github.com or gitlab.com.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise fail("Repository URL must not include credentials, a query, or a fragment.")
    if not parsed.path.endswith(".git"):
        raise fail("Repository URL must end in .git.")
    return repository


def validate_revision(revision: str) -> str:
    if not REVISION_PATTERN.fullmatch(revision) or revision.startswith("-") or revision.endswith("/"):
        raise fail("Revision must be a branch, tag, or commit identifier.")
    return revision


def checkout_path(repository_id: str) -> Path:
    path = checkouts.get(repository_id)
    if path is None:
        raise fail("Unknown repository ID. Check out the repository first.")
    return path


def resolve_path(repository: Path, relative_path: str) -> Path:
    candidate = (repository / relative_path).resolve(strict=True)
    try:
        candidate.relative_to(repository.resolve())
    except ValueError as error:
        raise fail("Path must stay within the checked-out repository.") from error
    return candidate


def source_files(repository: Path, relative_path: str) -> list[Path]:
    root = resolve_path(repository, relative_path)
    if root.is_file():
        return [root]
    if not root.is_dir():
        raise fail("Path must identify a file or directory.")

    files = [path for path in root.rglob("*") if path.is_file() and ".git" not in path.parts]
    return files[:MAX_LISTED_FILES]


@mcp.tool()
def checkout_repository(repository: str, revision: str = "HEAD") -> dict[str, str]:
    """Fetch a public HTTPS repository at a branch, tag, or commit without running its code."""
    repository = validate_repository_url(repository)
    revision = validate_revision(revision)
    repository_id = uuid.uuid4().hex
    destination = SERVER_ROOT / repository_id
    destination.parent.mkdir(parents=True, exist_ok=True)

    try:
        run_git("init", "--quiet", str(destination))
        run_git("remote", "add", "origin", repository, cwd=destination)
        run_git("fetch", "--quiet", "--no-tags", "--depth=1", "--filter=blob:limit=1048576", "origin", revision, cwd=destination)
        run_git("checkout", "--quiet", "--detach", "--no-recurse-submodules", "FETCH_HEAD", cwd=destination)
    except Exception:
        shutil.rmtree(destination, ignore_errors=True)
        raise

    checkouts[repository_id] = destination
    return {"repository_id": repository_id, "revision": revision}


@mcp.tool()
def list_files(repository_id: str, path: str = ".") -> list[str]:
    """List up to 1,000 readable files below a repository-relative path."""
    repository = checkout_path(repository_id)
    return [str(file_path.relative_to(repository)) for file_path in source_files(repository, path)]


@mcp.tool()
def read_file(repository_id: str, path: str) -> str:
    """Read one UTF-8 text file no larger than 1 MiB from a checked-out repository."""
    repository = checkout_path(repository_id)
    file_path = resolve_path(repository, path)
    if not file_path.is_file() or ".git" in file_path.parts:
        raise fail("Path must identify a repository file.")
    if file_path.stat().st_size > MAX_FILE_SIZE_BYTES:
        raise fail("File exceeds the 1 MiB read limit.")
    try:
        return file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        raise fail("File is not UTF-8 text.") from error


@mcp.tool()
def search_files(repository_id: str, query: str, path: str = ".") -> list[dict[str, object]]:
    """Search UTF-8 source files for literal text and return at most 100 matching lines."""
    if not query:
        raise fail("Search query must not be empty.")

    repository = checkout_path(repository_id)
    matches: list[dict[str, object]] = []
    for file_path in source_files(repository, path):
        if file_path.stat().st_size > MAX_FILE_SIZE_BYTES:
            continue
        try:
            lines = file_path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for line_number, line in enumerate(lines, start=1):
            if query in line:
                matches.append({"path": str(file_path.relative_to(repository)), "line": line_number, "text": line})
                if len(matches) == MAX_SEARCH_RESULTS:
                    return matches
    return matches


if __name__ == "__main__":
    mcp.run(transport="stdio")
