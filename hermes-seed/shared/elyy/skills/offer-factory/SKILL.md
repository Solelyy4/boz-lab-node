---
name: offer-factory
description: "Use when BOZ needs a sellable offer built now: assets on disk."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [offer, pricing, digital-product, invoice, cashflow, storefront, malaysia]
    related_skills: [cash-engine, delivery-desk, same-day-cash-kit, malaysian-accounting-compliance]
---

# Offer Factory — build the thing that gets sold

## When to Use

BOZ needs the actual deliverable: a finished, priced, buyer-facing bundle plus the sales page and
the messages, all written to disk. No design work left. Copy-paste, send, invoice.

One command produces seven files. Nothing is a placeholder except the buyer's own details and the
seller's QR image.

## Output

```
money-engine/kit/
  Invois-Kedai.xlsx          invoice + monthly summary, SST line, self-checking totals
  Cashflow-Kedai.xlsx        12-month cashflow, 6 expense heads, margin + breakeven cells
  Panduan-E-Invoice.pdf      one-page buyer-facing guide (competence proof)
  Harga-Dan-Pakej.md         three packages, floor price, refund line, unit economics
  Tawaran-WhatsApp.txt       3 messages: first touch, follow-up, close
  storefront.html            one-page sales page, price + payment + FAQ, works offline
  README-SEND.md             what to send to whom, in what order, today
```

## Command

```bash
python "$HOME/AppData/Local/hermes/shared/elyy/skills/offer-factory/scripts/make_offer.py" \
  --out "$HOME/OneDrive/Desktop/money-engine/kit" \
  --brand "Sole" --phone "60XXXXXXXXX" --price 29

# verification (copy, never the sellable file)
cp -r ~/OneDrive/Desktop/money-engine/kit "$TMPDIR/recalc"
powershell -NoProfile -ExecutionPolicy Bypass \
  -File "<skill>/scripts/recalc_check.ps1" -Dir "$TMPDIR/recalc"
```

Invoke the script with a **native forward-slash path** (`C:/Users/.../make_offer.py`) when the shell
is bash/MSYS: the Hermes venv python is a native Windows binary and does not translate `/c/Users/...`,
so an MSYS path fails with "can't open file 'C:\\c\\Users\\...'".

`--brand` is the seller name shown on the invoice footer and storefront. `--phone` must be full
international form (60...) because it feeds the `wa.me` links. `--price` sets the digital bundle
price used in the storefront and the economics table.

## What to check before sending anything

| Claim | Proof |
|---|---|
| invoice computes | real recalculation, not inspection: run `scripts/recalc_check.ps1 -Dir <copy of kit>` and read the printed totals. Expect difference cell **0** and total = sub + SST |
| cashflow computes | same probe: running-balance chain advances month to month, breakeven cell = fixed / (margin%) |
| PDF is readable | `pypdf` page count == 1 and extract_text() length > 0; no overflow in the table |
| storefront renders | regex the html for leftover `\[[A-Z0-9 \-]+\]` placeholders; price and `wa.me/<phone>` both present |
| economics honest | fee subtracted is the real rail fee, not zero |

**openpyxl writes formulas, it never evaluates them.** `load_workbook(...)` reading `E23` gives the
string `'=ROUND(E20+E22,2)'`, and the cached value is `None` until Excel saves the file. So "totals
compute" cannot be claimed from openpyxl — recalculate with the host spreadsheet engine
(`scripts/recalc_check.ps1`, Excel COM, fills sample values into a **copy** and reads back numbers)
or state plainly that only the formula graph was inspected. Never present a structural check as a
computed result.

Always probe a scratch **copy** (`cp -r kit scratch/recalc`): the sellable workbook must ship blank, and
sample values written into it become a silent defect for the buyer.

## Pricing that survives a fixed fee

```
RM29 digital bundle  -> gateway RM2 + 3%  = RM3.13 fee -> net RM25.87 (89%)
RM19 digital bundle  -> same fee           = RM2.57     -> net RM16.43 (86%)
RM10 digital bundle  -> same fee           = RM2.30     -> net RM7.70  (77%)  <- avoid
```

Whole ringgit only. Anchor at 29 or 49; a `.90` price loses the point to a fixed fee.

## Customisation rule

Replace before sending: brand name, phone, QR image, spec of the buyer's business (kedai runcit /
salon / bengkel - the invoice wording changes), and SST status. A file with their shop name reads
as work already done; a generic file reads as a template.

## Pitfalls

- Do not promise to file e-Invoice on the buyer's behalf before their TIN / intermediary access is
  confirmed. Sell the setup and the template, not the filing.
- One client = one folder. Never let two clients' data share a workbook.
- The free sample is the generic bundle; the paid deliverable is the same bundle with their name
  inside. That difference is the product.
- Regenerate, do not hand-edit: the script is the source of truth, edits to outputs are lost on the
  next run.
- **Literal braces inside an `str.format` template raise `KeyError` at write time.** Message copy,
  JSON snippets and prompt bodies carry `{...}` of their own; escape them (`{{ }}`) or build the
  asset with `str.replace` on `%%TOKEN%%` placeholders. A generator that dies mid-write leaves a
  half-built kit folder — rerun after the fix and re-verify sizes.
- **Never invent the seller's physical facts.** Phone number, DuitNow QR, bank account and SST number
  are facts on BOZ's side. Ship the asset with one obvious placeholder (`60XXXXXXXXX`, `[QR DUITNOW]`)
  listed once in the send sheet, and say so in the report. "BOZ does not want to be involved" means
  do everything that can be generated, then name the single physical input — not fabricate a number
  that makes the first real buyer message bounce.
