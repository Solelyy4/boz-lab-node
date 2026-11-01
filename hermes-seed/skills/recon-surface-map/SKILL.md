---
name: recon-surface-map
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
description: Use when reconning a target — surface map before strike.
metadata:
  hermes:
    tags: [security, recon, osint]
    related_skills: [bug-bounty-pipeline]
---

## When to Use

Use when reconning a target domain/IP — passive recon to full attack surface map before striking.

# Recon & Surface Mapping

## Urutan (passive → active, murah dulu)

### 1. Certificate transparency (free, no auth)

```bash
curl -s "https://crt.sh/?q=%25.<domain>&output=json" | jq -r '.[].name_value' | sort -u
```

### 2. DNS records

A/AAAA/NS/MX/TXT/SOA/CNAME/CAA via nslookup/dig/socket.

### 3. Wayback (endpoint mati)

```bash
curl -s "http://web.archive.org/cdx/search/cdx?url=<domain>/*&output=text&fl=original&collapse=urlkey" | head -200
```

### 4. JS bundle mining (SPA)

- Fetch index.html → extract `<script src>` → fetch JS → regex `/(api|endpoint|/v[0-9]/)[a-zA-Z0-9/_-]+` → router.js → page modules → /api/ call-sites.
- Output: endpoint → method → payload → auth table.
- Regex API keys: `(?i)(api[_-]?key|token|secret|bearer)['\"]?\s*[:=]\s*['\"][a-zA-Z0-9_-]{16,}`

### 5. Edge vs origin

- CDN detection: header fingerprint (cf-ray, x-served-by, x-amz-cf-id).
- Origin IP: DNS history, direct-IP probe + header compare.

### 6. Framework fingerprint dari error string

- `i64 parse error` → Rust/Axum · `Cannot GET /` → Express · template syntax error → engine id.
- Jangan teka dari look — teka dari error.

### 7. Auth boundary matrix

Per endpoint: no-token → 401/403/400/405? Bogus-token → ? Expired → ? Token query vs header vs cookie? Status differential = boundary map.

### 8. CORS matrix

Origin reflection? ACAC presence? Wildcard + credentials = browser blocks credentialed read → session hijack REFUTED. ACAC absent + cookie auth → CSRF chain masih alive.

### 9. Rate limit probe

Burst 20x → 429? Retry-After? Lockout? Absen = brute-force viable.

## Output

Surface map: endpoint inventory + infra map + auth boundary table + top 3 vectors ranked (evidence strength × impact).
