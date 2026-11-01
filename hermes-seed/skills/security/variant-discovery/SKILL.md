---
name: variant-discovery
description: "Use after one bug: find its siblings before reporting."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [bug-bounty, variants, idor, id-enumeration, endpoint-clustering]
    related_skills: [pentest-web-quickstart, evidence-first-report, bug-bounty-pipeline]
---

# Variant Discovery

## When to Use

Right after you confirm one bug. A single finding is usually a family: the same broken
assumption appears on other endpoints, other roles, other verbs, other tenants. Variant hunting
is the highest-ROI hour in bug bounty — one root cause, several paid reports.

## The six axes of variation

| Axis | Ask | Test |
|---|---|---|
| **Sibling endpoint** | same handler, different path | `/api/v1/invoice/42` → `/api/v2/`, `/api/internal/`, `/api/admin/` |
| **Verb** | same resource, other method | GET → PUT/PATCH/DELETE with the same id |
| **Object id** | other tenant's id | +1/-1, uuid swap, base64 decode → tamper → re-encode |
| **Role** | lower privilege principal | repeat with a second account (never the victim's) |
| **Parameter** | same endpoint, adjacent field | add/remove optional fields, `?include=`, mass-assignment keys |
| **Surface** | mobile app / legacy host | `/api/` → `m.` domain, `api-legacy.`, `graphql` |

## Endpoint clustering from the JS bundle

```bash
curl -s https://target.tld/static/app.js -o app.js
python - <<'EOF'
import re
t = open("app.js", encoding="utf-8", errors="ignore").read()
paths = sorted(set(re.findall(r'["\'](/[a-zA-Z0-9_\-/{}.]{3,60})["\']', t)))
for p in paths: print(p)
EOF
```

Group by first two segments — a cluster of 8 paths under `/api/v2/billing/` means the bug you
found in `/api/v2/billing/invoice/{id}` almost certainly repeats on `receipt/{id}`, `credit/{id}`,
`subscription/{id}`.

## Two-account matrix (mandatory for IDOR/BOLA)

```
A = own account 1, B = own account 2, V = object belonging to B
request            expected   finding if
A reads V          403       200 with B's data        → BOLA read
A writes V         403       200 + state changed      → BOLA write
A deletes V        403       200/no-op claimed        → BOLA delete
anon reads V       401/403   200                      → auth bypass
A lists collection 200 only A 200 includes B          → collection leak
```

Never test with a third party's object. Two own accounts, one proof, zero collateral.

## Id tampering recipes

```python
import base64, json

# numeric offset probes, not brute force
for d in (-2, -1, 1, 2):
    probe(base + str(base_id + d))

# base64 json blob: flip the tenant field, keep the structure identical
blob = json.loads(base64.b64decode(seg + "=="))
blob["tenantId"] = other_tenant
print(base64.urlsafe_b64encode(json.dumps(blob).encode()).decode().rstrip("="))
# signed blob → drop the sig field; if the server accepts it, signature is unverified
```

## Filter and sort leaks

Same root cause, view-layer surface:

- `?sort=password` / `?order=ssn` — field not in the response model, still sortable.
- `?fields=all` / `?include=internal` — projection bypass.
- `?q=` wildcard returning more rows than the UI ever shows.
- `?page_size=100000` — unbounded pagination.

## GraphQL variants

```graphql
# one query, all mutations: does the resolver check the same authz as the REST path?
mutation { updateInvoice(id: "<other>", input: {total: 1}) { id total } }
# interface/union field the UI never asks for
{ node(id: "<other>") { ... on PrivateDoc { body } } }
```

## Triage before writing more reports

Keep a variant only when it is **independently exploitable** by a different request. Ten
identical ids on one endpoint = one finding with a list of affected ids, not ten reports.
Repetition of the same root cause across a cluster is one report with a table.

## Verification per variant

| Claim | Proof |
|---|---|
| "variant exists" | raw response for the variant endpoint, 200 + foreign field |
| "independent bug" | different path/verb and a different fix needed |
| "same root cause" | one-line explanation of the shared broken check |
