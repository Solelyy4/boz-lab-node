# Measuring a provider's real limits behind 9router

9router hides upstream rate-limit headers, and it applies no cap of its own. To answer "what are
my daily limits?" you must ask the provider.

## Procedure

1. **Count healthy connections.** Only `testStatus='active'` rows actually serve traffic.

```python
import sqlite3, json, os
p = os.path.expandvars(r"%APPDATA%/9router/db/data.sqlite")
c = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
n = sum(1 for (d,) in c.execute("select data from providerConnections where provider='mistral' and isActive=1")
        if json.loads(d).get("testStatus") == "active")
print(n, "healthy")
```

2. **Borrow one key and call the provider directly**, dumping headers:

```bash
curl -s -D - -o /dev/null https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"codestral-latest","messages":[{"role":"user","content":"ok"}],"max_tokens":5}' \
  | grep -iE 'ratelimit|retry-after'
```

3. **Multiply.** Per-account numbers × healthy connections = aggregate ceiling (the gateway
   round-robins when `fallbackStrategy: round-robin`).

4. **Load-test to confirm the aggregate is real**, not just arithmetic: 30 concurrent
   completions across the models you care about; every non-200 counts against the ceiling.

## Measured baseline — Mistral free tier

| Header | Value |
|---|---|
| `x-ratelimit-limit-req-minute` | 125 |
| `x-ratelimit-limit-tokens-minute` | 625,000 |

With 32 healthy accounts: **4,000 req/min**, **20,000,000 tokens/min**. 30 concurrent requests
across three models returned 30/30 in ~15s with no 429, which matches the arithmetic.

## What these numbers do NOT tell you

Monthly quotas are not in the headers. A 24-hour projection (req/min × 1440) is a theoretical
ceiling, not an entitlement — vendor monthly caps bind first. State it that way instead of
promising a daily figure the headers never contained.

## Raising the ceiling

| Lever | Effect |
|---|---|
| Add another account/connection | + per-account limits (Mistral: +125 req/min, +625k tok/min) |
| Upgrade the vendor plan | raises the per-account header values |
| Raise local app caps | changes nothing upstream — see the consuming app's own cap keys |

The local app's caps must sit *below* what the upstream can actually sustain for the window you
care about; a cap far above the aggregate is cosmetic and removes the only brake on a runaway
loop hammering vendor accounts.
