# litellm / teapot cleanup TODO

Leftovers from debugging the litellm↔prisma startup failure (fixed 2026-07-26 by
adding `PRISMA_QUERY_ENGINE_BINARY`/`PRISMA_SCHEMA_ENGINE_BINARY` and `openssl`
on PATH in `modules/services/llm/default.nix`). None of these block anything.

## Repo (`/etc/nixos`)

- [ ] `conntest.py` — debug script used to repro the prisma connect failure; delete.
- [ ] `sitedirs.txt` — companion to conntest.py (dump of litellm's python site dirs); delete.
- [ ] Commit the actual fix in `modules/services/llm/default.nix` (currently uncommitted on `feat/418`).
- [ ] Branch has a run of "testing" commits — squash/reword before merging to `master`.

## litellm state dir (`/var/lib/litellm`)

Leftovers from earlier failed attempts (an old `generate-litellm-prisma` ExecStartPre
that no longer exists). The service now uses the client generated into the nix store,
so these are inert:

- [ ] `prisma/` — read-only partial copy of the prisma package (generation died halfway); remove.
- [ ] `schema.prisma` — installed by the removed pre-step; remove.
- [ ] `prisma-cache/` — npm-downloaded prisma CLI cache from the old pre-step; remove.
- [ ] `.cache/prisma/` and `.cache/checkpoint-nodejs/` — node prisma CLI caches (incl. the
      empty `linux-nixos` engines dir from the 404'd downloads); remove.
- [ ] `.npm/` — npm cache/logs from the old pre-step; remove.

e.g. `sudo rm -rf /var/lib/litellm/{prisma,schema.prisma,prisma-cache,.cache,.npm}`
then `sudo systemctl restart litellm` to confirm nothing regrows weirdly.
Note: litellm-proxy-extras runs `prisma migrate deploy` at startup via the node CLI,
which will legitimately recreate a small `.cache/` — that one's fine.

## Still untested end-to-end

- [ ] `/var/lib/llama-models/` is empty — drop `Qwen3-8B-Q4_K_M.gguf` in there
      (llama-swap expects that exact path) and run one chat completion through
      `http://<host>:4000/v1/chat/completions` to prove the full chain.
