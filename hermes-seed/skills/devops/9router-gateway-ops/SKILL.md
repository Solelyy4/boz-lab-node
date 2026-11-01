---
name: 9router-gateway-ops
description: "Use when 9router routing fails: start, health, pin."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows, macos, linux]
metadata:
  hermes:
    tags: [9router, gateway, model-routing, load-balancer, health]
    related_skills: [free-llm-api-keys, hermes-agent]
---

# 9Router Gateway Ops

## When to Use

Model routing through the local 9Router gateway: starting it, checking whether it is up,
pointing a CLI tool at it, or debugging "model unreachable" errors that are really
gateway-down errors.

## Verified install (this host)

| Fact | Value |
|---|---|
| Binary | `~/AppData/Roaming/npm/9router.cmd` (npm global, node 24) |
| Version | `0.5.111` |
| Default port | `20128` |
| Bind default | `0.0.0.0` |
| Data dir | `~/.9router` on Linux/macOS; **`%APPDATA%\9router` on Windows** — holds `machine-id`, `auth\cli-secret`, `db\data.sqlite` |
| Gateway auth | `/v1/*` needs a gateway API key from the `apiKeys` table, so an unauthenticated health probe answers **401** — that means alive, not broken |

## CLI surface

```bash
9router                      # run server (opens browser unless -n)
9router -p 20128 -n -l       # explicit port, no browser, show logs
9router -t                   # tray/background mode
9router --skip-update        # skip the auto-update check
9router show [tool]          # what each CLI tool is currently pointed at
9router connect <url>        # point a CLI tool at a remote gateway
```

## Health check (always first)

```bash
curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://127.0.0.1:20128/v1/models
curl -s -m 3 http://127.0.0.1:20128/v1/models | head -c 400
```

`000` means no listener — the gateway is not running, and every "model failed" report downstream
is a symptom, not a cause. **`401` is the healthy answer** (listener up, API key missing).

Start it before touching model config. On Windows `9router.cmd -n` dies in a non-interactive shell
and a bare `node app\server.js` with piped stdio exits with `stdin is not a tty`, so use the
console-backed launcher described under *Windows host quirks* below; from a real interactive
terminal `9router.cmd -n -l` still works. Re-run the health check after starting; only once it
answers should you debug routing.

## Windows host quirks (verified 1 Nov 2026)

| Symptom | Truth |
|---|---|
| `9router.cmd -n` prints `Exiting...` in a loop and exits | the CLI gets a signal in a non-interactive shell; do not fight it |
| `node app\server.js` (or `custom-server.js`) with piped stdio → `stdin is not a tty` then exit | the server refuses to run without a **console**; pty or a real console window is mandatory |
| `~/.9router` missing but gateway has data | on Windows the data dir is `%APPDATA%\9router` (machine-id, auth\cli-secret, db\data.sqlite) |

