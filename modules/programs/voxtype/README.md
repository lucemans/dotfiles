# Local coding dictation

`programs.voxtype.dictationModel` defaults to `"nemotron"`. Voxtype streams
microphone audio over a WebSocket to a local
[NeMo-Speech.cpp](https://github.com/NVIDIA/NeMo-Speech.cpp) server running
[Nemotron Speech Streaming 0.6B](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b)
(English, March 2026 checkpoint). The model is cache-aware: each audio frame is
encoded once, so latency is set by the chunk size, not by re-reading a window.

Words are typed while you speak. The GTK overlay shows the tentative
transcript under the waveform. Scroll Lock still toggles dictation.

## Try it

```sh
sudo nixos-rebuild switch --flake .#v3x-fighter
systemctl status nemo-speech
journalctl -u nemo-speech -n 20
```

The first build converts the pinned checkpoint to GGUF and compiles the CUDA
server. Set `nixpkgs.config.cudaCapabilities` on the host to build one GPU
architecture instead of four.

## Latency and accuracy

`services.nemoSpeech.latency` picks the chunk the encoder waits for: `80ms`,
`160ms` (default), `560ms` or `1120ms`. Longer chunks are more accurate.
NVIDIA reports roughly 7% word error rate at 160 ms to 560 ms on its mixed
test sets, higher than Fluid Speech Mini's offline score on its own sets.
No latency has been measured on the target GPU or from microphone to editor.
CPU runs in a shared sandbox were dominated by load and say nothing about it.

## Vocabulary and corrections

Voxtype reads vocabulary files at the start of every recording, so an edit
applies on the next Scroll Lock press. Entries are one per line:

```text
# a bare term biases recognition toward it
Nextcloud
# a correction rewrites the heard words and also biases toward the result
next cloud => Nextcloud
```

Three places feed it. For the same left side, the user file overrides the system file:

- `programs.voxtype.vocabulary.words` and `.corrections`, written to
  `/etc/voxtype/vocabulary.txt`.
- `~/.config/voxtype/vocabulary.txt`, managed with `voxtype-vocab`.
- Voxtype's `[text.replacements]` table, which also applies to streamed text.

```sh
voxtype-vocab add Nextcloud kubectl
voxtype-vocab fix "next cloud" Nextcloud
voxtype-vocab remove kubectl
voxtype-vocab list
```

A boosted term raises the chance the model spells it your way. It cannot turn
a word the model splits into two words (`next cloud`) into one; use a
correction for that. Boosting is strongest for terms that sound distinct. Words
are held back until they can no longer start a multi-word correction, so a
correction with a long left side delays typing by that many words. The server
accepts up to 256 phrases per recording and clamps `remote_boost` at 5.

## Running the server elsewhere

`services.nemoSpeech` is host independent. To use the GPU host:

```nix
# on mediabus
services.nemoSpeech = { enable = true; host = "100.127.0.11"; openFirewall = true; };
# on fighter
programs.voxtype.dictationServer = "http://100.127.0.11:8010";
```

`openFirewall` opens the port on the WireGuard interface only. Over the network
the connection is plain HTTP and WebSocket inside the tunnel; set
`services.nemoSpeech.apiKeyFile` to require a key.

## Change models

```nix
programs.voxtype.dictationModel = "parakeet-unified";
```

restores the in-process CUDA Parakeet profile. It does not use the server,
vocabulary files or the live preview patch.

## Packages and checks

```sh
nix build .#nemo-speech .#nemo-speech-model .#voxtype-dictation .#voxtype-preview
nix build .#checks.x86_64-linux.nemo-speech .#checks.x86_64-linux.voxtype-vocab
```

The server check starts the CPU build in the Nix sandbox and transcribes a
public speech clip over HTTP and the realtime WebSocket.
