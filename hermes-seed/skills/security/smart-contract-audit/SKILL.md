---
name: smart-contract-audit
description: "Use when auditing Solidity/DeFi: RPC recon to fork PoC."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [solidity, defi, reentrancy, oracle, rpc, foundry, audit]
    related_skills: [bug-bounty-pipeline, evidence-first-report]
---

# Smart Contract Audit

## When to Use

Auditing a Solidity contract or DeFi protocol, triaging a bounty target on-chain, or checking
whether a deployed proxy's actual logic contains a known bug class.

## Method

Read-only on-chain recon first (public RPC, no signup), then bug-class sweep, then a fork PoC.
Never claim a finding without a trace or a runnable test.

## Phase 1 — locate the real code

Proxy contracts hide the logic. Resolve the implementation slot before reading anything.

| Slot | Constant | Meaning |
|---|---|---|
| EIP-1967 implementation | `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` | logic address |
| EIP-1967 admin | `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103` | proxy admin |
| EIP-1967 beacon | `0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50` | beacon address |

```bash
RPC=https://eth.llamarpc.com   # any public endpoint; no key
C=0xTARGET

# implementation address
curl -s $RPC -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":["'$C'","0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc","latest"]}'

# bytecode present?
curl -s $RPC -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["'$C'","latest"]}' | head -c 200

# read-only probe: totalSupply() selector 0x18160ddd
curl -s $RPC -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"'$C'","data":"0x18160ddd"},"latest"]}'
```

Common selectors (no ABI needed): `0x18160ddd` totalSupply · `0x70a08231` balanceOf(address) ·
`0xdd62ed3e` allowance(address,address) · `0x8da5cb5b` owner() · `0x313ce567` decimals().

With Foundry (`foundryup`) each becomes one line:

```bash
cast storage $C 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC
cast call $C "totalSupply()(uint256)" --rpc-url $RPC
cast source $C --rpc-url $RPC            # verified source, if published
```

## Phase 2 — bug-class sweep (ordered by payout density)

| Class | What to grep / test | Kill condition |
|---|---|---|
| **Reentrancy** | external call before state write; `nonReentrant` missing on a state-changing fn; read-only reentrancy via `balanceOf` in a view a third party trusts | CEI respected, guard on every path |
| **Oracle** | `getReserves()`, `slot0()`, `latestAnswer()` as spot price; `updatedAt` never checked | TWAP + staleness validation |
| **Access control** | `tx.origin`, setter without `onlyOwner`, re-callable `initialize()`, uninitialized proxy | initializer guarded, timelock ≥48h |
| **ERC-20 quirks** | raw `transfer`/`transferFrom` (USDT returns no bool), fee-on-transfer accounting, rebasing, ERC-777 `tokensReceived` hook | `SafeERC20` + measured balance deltas |
| **Precision** | division before multiplication, share rounding in the depositor's favour, `1e18` vs token decimals | rounding always favours the protocol |
| **Economics** | first-depositor inflation, donation/skim, flash-loanable collateral, sandwichable swaps | virtual shares / dead shares / TWAP |
| **Upgrade safety** | storage layout collision after upgrade, `selfdestruct`, delegatecall to user input | layout diff clean |

## Phase 3 — PoC on a fork

```bash
anvil --fork-url $RPC --fork-block-number <N> --chain-id 1
```

Invariant style beats scripted happy paths:

```solidity
function invariant_solvency() public view {
    assertGe(token.balanceOf(address(vault)), vault.totalAssets());
}

function invariant_noFreeShares() public view {
    assertEq(vault.previewRedeem(vault.balanceOf(address(this))), 0); // fresh wallet
}
```

Profit accounting for the report — gross minus everything that eats it:

```
profit = drained - gas_used * gas_price - bribe - slippage - flash_loan_fee
```

Flash-loan source: Aave `flashLoan`, Uniswap V3 `flash()`, Balancer `flashLoan`. Submit through a
private mempool (Flashbots) or the attempt gets front-run.

## Phase 4 — severity and report

- Do **not** self-assign severity. Quote the program's reward table or write
  "Severity: defer to your assessment".
- Attach contract address, chain, block number, the exact call sequence, and the trace or test
  name proving state change.
- Distinguish **theoretical** from **demonstrated**. Information disclosure ≠ critical breach.

## Pitfalls

- Testnet findings usually pay nothing — confirm the chain is in scope first.
- A `view` call reverting on a fork often means a missing dependency contract, not a bug.
- `eth_call` against a proxy whose implementation is undeployed returns `0x` — check
  `eth_getCode` on the implementation before concluding "no supply".
- Public RPCs rate-limit and prune; if a historical block fails, rotate the endpoint.

## Verification

| Claim | Required proof |
|---|---|
| "proxy resolves" | `eth_getStorageAt` slot output, 32-byte address |
| "bug exists" | runnable fork test that fails against fixed code |
| "drainable" | before/after balance delta in the test, plus tx hash if broadcast |
| "fixed" | same test now reverts / invariant holds |
