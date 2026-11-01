# Building a key pool: farm → verify → push → rotate → prove

Use when the ask is "farm N keys" / "I want a lot of free keys" / "make these keys usable from my
tools". The work is not the signup script — it is the **pool that actually spreads load, plus the
proof that it does**.

## What a farm really produces

| Reality | Consequence |
|---|---|
| Each key belongs to a throwaway mailbox account | never the account you keep; treat `accounts_keys.txt` as disposable credentials |
| New accounts sit on the lowest tier | catalogue models outside the free list answer `403 tier_not_allowed` — swap **model**, not key |
| Mailbox provider rate-limits **per IP** | ~12–15 signups per address, then `429 Rate limited (free)`; farm in waves with a cooldown instead of one burst |
| Keys rot silently (limit, challenge, deletion) | re-verify the whole pool before reporting success, and again before wiring it anywhere |

Never report "N keys farmed" from the farmer's own log line alone, and never treat a 200 on
`/models` as a live key.

## Procedure

1. **Read the repo before running it.** Clone into the user's working dir (not Desktop), read the
   script end to end, then `python -m venv .venv` + `pip install -r requirements.txt`. Keep a
   wrapper (`farm.cmd`) that re-creates the venv on first run so the user never hand-installs.
2. **Farm in waves, not one burst.** 10–15 accounts per wave, concurrency 2–4, a few minutes
   between waves. Wave failures are almost always at *inbox creation* (`429`), which is the IP
   limit — the next wave succeeds unchanged after the cooldown, so do not retry the same stage
   immediately.
3. **Verify every key with a real generation call** (`max_tokens` ≥ 200, read `content`): the
   farmer's `verify` subcommand, or one `POST /chat/completions` per key. A key answering 401/403
   is dead — drop it instead of pushing it into the pool.
4. **Push into the gateway** (`push` subcommand, or `POST /api/providers` with `provider`, `apiKey`,
   `name`, `priority`). Names must be unique or the API answers `409`; append a suffix on retry.
5. **Turn on rotation — the step everyone skips.** Gateways default to **sticky** (`fill-first`):
   every request hits priority 1 until it fails, so 30 keys behave like one. Enable per-provider
   round-robin — see `9router-gateway-ops` → *Many connections for one provider* — with
   `stickyRoundRobinLimit: 1` for one-key-per-request.
6. **Load test in parallel** — 8–16 concurrent requests, require 100% 200s. This is where a dead
   key, a wrong model id, or a per-key rate limit surfaces.
7. **Prove the spread from the gateway's own usage table**, not from the setting: count distinct
   `connectionId` across the last N `usageHistory` rows for that provider. 16 requests → 16
   distinct connections = rotation works. Fewer = still sticky.

## Where the keys actually live (the question that follows)

After farming, the user asks "mana nak dapat key ni / where do I use it". There is no portal — the
key was written to disk at signup:

| File | Shape |
|---|---|
| `accounts_keys.txt` | `email:password:api_key:provider`, one line per account — the copy-paste source |
| `accounts.jsonl` | full record per attempt (workspace, org, test status, `pushed`) — append-only, safe to resume |
| gateway DB | one row per key under `providerConnections` (secret inside `data`) |

Answer with three destinations and name which key goes where — mixing them is the usual confusion:

1. **Direct to the provider**: `https://api.<provider>.ai/v1` + the `mstrl_…`-style key.
2. **Through the gateway** (recommended): `http://127.0.0.1:<port>/v1` + the **gateway's** API key,
   model `provider/model-id`. The farmed keys stay hidden behind it and rotate.
3. **In a script**: a helper that reads line N of `accounts_keys.txt` and posts one completion — ship
   it so the user sees a real 200 instead of instructions.

Say plainly that an API key is not a login: it goes in `Authorization: Bearer <key>`.

## Credential hygiene

- `chmod 600` is a no-op for NTFS mode bits under git-bash — on Windows the protection is the
  user-profile ACL. Say that instead of claiming mode bits protect the file.
- Never print a full key in chat; show `prefix…last4`. Read the real value into a shell variable
  (`K=$(sed -n '3p' accounts_keys.txt | cut -d: -f3)`) so the command stays copy-pasteable without
  leaking it — and remember a native `curl` cannot write to an MSYS-style `/c/...` output path.
- Keep the pool directory out of any repo the user shares or commits.

## Reporting shape that survives review

A table of raw results: farm ok/fail per wave, `verify ok=N bad=0 total=N`, gateway connection count
plus active count, load test `N/N ok wall=Xs`, distinct-connection count. Then the honest limits:
per-account daily cap, no proxy pool yet, keys bound to throwaway mailboxes. A pool claimed without
the distinct-connection number is unverified.
