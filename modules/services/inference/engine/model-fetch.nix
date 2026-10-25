# Downloads and verifies model files at runtime, outside the Nix store.
#
# `files` is the list `default.nix` returns: { repo, rev, file, sha256, gated, dest } for each
# file. Returns the program a systemd unit runs.
{
  lib,
  pkgs,
}: files:
pkgs.writeShellApplication {
  name = "llama-models-fetch";
  runtimeInputs = [pkgs.curl pkgs.coreutils];
  text = ''
    failed=0

    fetch() {
      local url=$1 dest=$2 want=$3 gated=$4 rc=0 got
      if [ -f "$dest" ] && [ "$(cat "$dest.ok" 2>/dev/null)" = "$want" ]; then
        return 0
      fi
      mkdir -p "$(dirname "$dest")"
      # A file with no `.ok` marker, such as one copied in by hand, is accepted when its hash matches.
      if [ -f "$dest" ]; then
        echo "verifying $dest"
        got=$(sha256sum "$dest" | cut -d' ' -f1)
        if [ "$got" = "$want" ]; then
          echo "$want" > "$dest.ok"
          return 0
        fi
        echo "sha256 of $dest is $got, want $want" >&2
        rm -f "$dest"
      fi
      if [ "$gated" = 1 ]; then
        echo "$dest is from a gated repo, so it has to be placed by hand" >&2
        return 0
      fi
      echo "downloading $dest"
      # Exit 33 means the partial file already holds every byte, so it only needs the hash check.
      curl --fail --location --retry 5 --retry-delay 10 --continue-at - --output "$dest.part" "$url" || rc=$?
      if [ "$rc" -ne 0 ] && [ "$rc" -ne 33 ]; then
        echo "download failed for $dest (curl exit $rc)" >&2
        return 1
      fi
      got=$(sha256sum "$dest.part" | cut -d' ' -f1)
      if [ "$got" != "$want" ]; then
        echo "sha256 mismatch for $dest: got $got, want $want" >&2
        rm -f "$dest.part"
        return 1
      fi
      mv "$dest.part" "$dest"
      echo "$want" > "$dest.ok"
    }

    ${lib.concatMapStrings (m: ''
        fetch ${lib.escapeShellArg "https://huggingface.co/${m.repo}/resolve/${m.rev}/${m.file}"} \
          ${lib.escapeShellArg m.dest} \
          ${m.sha256} ${
          if m.gated
          then "1"
          else "0"
        } || failed=1
      '')
      files}

    exit "$failed"
  '';
}
