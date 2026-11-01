---
name: secret-safe-scripting
description: "Use when a script touches keys: load, mask, ship."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [secrets, dotenv, masking, opsec, credentials, permissions]
    related_skills: [windows-bash-ops, hermes-agent]
---

# Secret-Safe Scripting

## When to Use

Any script that reads an API key, private key, session token, cookie jar, or password file —
and any time output, logs, or a report could carry one of those values.

## Rules (non-negotiable)

1. **Secrets live in `.env`, never in code.** `$HERMES_HOME/.env` is the profile store on this host.
2. **Never print a secret in full** — not to chat, not to a log, not to a traceback.
3. **Files holding secrets are `chmod 600`** and stay outside any synced/shared folder.
4. **One secret, one purpose.** A leaked key must be revocable without breaking other flows.
5. **Never commit.** `.gitignore` gets `.env`, `*.pem`, `*cookies*.json`, `secrets/` before the
   first commit, not after.

## Loading

```python
import os
from pathlib import Path

def load_env(path=None):
    p = Path(path or os.path.expandvars(r"$HERMES_HOME/.env"))
    if not p.exists():
        return
    for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

load_env()
key = os.environ["SOME_API_KEY"]      # KeyError beats a silent None
```

Never `source .env` in bash on this host — quoting and CRLF from Windows editors break values
(`\r` becomes part of the key). Load in python instead.

## Masking

```python
def mask(v, show=4):
    if not v: return "<empty>"
    v = str(v)
    if len(v) <= show * 2:
        return "*" * len(v)
    return v[:show] + "*" * (len(v) - show * 2) + v[-show:]

print(f"using key {mask(key)}")      # sk-a************9f2c
```

Apply mask at the **boundary**: one masked print, then pass the raw value around internally.

## A file write that cannot leak

```python
def write_secret(path, value):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(value, encoding="utf-8")
    try:
        p.chmod(0o600)          # partially a no-op on some Windows FS; still attempt
    except OSError:
        pass
    return p
```

Verify what the OS actually granted:

```bash
stat -c '%a %n' file            # msys/linux
icacls file                     # windows, when stat lies
```

## Scrubbing logs before they ship

```python
import re
PATTERNS = [
    r"0x[a-fA-F0-9]{64}",                              # private key
    r"sk-[A-Za-z0-9_\-]{16,}",                         # openai-style
    r"gh[pousr]_[A-Za-z0-9]{20,}",                     # github
    r"eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}",   # jwt
    r"(?i)(api[_-]?key|token|secret|passwd|password)\s*[=:]\s*\S+",
]

def scrub(text):
    for p in PATTERNS:
        text = re.sub(p, "[REDACTED]", text)
    return text
```

Run `scrub()` on anything that leaves the process: log lines, error messages, report bodies,
commit messages, screenshots of a terminal.

## Failure paths leak the most

- `requests` exceptions include the URL — a key in a query string lands in the traceback.
  Put credentials in headers, not query strings.
- Shell history: prefix sensitive commands with a space under `HISTCONTROL=ignorespace`.
- Subprocess argv is visible in the process table — pass secrets by env or stdin, not argv.
- Crash dumps and `pip`/`npm` debug logs record env; scrub before attaching to a report.

## Rotation drill

1. Revoke at the provider first, then replace locally (revoke-first avoids a window where the
   old key still works and the new one is already in the wild).
2. Update `$HERMES_HOME/.env`, re-run the smoke test, confirm the new key authenticates.
3. Purge the old value from logs and shell history.

## Verification

| Claim | Proof |
|---|---|
| "key loaded" | masked print showing prefix/suffix only |
| "file locked down" | `stat -c '%a'` output = `600` |
| "no leak in output" | `scrub(log)` shows `[REDACTED]`; raw search returns nothing |
| "rotated" | new key authenticates (HTTP 200 from an authenticated endpoint) |
