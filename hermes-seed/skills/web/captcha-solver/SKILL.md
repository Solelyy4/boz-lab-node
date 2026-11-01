---
name: captcha-solver
description: "Use when a captcha blocks you: solve, harvest, replay."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [captcha, turnstile, recaptcha, hcaptcha, solver, cookies]
    related_skills: [anti-bot-http-ladder, blocked-page-recovery]
---

# Captcha Solver

## When to Use

A page returns a challenge instead of content: Turnstile, reCAPTCHA, hCaptcha, or a Cloudflare
interactive challenge — and the token or session cookie is what you actually need.

## Method

Solve the smallest possible surface, harvest the token/cookie, then continue over pure HTTP.
The goal is never "run a browser forever" — it is one solve, then cheap requests.

## Step 0 — know which wall you are behind

```python
import re
t = html
if "turnstile" in t:                    kind = "cloudflare-turnstile"
elif "hcaptcha.com" in t:               kind = "hcaptcha"
elif "recaptcha/api2" in t:             kind = "recaptcha-v2"
elif "recaptcha/enterprise" in t:       kind = "recaptcha-v3"
elif "cf-challenge" in t or "just a moment" in t.lower(): kind = "interactive-challenge"

m = re.search(r'data-sitekey="([^"]+)"', t) or re.search(r"sitekey['\"]?\s*[:=]\s*['\"]([0-9a-zA-Z_-]{20,})", t)
sitekey = m.group(1) if m else None
```

Token field names: Turnstile → `cf-turnstile-response`, reCAPTCHA v2/v3 → `g-recaptcha-response`,
hCaptcha → `h-captcha-response`. Wrong field = silent reject, not an error message.

## Step 1 — local sidecar (check it is alive first)

```bash
curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8877/health
```

Last verified on this host: **down (curl exit 000, no listener)**. Start the service before
assuming it exists, then read its real API surface instead of guessing routes:

```bash
curl -s http://127.0.0.1:8877/                  # index / docs
curl -s http://127.0.0.1:8877/openapi.json | head -c 2000
```

Drive only documented endpoints.

## Step 2 — paid API fallback (documented endpoints)

2Captcha text protocol:

```bash
curl -s "https://2captcha.com/in.php" -d "key=$KEY" -d "method=turnstile" \
  -d "sitekey=$SITEKEY" -d "pageurl=$PAGE" -d "json=1"
curl -s "https://2captcha.com/res.php?key=$KEY&action=get&id=$ID&json=1"
```

CapSolver JSON task API:

```bash
curl -s https://api.capsolver.com/createTask -H 'content-type: application/json' \
  -d '{"clientKey":"'$KEY'","task":{"type":"AntiTurnstileTaskProxyLess","websiteURL":"'$PAGE'","websiteKey":"'$SITEKEY'"}}'
curl -s https://api.capsolver.com/getTaskResult -H 'content-type: application/json' \
  -d '{"clientKey":"'$KEY'","taskId":"'$TID'"}'
```

Wait for `status: ready` / `solution.token`. A `processing` loop past ~2 minutes is a failure —
abort and change approach instead of polling forever.

## Step 3 — inject the token

```python
token = "0.xxxx"   # from the solver
token_js = token.replace("\\", "\\\\").replace("'", "\\'")
js(f"""(() => {{
  let f = document.querySelector('input[name="cf-turnstile-response"],textarea[name="g-recaptcha-response"]');
  if (!f) {{ f = document.createElement('textarea'); f.name = 'cf-turnstile-response'; document.forms[0].appendChild(f); }}
  f.value = '{token_js}';
  return f.name;
}})()""")
```

Submit through the page's own control (`document.querySelector('form').requestSubmit()`) so the
site's JS runs — posting the field yourself usually fails a server-side bind check.

## Step 4 — harvest and go pure-HTTP

```python
cookies = {c["name"]: c["value"] for c in cdp("Network.getAllCookies")["cookies"]}
```

Save beside the solve: `cookies.json` (`chmod 600`), the UA string, the egress IP, a WIB
timestamp. `cf_clearance` is bound to IP + UA + TLS fingerprint — replay with the same
`curl_cffi` impersonate profile and the same IP or it dies instantly.

```python
from curl_cffi import requests as cr
s = cr.Session(impersonate="chrome", cookies=cookies)
print(s.get(PROTECTED_URL).status_code)
```

## Ephemeral-browser discipline (hard rule)

```python
try:
    ...solve, harvest cookies...
finally:
    js("window.close()")
```

No browser outlives the solve. Verify with `tasklist | grep -iE "chrom|headless"` before
claiming the run is finished.

## What actually changes difficulty

- Headless UA alone trips Turnstile: keep `navigator.webdriver` undefined and a consistent
  `sec-ch-ua` set.
- Solve **once per IP**; repeated solves from one IP raise the difficulty tier.
- Residential egress beats any client-side patch.
- A managed challenge with **no widget** cannot be solved by a token API — that path needs the
  browser lane in `anti-bot-http-ladder`.
- **Detect an unrendered widget before waiting on it:** token field present but its value length
  stays **0** for ~10 s and no `challenges.cloudflare.com` iframe ever appears means the challenge
  script never loaded in this browser — reloading and re-clicking changes nothing. Stop there.
  On a *signup* form the exit is human: hand the account holder the URL plus a disposable
  address/password you prepared, let them pass the check, then open the confirmation link from
  the mailbox you control and finish the account yourself.

## Verification

| Claim | Required proof |
|---|---|
| "solver alive" | `200` from `/health` |
| "token obtained" | token length + prefix recorded, never printed in full |
| "bypassed" | protected URL returns 200 with real content, not a challenge page |
| "no zombie" | `tasklist` shows no leftover headless browser |
