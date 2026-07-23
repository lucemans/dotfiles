# anyrun

Wayland-native launcher. No daemon, no telemetry — cold-starts per invocation.
Configured in `default.nix` via home-manager's `programs.anyrun`; styling comes
from the gruvbox palette in `modules/theme/theme.nix`.

- Keybind: `Alt+R` (plasma-manager hotkey)
- `config.ron` and `style.css` are generated — edit `default.nix`, never
  `~/.config/anyrun/` directly. Changes apply on next launch after a rebuild.
- Fallback: rofi stays installed on `Alt+Shift+R`.

## Current capabilities

| Plugin | Query style | Notes |
| --- | --- | --- |
| applications | app names | desktop entries |
| rink | `2+2`, `1 feet in meters`, `100 usd in eur` | math, units, fiat currencies |
| shell | `$ command` | run shell commands |
| symbols | symbol/unicode names | |
| websearch | engine prefix + query | opens default browser |
| nix_run | `nixpkgs#attr` | `nix run` graphical apps |
| github (custom) | `wallet-page`, `v3xlabs/wallet-page` | fuzzy repos over lucemans, v3xlabs, ethereum orgs |
| github (custom) | `wallet.page` | input containing a dot opens as website |
| ethereum-search (custom) | `eip 1559`, `erc-20`, `1559` | proposals from eips.ethereum.org index |
| ethereum-search (custom) | `eips#123`, `ercs pr 123`, bare `123` | PR lookup on ethereum/EIPs + ethereum/ERCs |

All links open via `xdg-open` (chromium is the default handler).

### Custom plugins

Built from `plugins/<name>/` as cdylib crates (`perSystem.packages` in
`default.nix`), compiled against the `anyrun-plugin` crate pinned to the
installed anyrun's tag (currently `v26.6.1`). When nixpkgs bumps anyrun:

1. Update the `tag` in each plugin's `Cargo.toml`.
2. Regenerate lockfiles: `cargo generate-lockfile --manifest-path plugins/<name>/Cargo.toml`.
3. Update the `outputHashes` versions/hashes in `default.nix` (build with a
   wrong hash once to learn the new one).

Data is cached on disk because anyrun cold-starts per launch (GitHub's
unauthenticated API allows 60 req/h):

- `~/.cache/anyrun-plugins/github-repos.json` — repo list, 1h TTL
- `~/.cache/anyrun-plugins/eip-index.json` — EIP/ERC index, 24h TTL

## Planned capabilities (tracking)

- [ ] **crypto** (`plugins/crypto/`) — `1 eth in btc` style queries. Parse
  `<amount> <symbol> in/to <symbol>`, resolve via CoinGecko free API, Enter
  copies the result.
- [ ] **nixpkgs search** — port of `modules/rofi/nixpkgs-search.sh`
  (search.nixos.org Elasticsearch backend): fuzzy package results with
  attr/version/description, Enter opens the package page or copies the attr.
- [ ] github: pagination past the 100 most-recently-pushed repos per org.

## Keybind propagation (Plasma 6.7 Wayland)

`org.kde.kglobalaccel` is owned **in-process by `kwin_wayland`**. The shortcut
registry reads `~/.config/kglobalshortcutsrc` once at session start and never
watches the file again (verified in the kglobalacceld source: no
`KConfigWatcher`, no reload DBus method). Consequences:

- plasma-manager writes the file correctly at every activation, but hotkey
  changes only take effect at the **next login**. There is no safe runtime
  reload:
  - restarting `plasma-kglobalaccel.service` is a no-op — that unit is
    vestigial on Wayland (always `inactive dead`)
  - `org.kde.KWin /KWin reconfigure` only reparses `kwinrc`, not shortcuts
  - mutating the registry over DBus (`doRegister`/`setForeignShortcutKeys`/
    `unregister`) **crashed KWin** and killed the session — do not automate this
- `reload-plasma` restarts plasmashell only (panels/widgets); it never
  affected keybinds.
