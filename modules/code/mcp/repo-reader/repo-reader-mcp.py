#!/usr/bin/env python3
import os
import json
import re
import shutil
import subprocess
import uuid
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

from mcp.server.fastmcp import FastMCP


SERVER_ROOT = Path("/workspace/repositories")
ALLOWED_HOSTS = frozenset({"github.com", "gitlab.com", "git.voidarc.co.uk"})
MAX_FILE_SIZE_BYTES = 1_048_576
MAX_LISTED_FILES = 1_000
MAX_SEARCH_RESULTS = 100
MAX_BATCH_FILES = 25
MAX_BATCH_SIZE_BYTES = 4 * MAX_FILE_SIZE_BYTES
MAX_LIST_DEPTH = 32
REVISION_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/@-]{0,255}")
checkouts: dict[str, Path] = {}
mcp = FastMCP("repo-reader")


def fail(message: str) -> ValueError:
    return ValueError(message)


def run_git(*arguments: str, cwd: Path | None = None, success_codes: tuple[int, ...] = (0,)) -> str:
    result = subprocess.run(
        ["git", "-c", "protocol.file.allow=never", "-c", "protocol.ext.allow=never", *arguments],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode not in success_codes:
        detail = result.stderr.strip() or result.stdout.strip() or "Git failed without an error message."
        raise fail(detail[:2_000])
    return result.stdout


def normalized_path(segments: list[str]) -> str:
    if not segments or any(segment in {"", ".", ".."} for segment in segments):
        raise fail("Repository URL must identify a repository path.")
    return "/".join(quote(segment, safe="-._~") for segment in segments)


def validate_repository_url(repository: str) -> tuple[str, str | None]:
    parsed = urlparse(repository)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise fail("Repository must be an HTTPS URL hosted on an allowed Git host.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise fail("Repository URL must not include credentials, a query, or a fragment.")

    segments = [unquote(segment) for segment in parsed.path.split("/") if segment]
    if parsed.path.endswith(".git"):
        return repository, None

    if parsed.hostname == "gitlab.com" and "-" in segments:
        separator = segments.index("-")
        repository_segments = segments[:separator]
        tail = segments[separator + 1 :]
        revision = tail[1] if len(tail) >= 2 and tail[0] in {"tree", "blob"} else None
    elif parsed.hostname == "git.voidarc.co.uk" and "src" in segments:
        separator = segments.index("src")
        repository_segments = segments[:separator]
        tail = segments[separator + 1 :]
        revision = tail[1] if len(tail) >= 2 and tail[0] in {"branch", "commit"} else None
    elif parsed.hostname == "github.com" and "tree" in segments:
        separator = segments.index("tree")
        repository_segments = segments[:separator]
        tail = segments[separator + 1 :]
        revision = tail[0] if tail else None
    elif parsed.hostname == "github.com" and "blob" in segments:
        separator = segments.index("blob")
        repository_segments = segments[:separator]
        tail = segments[separator + 1 :]
        revision = tail[0] if tail else None
    else:
        repository_segments = segments
        revision = None

    if revision is not None:
        revision = validate_revision(revision)
    return f"https://{parsed.netloc}/{normalized_path(repository_segments)}.git", revision


def validate_revision(revision: str) -> str:
    if not REVISION_PATTERN.fullmatch(revision) or revision.startswith("-") or revision.endswith("/"):
        raise fail("Revision must be a branch, tag, or commit identifier.")
    return revision


def checkout_path(repository_id: str) -> Path:
    path = checkouts.get(repository_id)
    if path is None:
        raise fail("Unknown repository ID. Check out the repository first.")
    return path


def checkout_id(repository: str, revision: str) -> str:
    parsed = urlparse(repository)
    name = "-".join([parsed.hostname or "repository", *parsed.path.removesuffix(".git").split("/") , revision]).lower()
    slug = re.sub(r"[^a-z0-9]+", "-", name).strip("-")[:96]
    return f"{slug}-{uuid.uuid4().hex[:8]}"


def resolve_path(repository: Path, relative_path: str) -> Path:
    candidate = (repository / relative_path).resolve(strict=True)
    try:
        candidate.relative_to(repository.resolve())
    except ValueError as error:
        raise fail("Path must stay within the checked-out repository.") from error
    return candidate


def revision_path(relative_path: str) -> Path:
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts or ".git" in candidate.parts:
        raise fail("Path must stay within the checked-out repository.")
    return candidate


def source_files(repository: Path, relative_path: str, max_depth: int | None = None, include: str | None = None) -> list[Path]:
    root = resolve_path(repository, relative_path)
    if root.is_file():
        return [root]
    if not root.is_dir():
        raise fail("Path must identify a file or directory.")

    root_depth = len(root.relative_to(repository).parts)
    files = [
        file_path
        for file_path in root.rglob("*")
        if file_path.is_file()
        and ".git" not in file_path.parts
        and (max_depth is None or len(file_path.relative_to(repository).parts) - root_depth <= max_depth)
        and (include is None or file_path.relative_to(repository).match(include))
    ]
    files.sort(key=lambda file_path: str(file_path.relative_to(repository)))
    return files[:MAX_LISTED_FILES]


def read_file_contents(file_path: Path, line_offset: int = 1, line_limit: int | None = None) -> str:
    if line_offset < 1 or line_limit is not None and line_limit < 1:
        raise fail("Line offset and limit must be positive.")
    if line_limit is None and file_path.stat().st_size > MAX_FILE_SIZE_BYTES:
        raise fail("File exceeds the 1 MiB read limit. Provide a line limit to read part of it.")
    try:
        if line_limit is None:
            return file_path.read_text(encoding="utf-8")
        lines: list[str] = []
        size_bytes = 0
        with file_path.open(encoding="utf-8") as file_handle:
            for line_number, line in enumerate(file_handle, start=1):
                if line_number < line_offset:
                    continue
                if line_number >= line_offset + line_limit:
                    break
                size_bytes += len(line.encode("utf-8"))
                if size_bytes > MAX_FILE_SIZE_BYTES:
                    raise fail("Selected lines exceed the 1 MiB read limit.")
                lines.append(line)
        return "".join(lines)
    except UnicodeDecodeError as error:
        raise fail("File is not UTF-8 text.") from error


@mcp.tool()
def checkout_repository(repository: str, revision: str = "HEAD") -> dict[str, str]:
    """Fetch a public HTTPS repository at a branch, tag, or commit without running its code."""
    repository, url_revision = validate_repository_url(repository)
    revision = validate_revision(revision)
    if revision == "HEAD" and url_revision is not None:
        revision = url_revision
    repository_id = checkout_id(repository, revision)
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
def list_files(repository_id: str, path: str = ".", max_depth: int | None = None, include: str | None = None) -> list[str]:
    """List up to 1,000 readable files below a repository-relative path."""
    repository = checkout_path(repository_id)
    if max_depth is not None and not 0 <= max_depth <= MAX_LIST_DEPTH:
        raise fail(f"Maximum depth must be between 0 and {MAX_LIST_DEPTH}.")
    return [str(file_path.relative_to(repository)) for file_path in source_files(repository, path, max_depth, include)]


@mcp.tool()
def read_file(repository_id: str, path: str, line_offset: int = 1, line_limit: int | None = None) -> str:
    """Read one UTF-8 text file no larger than 1 MiB from a checked-out repository."""
    repository = checkout_path(repository_id)
    file_path = resolve_path(repository, path)
    if not file_path.is_file() or ".git" in file_path.parts:
        raise fail("Path must identify a repository file.")
    return read_file_contents(file_path, line_offset, line_limit)


@mcp.tool()
def read_files(repository_id: str, paths: list[str]) -> list[dict[str, str]]:
    """Read up to 25 UTF-8 repository files, with a total size limit of 4 MiB."""
    if not paths or len(paths) > MAX_BATCH_FILES:
        raise fail(f"Provide between one and {MAX_BATCH_FILES} file paths.")
    repository = checkout_path(repository_id)
    result: list[dict[str, str]] = []
    total_size_bytes = 0
    for path in paths:
        file_path = resolve_path(repository, path)
        if not file_path.is_file() or ".git" in file_path.parts:
            raise fail("Each path must identify a repository file.")
        content = read_file_contents(file_path)
        total_size_bytes += len(content.encode("utf-8"))
        if total_size_bytes > MAX_BATCH_SIZE_BYTES:
            raise fail("Selected files exceed the 4 MiB batch read limit.")
        result.append({"path": path, "content": content})
    return result


@mcp.tool()
def search_files(repository_id: str, query: str, path: str = ".", include: str | None = None) -> list[dict[str, object]]:
    """Search repository files with ripgrep literal matching and return at most 100 matching lines."""
    if not query:
        raise fail("Search query must not be empty.")

    repository = checkout_path(repository_id)
    root = resolve_path(repository, path)
    if not root.is_dir() and not root.is_file():
        raise fail("Path must identify a file or directory.")
    arguments = ["rg", "--json", "--fixed-strings", "--glob", "!.git/**"]
    if include is not None:
        arguments.extend(["--glob", include])
    # Prevent a search term beginning with '-' from being parsed as an rg option.
    arguments.extend(["--", query, str(root)])
    process = subprocess.Popen(
        arguments,
        cwd=repository,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    matches: list[dict[str, object]] = []
    try:
        assert process.stdout is not None
        for output in process.stdout:
            event = json.loads(output)
            if event["type"] != "match":
                continue
            data = event["data"]
            match_path = Path(data["path"]["text"])
            if not match_path.is_absolute():
                match_path = repository / match_path
            matches.append(
                {
                    "path": str(match_path.relative_to(repository)),
                    "line": data["line_number"],
                    "text": data["lines"]["text"].rstrip("\n"),
                }
            )
            if len(matches) == MAX_SEARCH_RESULTS:
                process.terminate()
                break
        process.wait(timeout=120)
    except subprocess.TimeoutExpired as error:
        process.kill()
        raise fail("Search timed out.") from error
    finally:
        if process.stderr is not None:
            error_output = process.stderr.read().strip()
            if error_output and process.returncode not in {0, 1, -15}:
                raise fail(error_output[:2_000])
    return matches


def fetch_revision(repository: Path, revision: str) -> str:
    revision = validate_revision(revision)
    run_git("fetch", "--quiet", "--no-tags", "--depth=1", "--filter=blob:limit=1048576", "origin", revision, cwd=repository)
    return run_git("rev-parse", "FETCH_HEAD", cwd=repository).strip()


@mcp.tool()
def list_refs(repository_id: str) -> list[dict[str, str]]:
    """List up to 1,000 branches and tags advertised by the repository's origin."""
    repository = checkout_path(repository_id)
    output = run_git("ls-remote", "--heads", "--tags", "origin", cwd=repository)
    refs: list[dict[str, str]] = []
    for line in output.splitlines()[:MAX_LISTED_FILES]:
        commit, ref = line.split("\t", maxsplit=1)
        refs.append({"name": ref.removeprefix("refs/"), "commit": commit})
    return refs


@mcp.tool()
def get_commit(repository_id: str, revision: str = "HEAD") -> dict[str, object]:
    """Read commit metadata and changed paths for a branch, tag, or commit."""
    repository = checkout_path(repository_id)
    commit = "HEAD" if revision == "HEAD" else fetch_revision(repository, revision)
    metadata = run_git("show", "-s", "--format=%H%x00%P%x00%an%x00%ae%x00%aI%x00%s", commit, cwd=repository).strip().split("\x00")
    changes = run_git("diff-tree", "--root", "--no-commit-id", "--name-status", "-r", commit, cwd=repository)
    return {
        "commit": metadata[0],
        "parents": metadata[1].split() if metadata[1] else [],
        "author": {"name": metadata[2], "email": metadata[3], "date": metadata[4]},
        "subject": metadata[5],
        "changes": changes.splitlines()[:MAX_SEARCH_RESULTS],
    }


@mcp.tool()
def read_file_at_revision(repository_id: str, path: str, revision: str) -> str:
    """Read one UTF-8 text file from a branch, tag, or commit."""
    repository = checkout_path(repository_id)
    relative_path = revision_path(path)
    commit = fetch_revision(repository, revision)
    object_name = f"{commit}:{relative_path}"
    if int(run_git("cat-file", "-s", object_name, cwd=repository).strip()) > MAX_FILE_SIZE_BYTES:
        raise fail("File exceeds the 1 MiB read limit.")
    return run_git("show", object_name, cwd=repository)


@mcp.tool()
def diff_revisions(repository_id: str, base_revision: str, target_revision: str, path: str = ".") -> str:
    """Return a bounded unified diff between two revisions."""
    repository = checkout_path(repository_id)
    base_commit = fetch_revision(repository, base_revision)
    target_commit = fetch_revision(repository, target_revision)
    relative_path = revision_path(path)
    output = run_git(
        "diff",
        "--no-ext-diff",
        "--unified=3",
        base_commit,
        target_commit,
        "--",
        str(relative_path),
        cwd=repository,
        success_codes=(0, 1),
    )
    if len(output.encode("utf-8")) > MAX_FILE_SIZE_BYTES:
        raise fail("Diff exceeds the 1 MiB output limit.")
    return output


if __name__ == "__main__":
    mcp.run(transport="stdio")
