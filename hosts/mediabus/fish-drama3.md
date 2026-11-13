# Fish Audio Drama 3 on mediabus

This adds an on-demand, local-only speech API at `127.0.0.1:8085`.
The native audio.cpp community port supports Drama 3 with CPU expert offload;
its documented 16 GB profile uses Q2_K experts and eight CPU expert layers.
Mediabus has two 16 GB A4000s, not a single 32 GB GPU. This setup uses GPU 0
and system RAM. It does not pool the cards or coordinate VRAM with llama-swap.

Runtime source and model revision are pinned; the 17.05 GB model download is
SHA-256 checked before use and persists in `/var/lib/fish-drama3`. The first
start downloads it. Leave at least 20 GB free there, plus space for the Nix
CUDA build. Building the runtime/CUDA dependencies may take considerable time.

## Apply on mediabus

From the checked-out PR branch, with access to the existing private flake inputs:

```sh
# First build without activating the configuration.
sudo nixos-rebuild build --flake .#v3x-mediabus
# Then activate the built configuration.
sudo nixos-rebuild switch --flake .#v3x-mediabus
```

The service deliberately has no boot target. A rebuild does not start it.
Before starting, inspect GPU use with `nvidia-smi`; arrange for GPU 0 to be free
of other inference workloads. In particular, llama-swap can reload models in
response to traffic even if no model is loaded at the instant you inspect it.
The documented offload profile assumes a dedicated 16 GB card and still needs
verification on this host. Do not stop existing services without coordinating
with their users.

```sh
sudo systemctl start fish-drama3
sudo journalctl -u fish-drama3 -f
```

Once startup completes, submit a first request (model loading is lazy, so allow
extra time). This exercises actual synthesis, beyond checking server health:

```sh
curl --fail-with-body --max-time 600 \
  http://127.0.0.1:8085/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{"model":"fish-drama3","input":"Hello from mediabus.","response_format":"wav"}' \
  --output /tmp/fish-drama3.wav
file /tmp/fish-drama3.wav
```

Listen to the WAV and inspect `nvidia-smi` during synthesis. Verify memory,
pronunciation, and latency before using it for real workloads. GPU memory is
released after five idle minutes, but a later request can load it again.

To use from another computer, forward the port with SSH rather than opening
the firewall. Replace the SSH target with your existing mediabus login:

```sh
ssh -N -L 8085:127.0.0.1:8085 USER@MEDIABUS
```

The API then has the same localhost URL on your computer. This change does not
register the backend with LiteLLM or expose an unauthenticated network listener.

## Stop and recover

```sh
sudo systemctl stop fish-drama3
```

If the checksum fails for an existing final model file, stop the service, move
the file aside, and start again to download a clean copy. Interrupted downloads
resume from `.partial`. If a resumed download repeatedly fails its checksum,
remove that partial file while the service is stopped and retry.

Revert the PR and rebuild to remove the service; retained model data can be
removed separately when no longer needed.

## References and validation limits

- [audio.cpp Drama 3 model guide](https://github.com/0xShug0/audio.cpp/blob/eeeca9e88b42509707486efb37bb5edb3b1ca48e/docs/models/fish_drama3.md)
- [audio.cpp Nix build guide](https://github.com/0xShug0/audio.cpp/blob/eeeca9e88b42509707486efb37bb5edb3b1ca48e/docs/build/nixos.md)
- [Pinned model package and license files](https://huggingface.co/Jmica/Drama-3-GGUF/tree/060acc8e5d9e5d16baf647c775dfe1a1438f5f35)

This is a community port with quantized weights. Nix syntax is checked separately
from evaluation/build and GPU runtime validation. The PR does not establish
perceptual parity with the official model or successful inference on mediabus.
