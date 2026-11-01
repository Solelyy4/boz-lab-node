---
name: evidence-first-report
description: "Use before claiming a result: prove it or drop it."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [evidence, reporting, honesty, verification, bug-bounty]
    related_skills: [bug-bounty-pipeline, smart-contract-audit, pentest-web-quickstart]
---

# Evidence-First Reporting

## When to Use

Any time a result will be reported: a bug found, a script working, a service up, a page
scraped, a transaction sent. If the sentence contains "berhasil", "works", "done", "deployed"
it needs a proof object attached.

## The claim/proof contract

Every claim is written as:

```
[CLAIM] — [PROOF TYPE]: [VALUE]
```

| Domain | Minimum proof |
|---|---|
| Web/API finding | raw request + raw response, status code, distinctive body marker |
| Bypass (WAF/CAPTCHA/auth) | response difference vs the blocked attempt: status, length, marker |
| Script works | 5 consecutive runs, exit code 0 each, row count / output file on disk |
| Service running | `curl -w '%{http_code}'` = 200 **and** PID + listening port |
| Scrape | rows persisted to disk + 3 sample rows shown |
| On-chain tx | tx hash + block + explorer URL + before/after balance |
| Malware/implant | C2 callback log line with timestamp + persistence artifact path |
| Screenshot-based finding | image file path + WIB timestamp visible in the capture |

## Run artifacts, don't narrate them

```bash
OUT=$TMPDIR/run-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
cmd > "$OUT/stdout.log" 2> "$OUT/stderr.log"; echo "exit=$?" >> "$OUT/stdout.log"
sha256sum "$OUT"/*.log > "$OUT/manifest.txt"
```

The report cites paths, not memories. A reader must be able to re-open the evidence.

## Five-run consistency gate

New script → run it five times. Anything below 5/5 is **NEED MORE HARDENING**, not "flaky":

```bash
for i in 1 2 3 4 5; do ./tool.sh >/dev/null 2>&1; echo "run$i=$?"; done
```

Any non-zero → find the root cause before shipping. A single tolerated failure becomes a
production failure with someone else's deadline attached.

## Severity without self-claiming

- Quote the program's own table (reward tier, CVSS, RFC 9426 rubric), or write
  `Severity: defer to your assessment`.
- Impact = demonstrated, not potential. Reading public data is **information disclosure**,
  not a critical breach.
- No proof of exploitability → label it "hardening / defence in depth", not a vulnerability.

## Report skeleton (engineer to engineer)

```
Title: <bug class> in <endpoint/contract> allows <impact>
Preconditions: <auth level, config, chain, version>
Steps: 1) ... 2) ... 3) ...        (exact, copy-paste runnable)
Observed: <status/response/trace>
Expected: <what correct behaviour is>
Impact: <what an attacker gains, bounded by proof>
Evidence: <file paths, hashes, timestamps in WIB>
Fix: <one concrete change>
Severity: defer to your assessment
```

No preamble, no "I hope this helps", no AI-slop adjectives. First line names the bug.

## Redaction before delivery

- Strip PII to 1–2 records; mask emails except the domain, truncate identifiers.
- Never include a live credential or session cookie — use a masked sample.
- Scrub other tenants' data in screenshots; keep only what proves the bug.

## Anti-patterns

| Anti-pattern | Rewrite as |
|---|---|
| "Exploit jalan, target bocor" | "IDOR on `/api/inv/42` returns 200 + other tenant's invoice JSON — see `evidence/idor-42.http`" |
| "Seems to work" | "5/5 runs exit 0; `rows.csv` has 1,204 lines" |
| "Server up" | "`HTTP 200` from `/health`; PID 8123 LISTEN :8877" |
| "Probably critical" | "Severity: defer to your assessment (program pays P1–P3 for auth bypass)" |

## Final check before sending

1. Every number traceable to a file or command output?
2. Every path absolute and existing?
3. Every URL reachable right now?
4. Every command copy-paste runnable on this host?
5. Any placeholder, TODO, or invented output left in? (must be zero)
6. Failed steps reported raw, with the pivot that followed?
