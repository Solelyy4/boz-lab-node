# Token Harbor (tokenharbor.ai) — free-tier gateway notes

OpenAI- and Anthropic-compatible gateway with a **standing free tier** on a few model IDs.
No signup credit, no subscription required, no card for the free routes.

## Endpoints and wiring

| Item | Value |
|---|---|
| OpenAI-compatible base | `https://tokenharbor.ai/v1` |
| Anthropic-compatible base | `https://tokenharbor.ai` |
| Auth | `Authorization: Bearer <key>` |
| Hermes provider | `model.provider: custom` + `base_url: https://tokenharbor.ai/v1`, `api_mode: chat_completions` |

Free model IDs (verify against `/v1/models` at task time — routes rotate):

| Model ID | Context | Out |
|---|---|---|
| `deepseek-v4.1-flash:free` | 1.05M | 128K |
| `mimo-v2.6-flash:free` | 1.048M | — |

On this host a gateway is registered as a **root-level YAML list**, not under `model:`:

```yaml
custom_providers:
  - name: Token Harbor
    base_url: https://tokenharbor.ai/v1
    api_key: <key>
    model: deepseek-v4.1-flash:free
    models:
      deepseek-v4.1-flash:free: {}
      mimo-v2.6-flash:free: {}
```

Hermes validates `custom_providers` as a **list of dicts** — the dict form validates as a warning
and its entries are silently ignored at runtime. **Append** to the existing list (the other
gateway entries there must survive), then `hermes gateway restart`: config is read at process
start.

`TH-Rudder` is their auto-router model. `:free` IDs never bill the wallet — they draw on the
free allowance only. The paid counterpart (`deepseek-v4.1-flash`) lists at $0.30/1M in,
$1.20/1M out; that list price is what the allowance is metered against.

## Limits — free account

| Limit | Value |
|---|---|
| Per account | 60 req/min, 1,800 req/hour — shared across every key and every model |
| Per IP | 100 req/min, 3,000 req/hour |
| Images | 10 req/min, 150 req/hour |
| Request size | 4 MB free / 100 MB after any top-up → 413 `request_too_large` |
| Concurrency | unlimited on every plan |
| Over rate | 429 + `Retry-After` |

## How the allowance actually behaves

- **Value-based, in USD at list price**, not a request count or a token count. The dashboard shows
  a **percentage**, not tokens.
- **Rolling 7-day window, personal**: the first free request starts it; each window is 7×24h from
  that user's own start time. It repeats indefinitely.
- **Unused room does not carry forward.** Free routes **stop accepting new requests** when the
  window is exhausted, and resume when the next window opens.
- **The API key itself does not expire** — it lives until revoked. Per-key "limits" in the
  dashboard are USD spend caps, not rate limits.
- To turn a key off, revoke it; a limit of `$0` is rejected, so it cannot be used as a kill switch.

## Signup — take the shortest path

Email+password needs inbox verification. **Google or GitHub OAuth needs neither**, and avoids the
whole harvester stack (own domain on Cloudflare Email Routing → worker → webhook on a Node server
port 80). OAuth is a ~20-second click by the account holder and is the recommended route; the
credential entry itself is theirs to do, never yours.

The signup form carries a **"Quick human check" (Turnstile)** that does not render under browser
automation — `input[name="cf-turnstile-response"]` stays empty and *Create account* silently does
nothing. That one click is the account holder's; everything after it is yours.

## Email verification gate — the blocker people misdiagnose

A key minted before the address is confirmed is **valid but unusable**. Read the code, not the
status:

| Response | Meaning | Action |
|---|---|---|
| `401 invalid_api_key` | mistyped, revoked, rotated | re-mint in the dashboard |
| `403 email_verification_required` | **key is fine**, address unconfirmed | confirm the address; do not re-mint |
| `200` on `/v1/models` but 4xx on a `:free` id | route not in the free tier | pick an id from `/v1/models` |

The confirmation mail **routinely never arrives** (provider dropped it, or the address was mistyped
at signup), so "check inbox and spam" is not a plan. Put the address under your own control: open
the account on a disposable mailbox you can poll over HTTP, then click the confirmation link
yourself — `scripts/mailbox_poll.py`. `/dashboard` resend and `support@tokenharbor.ai` are
human-latency fallbacks, not the fast path.

## "Get unlimited free keys" harvester packs — verdict

Packs found circulating (Camoufox auto-register + Node mail webhook + Cloudflare WARP / airplane-mode
IP rotation + systemd units) exist for one reason: the allowance is **per account**, so N accounts =
N allowances.

- The **per-IP** cap (100 req/min, 3,000/hour) still binds, which is why those packs ship IP
  rotation. Without rotation, extra accounts buy almost nothing.
- Real cost to stand one up: a domain on Cloudflare Email Routing, a VPS with port 80, Python +
  Camoufox, and Node — hours of setup plus ban risk, for something one OAuth signup delivers.
- Start with **one** account: 1,800 req/hour covers ordinary interactive use. Revisit only when
  measured usage actually hits the weekly ceiling.

## Getting facts off their site

`/docs/*`, `/pricing`, `/models` are client-rendered (Next.js): `curl` + tag-strip returns a couple
hundred characters of nav chrome and nothing else. Do not conclude "no info". Instead:

1. `https://tokenharbor.ai/llms.txt` — a server-rendered index of key facts and doc URLs.
2. `/faq` **is** server-rendered; grep it for `rolling 7-day`, `allowance`, `expire`.
3. Render the exact doc URL through the search backend (`web_search` on the page URL) — its
   snippet carries the full page text.
