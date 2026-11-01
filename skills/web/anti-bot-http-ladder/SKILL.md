---
name: anti-bot-http-ladder
description: "Use when a fetch hits 403/429/bot-wall: HTTP ladder."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [scraping, tls-fingerprint, curl_cffi, cloudflare, httpx, pure-http]
    related_skills: [blocked-page-recovery, captcha-solver]
---

# Anti-Bot HTTP Ladder

## When to Use

A `requests`/`httpx` fetch returns 403/429, a Cloudflare challenge, a JS-required page, or an
empty body — and you still want the content without driving a browser.

## The ladder

Escalation ladder for fetching a protected page **without a browser**. Cheap → expensive.
Stop as soon as a step returns real content. Never retry the identical request that just
failed — mutate one variable per attempt.

```
L1 requests/httpx            default client, sane headers
L2 curl_cffi impersonate     real Chrome JA3/JA4 + header order
L3 session + cookie replay   cf_clearance / __cf_bm from a solved challenge
L4 HTTP/2 multiplex          :method :authority :scheme :path ordering
L5 protocol pivot            /api/, /graphql, RSS, feed, origin IP direct
L6 browser (last resort)     agent-browser, close the tab in finally
```

## Environment facts (this host, verified)

| Fact | Value |
|---|---|
| Interpreter | `which python` → Hermes venv (`installs/*/environments/*/venv/Scripts/python.exe`) |
| Installed | `httpx 0.28.1`, `requests 2.33.0`, `curl_cffi 0.17.0`, `bs4 4.15.0`, `lxml 6.1.3` |
| NOT installed | `playwright`, `camoufox`, `patchright`, `numpy` |
| **No `pip` in that venv** | install with `uv pip install --python <NATIVE-PATH>` |
| Native path required | `C:/Users/.../venv/Scripts/python.exe`, not `/c/Users/...` |

```bash
UV="C:/Users/<user>/AppData/Local/hermes/tools/uv-0.13.5-win32-x64/uv.exe"
PY=$(python -c "import sys;print(sys.executable.replace(chr(92),'/'))")
"$UV" pip install --python "$PY" curl_cffi beautifulsoup4 lxml
```

Verified after install: `curl_cffi 0.17.0` returns `ja3_hash 47969252fcc0967138d5a3cb8b286263`,
`ja4 t13d1517h2_8daaf6152771_cb7bf5808d99` against `tls.browserleaks.com/json`.

## L2 — curl_cffi impersonation (the workhorse)

```python
from curl_cffi import requests as cr

s = cr.Session(impersonate="chrome")          # chrome / chrome124 / chrome131 / safari / firefox
r = s.get("https://target.tld/page", timeout=25)
print(r.status_code, len(r.text))
```

Rules that actually move the needle:

1. **`impersonate` sets UA too** — do not override `User-Agent` by hand, it desyncs from the
   TLS+HTTP2 fingerprint. If a UA is mandatory, pick the matching `impersonate` profile instead.
2. **Keep the session.** Reuse preserves cookie jar, HTTP/2 connection and TLS session ticket.
3. **Header order matters as much as value.** Send the browser's real order:
   `sec-ch-ua` → `sec-ch-ua-mobile` → `sec-ch-ua-platform` → `Upgrade-Insecure-Requests` →
   `User-Agent` → `Accept` → `Sec-Fetch-Site` → `Sec-Fetch-Mode` → `Sec-Fetch-Dest` →
   `Accept-Encoding` → `Accept-Language`. curl_cffi orders these per profile; extra headers
   appended manually land at the end, which is what Chrome does too.
4. **Referer chain.** Deep links need the parent page as `Referer`, or hotlink protection 403s.

## Distinguish the block from the content

A 200 can still be a block page. Classify before parsing:

```python
def classify(r):
    t = r.text[:4000].lower()
    if r.status_code in (403, 429):                  return "blocked-status"
    if "just a moment" in t or "cf-challenge" in t:  return "cf-challenge"
    if "captcha" in t and len(r.text) < 20000:        return "captcha-wall"
    if "enable javascript" in t:                      return "js-required"
    if r.status_code == 200 and len(r.text) > 5000:   return "content"
    return f"unknown-{r.status_code}"
```

## Retry discipline (decorrelated jitter, no blind loops)

```python
import random

def backoff(attempt, cap=30.0):
    return min(cap, random.uniform(1.0, 3.0) * (2 ** attempt))
```

Mutate one thing per attempt: `impersonate` profile → `Accept-Language` → proxy → path shape.
Three identical retries is a bug, not persistence.

## L3 — cookie replay after a challenge

```python
cookies = {c["name"]: c["value"] for c in cdp("Network.getAllCookies")["cookies"]}
s = cr.Session(impersonate="chrome", cookies=cookies)
```

`cf_clearance` is bound to IP + UA + TLS fingerprint. Reuse **the same** `impersonate` profile
and the same egress IP, or it 403s again. Persist to disk (`chmod 600`) with its UA string and
IP recorded beside it.

## L4 — HTTP/2 pseudo-header ordering

Gateways that fingerprint HTTP/2 want `:method` → `:authority` → `:scheme` → `:path`.
curl_cffi and httpx (`http2=True`) do this correctly per profile; hand-rolled h2 stacks often
emit `:path` early and get flagged.

## L5 — protocol pivot before any browser

Look for the data plane the site itself uses: `/api/`, `/graphql`, `/wp-json/`, `/rss`, `?format=json`,
mobile subdomain, `static.` CDN JSON, sitemap XML. Pulling JSON beats scraping HTML and usually
has no bot wall at all.

## L6 — browser fallback, ephemeral

```python
# via the browser_exec tool, not a local playwright install
new_tab("https://target.tld"); wait_for_load()
txt = js("document.body.innerText.slice(0,5000)")
cookies = cdp("Network.getAllCookies")["cookies"]   # harvest, then close the tab
```

A browser left open is a zombie — close the tab and verify no orphan process remains.

## Pitfalls

- **Windows path translation is off.** `node /tmp/a.js` and `git -C /c/Users/x` fail; pass
  `C:/Users/x` forward-slash native paths to native binaries.
- **`search_files` false-zero** — cross-check with `grep -F` before claiming "not found".
- **429 ≠ block.** Back off, then pivot node/proxy; a rate limit answered with more requests
  escalates into a ban.
- **Never pipe a native tool's stderr** into a reader that exits early.

## Verification before claiming success

| Claim | Required proof |
|---|---|
| "fetch works" | HTTP status + byte length + a distinctive substring from the body |
| "WAF bypassed" | response difference vs the blocked attempt (status, length, marker) |
| "fingerprint matches" | `ja3_hash`/`ja4` from `tls.browserleaks.com/json` |
| "session reused" | second request returns 200 without a challenge marker |