Working launcher (detached, minimized console, survives the session):

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File start_9router.ps1 -Port 20128
```

`start_9router.ps1` = `Start-Process node -ArgumentList '--dns-result-order=ipv4first','server.js' -WorkingDirectory %APPDATA%\npm\node_modules\9router\app -WindowStyle Minimized` with `PORT`/`HOSTNAME` set. Live copy: `~/Downloads/Mistral-farm/start_9router.ps1`.

Health after start: `401` on `/v1/models` = alive (API key required), `000` = dead.

### CLI token (for tooling that pushes providers)

`sha256(machine-id + "9r-cli-auth" + auth\cli-secret)[:16]`, read from the **data dir**. Tools that
only look in `~/.9router` need `DATA_DIR` pointed at it:

```bat
set DATA_DIR=C:\Users\<user>\AppData\Roaming\9router
```

Header is `x-9r-cli-token`; `/api/providers`, `/api/provider-nodes`, `/api/keys` all accept it.
`/v1/*` does **not** — it needs a gateway API key from `apiKeys` in `db\data.sqlite`
(`sqlite3` via python; the `/api/keys` listing masks them).

### Many connections for one provider: sticky by default

Adding N keys under one provider does **not** spread load. Default `fallbackStrategy` is
`fill-first`: every request goes to priority 1 until it fails. Proof: `usageHistory` shows all
requests on one `connectionId`. Turn on rotation once via settings:

```bash
curl -X PATCH http://127.0.0.1:20128/api/settings -H "x-9r-cli-token: <tok>" \
  -H 'content-type: application/json' \
  -d '{"providerStrategies":{"mistral":{"fallbackStrategy":"round-robin","stickyRoundRobinLimit":1}}}'
```

Valid `fallbackStrategy`: `fill-first` | `round-robin` | `random`. Verify by counting distinct
`connectionId` in the last N rows of `usageHistory`, not by trusting the setting (`stickyRoundRobinLimit: 1` = new key per request; the global default 3 = 3 requests per key). `scripts/pool_verify.py`
does the whole check in one run: N parallel completions, then distinct-connection count from the DB.

## Model routing notes

- One OpenAI-compatible surface in front of many upstreams; node names look like
  `provider/model` (`ag/...`, `sf/...`, `gpt-...`, `claude-...`).
- **Availability changes** — verify against `/v1/models` at use time instead of trusting a table.
- `ag/*` nodes are Google-hosted and carry a **separate upstream classifier**: a blocked request
  returns HTTP 200 with `content: null` plus `promptFeedback.blockReason`. That is not a model
  refusal — pivot provider instead of rewriting the prompt.
- `429` is fair-share, not a ban: rotate node, then retry with jitter.

## Verify a route actually works

```bash
curl -s http://127.0.0.1:20128/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"<node>","messages":[{"role":"user","content":"reply with ok"}],"max_tokens":16}'
```

Read `choices[0].message.content`. Null content plus a `promptFeedback`/error field means the
request never reached the model. Empty content with a normal finish reason means the token budget
was too small — use `max_tokens >= 2000` before concluding a model "refused".

## Limits, dead model names, and proving the route

- **The gateway enforces no request/token cap of its own.** `settings` holds only
  `providerStrategies`, and API keys carry `accessRestricted=0`. Every real limit belongs to the
  upstream provider, so answer "what is my limit?" from the provider, not from 9router.
- **9router strips upstream rate-limit headers**, so a completion through the gateway exposes
  nothing. Measure directly: take one key from `providerConnections.data` (JSON field `apiKey`,
  filter `testStatus='active'`) and call the provider API with `curl -D -`, then read
  `x-ratelimit-limit-req-minute` and `x-ratelimit-limit-tokens-minute`. Per-account values
  multiply by the healthy connection count. Method + measured Mistral baseline + how to raise
  it: `references/measuring-provider-limits.md`.
- **A 503 from 9router is a wrapped upstream error — read `error.message` for the real code.**
  `403 tier_not_allowed` means the model is unusable on every account and retrying never helps;
  `429` means later or rotate. Never call a model broken from the outer status alone.
- **Combos are callable model names** and fall through their list, so the `model` field in the
  response can differ from what was requested. Read it whenever you need to know which model
  actually served.
- **Prove which provider/model answered** by counting `usageHistory` rows before and after, then
  reading the last rows (`provider, model, status`). Config says what should happen; this says
  what did.
- **Make the gateway the default client target**: set `model.provider: 9router` and
  `model.default: <node>` in `config.yaml`, then confirm with one `-z` run plus a `usageHistory`
  delta. Replace the whole `model:` block in one edit — a regex that re-emits keys already
  present (`provider`, `supports_vision`) duplicates them and Hermes refuses to start.

## Failure matrix

| Symptom | Cause | Action |
|---|---|---|
| `000` on health | gateway not running | start it, re-check |
| `404` on `/v1/models` | wrong port | `9router -p <port>` or fix the client base URL |
| `401` | key missing/invalid for that upstream | re-auth that provider, not the gateway |
| `429` | upstream fair-share | pivot node, backoff + jitter |
| `200` + null content | upstream classifier block | change provider/model, not wording |
| Works in curl, fails in client | client base URL missing `/v1` | fix the client base URL |

## Housekeeping

- Killing the gateway kills every in-flight client; check `9router show` before restarting.
- The data dir (see the table above) holds provider API keys — back it up before editing by hand and
treat it as a secret. On Windows that is `%APPDATA%\9router`, not `~/.9router`.
- Settings live in `db\data.sqlite` (`settings` table, one JSON blob): `providerStrategies`,
`stickyRoundRobinLimit`, `comboStrategy`, outbound proxy. Read or patch through `/api/settings`
rather than writing the blob by hand.

## Checklist

- [ ] Health endpoint returns `200`
- [ ] `/v1/models` lists the node you intend to use
- [ ] One completion request returns non-null content
- [ ] Client base URL ends with `/v1`
