---
name: bug-bounty-pipeline
version: 1.0.0
description: Use when hunting bug bounty — prospecting, recon, report.
---

# Bug Bounty Pipeline

## Alur

```
PROSPEKTING -> FILTER PROGRAM -> BACA RULES -> PETAKAN SCOPE -> RECON -> BUKTI -> DRAFT
```

## Aturan inti

1. Exclude mutlak platform managed: hackerone, bugcrowd, intigriti, yeswehack, openbugbounty, immunefi, hackenproof. Target: LIVE + SELF-HOSTED + kontak langsung.
2. Prospecting pakai web_search, bukan browser manual. Contoh query: `"responsible disclosure" -site:hackerone.com -site:bugcrowd.com`, `site:<target>.com security.txt`.
3. Baca rules dulu sebelum sentuh target. In-scope domain disalin ke `SCOPE.md` sebelum eksekusi.
4. Recon urutan: security.txt -> crt.sh (subdomain dari cert log) -> wayback (endpoint mati) -> JS bundle mining (endpoint tersembunyi + API key hardcoded) -> robots.txt.
5. Bukti wajib sebelum nulis report: screenshot URL + timestamp WIB terlihat, video untuk multi-step, PoC runnable, data 1-2 record (redact PII).
6. IDOR wajib 2 akun sendiri. Jangan sentuh data orang lain.
7. Timebox 3 hari per program. Tak jumpa bug -> pivot.
8. Draft email: engineer-to-engineer, kalimat pertama = nama bug, nol AI slop, severity kutip kriteria resmi (CVSS/RFC 9426) atau tulis `Severity: defer to your assessment`. Simpan `DRAFT-EMAIL.txt` isi subject + body final sahaja.

## Severity discipline

- Data publik terekspos = information disclosure, bukan critical breach.
- Nol self-claim severity tanpa kriteria program.
- Endpoint ter-mapping != vulnerability. Existence != exploitability.

## Counter-audit (claim verification)

Setiap asersi audit lain: ekstrak testable assertion -> probe reproducible -> CONFIRMED / REFUTED / UNVERIFIABLE.

- CORS wildcard TANPA Access-Control-Allow-Credentials != session hijack.
- 401 di semua bulk endpoint = boundary solid, bukan 30 endpoints exposed.
- Framework attribution cek error string, bukan tekaan visual.

## Deliverable

Per finding: description -> evidence verbatim -> impact -> fix spesifik -> effort. Plus section `Not tested` yang jujur.
