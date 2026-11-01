---
name: bounty-autopilot
description: "Use when running bounty work unattended: cron recon."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [bug-bounty, automation, cron, recon, pipeline, unattended]
    related_skills: [bug-bounty-pipeline, recon-surface-map, variant-discovery, exploitability-analyzer, evidence-first-report]
---

# Bounty Autopilot

## When to Use

Running bounty work while nobody is watching: a cron-driven loop that reconnoitres, mines
candidate bugs, triages them, drafts reports, and leaves a submission queue. BOZ reviews the queue;
the labour is already done.

## What can and cannot be automated (read first)

| Leg | Automatable? |
|---|---|
| Scope ingest, recon, endpoint mining | **yes**, fully |
| Candidate generation (you own the accounts) | **yes**, fully |
| Triage: real vs noise | **yes** — `exploitability-analyzer` rubric in code |
| Report drafting | **yes** — template + evidence pack |
| Creating the platform account / KYC | **no** — human, once |
| Pressing submit / accepting payout | **no** by default; API submit only where a program offers one |

So the honest shape is: **agent does 100% of the work, human does two clicks.** Any claim of
"fully passive income" past that point is fiction — say so instead of overselling.

## Pipeline

```
[1 scope]     programs.json  (name, url, scope[], out_of_scope[], account_alias)
[2 recon]     crt.sh + DNS + JS bundle mining  → assets.txt, endpoints.txt
[3 candidates] param/id/verb variants from endpoints → candidates.jsonl
[4 gate]      reachability + baseline diff + rung 0–6 → keep rung ≥3 only
[5 evidence]  raw request/response + timestamp WIB → evidence/<program>/<finding>/
[6 queue]     reports/<finding>.md + findings.db (dedupe by fingerprint)
```

Every stage writes a file. A stage that produced no file did not run.

## Stage 2 — endpoint mining (the workhorse)

```bash
python "$HERMES_HOME/skills/security/bounty-autopilot/scripts/js_endpoint_miner.py" \
  --url https://target.tld --out "$HOME/recon/target" --max-bundles 12
```

It fetches the HTML, follows same-origin script bundles, extracts API-looking paths and absolute
URLs, dedupes, and writes `endpoints.json` + `endpoints.txt`. Re-run it per host; diff the two runs
to see what shipped this week.

## Stage 4 — the gate that keeps the queue clean

Run every candidate through the same five questions as `exploitability-analyzer`, but in code so it
scales:

```python
KEEP = {"rung": 3, "repro": 2}          # rung >= 3 (privesc or worse) and 2 clean reproductions

def keep(c):
    return c["reachable"] and c["controllable"] and c["rung"] >= KEEP["rung"] and c["repro"] >= KEEP["repro"]
```

A queue that ships 40 "missing header" items is worse than one that ships 3 real findings: the
program stops reading.

## Stage 6 — dedupe memory

```python
import sqlite3, hashlib, json
db = sqlite3.connect("findings.db", timeout=10)
db.execute("PRAGMA journal_mode=WAL")
db.execute("""CREATE TABLE IF NOT EXISTS findings(
  fp TEXT PRIMARY KEY, program TEXT, cls TEXT, endpoint TEXT, rung INT,
  status TEXT, seen_at INT, report_path TEXT)""")

def fingerprint(program, cls, endpoint, param):
    return hashlib.sha256(f"{program}|{cls}|{endpoint}|{param}".encode()).hexdigest()[:16]
```

Insert with `INSERT OR IGNORE` — the same bug rediscovered on a later cron run returns
`duplicate` and never reaches the queue twice.

## Cron shape

| Job | Mode | Schedule | Prompt / script |
|---|---|---|---|
| recon | `no_agent` | daily 03:00 WIB (`0 4 * * *` host) | script prints only new assets/endpoints |
| triage | agent | daily 04:00 WIB (`0 5 * * *` host) | "read candidates.jsonl, apply the gate, draft reports for kept items" |
| weekly digest | agent | Monday 09:00 WIB (`0 10 * * 1` host) | summarize queue, flag stale programs |

Set `failure_deliver="local"` on all three, and `continuity=True` on the digest so it does not repeat
last week's items.

## Verification

| Claim | Proof |
|---|---|
| "recon ran" | `assets.txt` + `endpoints.txt` with counts and mtimes |
| "N candidates" | `candidates.jsonl` line count |
| "queue has X" | `findings.db` query output + report files on disk |
| "new since last run" | diff of endpoints between two runs |

## Pitfalls

- **Duplicates kill credibility** — the fingerprint table is not optional.
- **Scope drift**: re-read the program's scope before every report; out-of-scope findings can get an
  account banned.
- **Rate limits**: cap bundle fetches (`--max-bundles`), add jitter, never scan with a scanner.
- **Payout reality**: first payout typically weeks to months; a queue with no payouts after 6 weeks
  means the target selection is wrong, not the tooling.
- Do not auto-submit anything. The queue is for a human decision.
