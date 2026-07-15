# eth-data-mcp

Inspired by [](https://github.com/maxencerb/foundry-mcp). Rewritten.
Exposes a read-only bubblewraped tmpfs mcp that allows for spinning up anvil to fork mainnet or testnets.

It should also include 3rd party data for ease of fetching; such as blockscout for listing transactions (do note this may be incomplete data but its good for hints), discovering assets given an address, etc.

The below list is for inspiration copied from foundry-mcp, it can be altered / improved.

### Anvil Tools

| Tool | Description |
|------|-------------|
| `anvil_start` | Start a local Ethereum node |
| `anvil_stop` | Stop a running node |
| `anvil_status` | Check node status |
| `anvil_mine` | Mine blocks |
| `anvil_setBalance` | Set account balance |
| `anvil_setCode` | Set contract bytecode |
| `anvil_setStorageAt` | Set storage slot value |
| `anvil_impersonateAccount` | Impersonate an account |
| `anvil_stopImpersonatingAccount` | Stop impersonating |
| `anvil_snapshot` | Create state snapshot |
| `anvil_revert` | Revert to snapshot |
| `anvil_setNextBlockTimestamp` | Set next block timestamp |
| `anvil_increaseTime` | Increase block time |
| `anvil_setAutomine` | Toggle auto-mining |
| `anvil_reset` | Reset fork state |
| `anvil_getAccounts` | List dev accounts |

### Chisel Tools

| Tool | Description |
|------|-------------|
| `chisel_eval` | Evaluate Solidity expression |
| `chisel_run` | Run Solidity statements |
| `chisel_list` | List saved sessions |
| `chisel_load` | Load a session |
| `chisel_view` | View session source |
| `chisel_clear_cache` | Clear cache |

### Help Tools

| Tool | Description |
|------|-------------|
| `forge_help` | Get forge CLI help (supports subcommands) |
| `cast_help` | Get cast CLI help (supports subcommands) |
| `anvil_help` | Get anvil CLI help |
| `chisel_help` | Get chisel CLI help |
| `foundry_version` | Get installed Foundry versions |
