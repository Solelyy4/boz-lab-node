---
name: blockchain-cli-patterns
description: "Use when doing on-chain work by CLI: RPC, reads, txs."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [ethereum, rpc, evm, cast, transactions, on-chain]
    related_skills: [smart-contract-audit, secret-safe-scripting]
---

# Blockchain CLI Patterns

## When to Use

Any on-chain read or write done from the shell: balances, proxy resolution, revert decoding, call
simulation, or sending a transaction. Prefers raw JSON-RPC (works everywhere, no SDK) and reaches
for Foundry when installed.

## Environment reality (this host)

| Tool | State |
|---|---|
| `web3` / `eth-account` | **installed** — web3 8.0.0, eth-account 0.14.0 |
| `py-solc-x` | **installed** — solc `0.8.26` downloaded, compiles offline |
| `cast` / `forge` / `anvil` | **not installable on this host**: foundry v1.8.6 publishes no Windows asset (36 assets: alpine/darwin/linux only), no rust toolchain, no WSL2, no docker |
| `curl`, `python 3.14` | available |

Verified: `Web3.keccak(text="transfer(address,uint256)")[:4].hex()` → `a9059cbb`, and
`solcx.compile_source("contract A { function f() public pure returns (uint){ return 1; } }")`
returns `['<stdin>:A']` with solc 0.8.26.

For a local fork node without Foundry, use hardhat from npm (`npx hardhat node --fork <rpc>`);
every read/simulate path below still works over plain JSON-RPC.

```bash
UV="C:/Users/<user>/AppData/Local/hermes/tools/uv-0.13.5-win32-x64/uv.exe"
PY=$(python -c "import sys;print(sys.executable.replace(chr(92),'/'))")
"$UV" pip install --python "$PY" web3 eth-account
```

Everything below works with plain `curl` until then — that is the point.

## Raw JSON-RPC, the whole toolkit

```bash
RPC=https://eth.llamarpc.com
rpc() { curl -s $RPC -H 'content-type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}"; }

rpc eth_blockNumber '[]'
rpc eth_getBalance '["0xADDR","latest"]'
rpc eth_getTransactionCount '["0xADDR","pending"]'      # nonce: pending, not latest
rpc eth_gasPrice '[]'
rpc eth_getCode '["0xADDR","latest"]' | head -c 120      # 0x = EOA, not a contract
rpc eth_call '[{"to":"0xADDR","data":"0x18160ddd"},"latest"]'
rpc eth_getTransactionReceipt '["0xTXHASH"]'
```

Interpretation traps:

- `eth_getBalance` returns **hex wei** — divide by `1e18` for the native coin, and remember an
  ERC-20 balance needs a `balanceOf` call instead.
- A `latest` nonce produces replacement-tx loops. Use `pending`.
- `eth_getCode` returning `0x` means no contract at that address on that chain — a wrong chain id
  looks exactly like a deleted contract.
- `eth_call` returning `0x` is usually a missing implementation (proxy) or a wrong selector.

## Selectors you should not have to look up

| Signature | Selector |
|---|---|
| `totalSupply()` | `0x18160ddd` |
| `balanceOf(address)` | `0x70a08231` |
| `allowance(address,address)` | `0xdd62ed3e` |
| `decimals()` | `0x313ce567` |
| `owner()` | `0x8da5cb5b` |
| `transfer(address,uint256)` | `0xa9059cbb` |
| `approve(address,uint256)` | `0x095ea7b3` |

Encode arguments as 32-byte left-padded hex (`0x` + 24 zeros + the 40-char address for `address`).

## Simulate before sending

```bash
rpc eth_call '[{"from":"0xYOU","to":"0xTARGET","data":"0x...","value":"0x0"},"latest"]'
rpc debug_traceCall '[{"from":"0xYOU","to":"0xTARGET","data":"0x..."},"latest",{}]'
```

A revert here costs nothing. The same revert on-chain costs the full gas.

## Chain IDs (a wrong one gives silently wrong reads)

| Chain | ID |
|---|---|
| Ethereum | 1 |
| BSC | 56 |
| Polygon | 137 |
| Arbitrum One | 42161 |
| Base | 8453 |
| Optimism | 10 |
| Avalanche C | 43114 |

## Sending a transaction (when asked)

1. Build calldata (selector + padded args), simulate with `eth_call`.
2. Read `eth_gasPrice`, or an EIP-1559 pair (`eth_maxPriorityFeePerGas` + block `baseFeePerGas`),
   then `maxFeePerGas = 2*baseFee + priority`.
3. Sign locally — never paste a private key into a remote API:

```python
from eth_account import Account
signed = Account.sign_transaction({
    "nonce": nonce, "gasPrice": gas_price, "gas": gas,
    "to": to, "value": value, "data": data, "chainId": chain_id,
}, os.environ["PRIVATE_KEY"])          # key from env, never argv
rpc("eth_sendRawTransaction", [signed.raw_transaction.hex()])
```

4. Poll `eth_getTransactionReceipt` until non-null; `status: 0x1` = success.
5. Record tx hash, block number, explorer URL, and the before/after balance difference.

**Irreversible:** a broadcast transaction is final. Confirm the intent once before signing, then
execute without further hand-wringing.

## Reading a revert like a human

```python
import os
data = os.environ["REVERT_HEX"]
if data.startswith("0x08c379a0"):            # Error(string)
    raw = bytes.fromhex(data[10:])
    print(raw[64:].split(b"\x00")[0].decode(errors="ignore"))
else:
    print("custom error selector:", data[:10])   # map it via the ABI
```

## Pitfalls

- Public RPCs prune history and rate-limit; rotate the endpoint before blaming the contract.
- `eth_call` without `from` simulates as the zero address, so `onlyOwner` paths behave differently
  than your wallet would.
- Fee-on-transfer tokens: read `balanceOf` before and after; never trust the amount argument.
- Windows: give native tools `C:/...` paths, not `/c/...`.

## Verification

| Claim | Proof |
|---|---|
| "balance read" | raw hex + human value, with address and chain id |
| "tx sent" | tx hash + receipt status + block number |
| "call would succeed" | `eth_call` non-reverting output, data recorded |
| "proxy resolved" | storage slot read + `eth_getCode` on the implementation |
