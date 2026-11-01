---
name: malaysian-accounting-compliance
description: "Use for MY accounting: MFRS/MPERS, e-Invoice, SST."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [malaysia, accounting, mfrs, mpers, e-invoice, myinvois, sst, lhdn]
    related_skills: [xlsx, document-to-action-items]
---

# Malaysian Accounting & Compliance

## When to Use

Any Malaysia-context accounting task: financial statements, MFRS/MPERS treatment, LHDN
e-Invoice (MyInvois), SST registration/charging, tax computation, or coursework framing for a
DAC-style diploma. Also use it when converting a generic accounting question into MY practice.

**Rule zero:** rates, thresholds and deadlines change by gazette and Budget. Always state the
figure you used, the date it was valid, and the official page you checked. Never present a
remembered rate as current.

## Source of truth (check these, not memory)

| Topic | Where |
|---|---|
| e-Invoice / MyInvois | `myinvois.hasil.gov.my` (portal + SDK docs), LHDN e-Invoice guideline PDF |
| Income tax, capital allowances | `hasil.gov.my` — public rulings (PR), including e-Invoice rulings |
| SST | `mysst.customs.gov.my` — rate tables, registration threshold, exemption orders |
| Reporting framework | MIA (`mia.org.my`) — MFRS/MPERS adoption, illustrative financial statements |
| Company law / filing | SSM (`ssm.com.my`) — annual return, FS lodgement |

## Framework selection

| Entity | Framework |
|---|---|
| Listed, or entity with public accountability | **MFRS** (full IFRS-aligned) |
| Private entity, no public accountability | **MPERS** (IFRS for SMEs-aligned) |
| Sole prop / partnership / LLP | Not MFRS/MPERS — accounting records + tax computation; MPERS only if elected |

Private-entity transition to MPERS is a one-way election in practice — flag it as a decision,
not a default.

## e-Invoice (MyInvois) — the workflow that actually matters

```
1. Collect      buyer TIN + registration type, item classification code, tax type
2. Validate     submit JSON/XML (SDK or API) → submission UID + long id
3. Notify       LHDN validates asynchronously → poll status
4. Share        QR/long id given to buyer; buyer may reject within the window
5. Consolidate  B2C / receipts may be consolidated monthly (subject to rules + deadlines)
6. Reconcile    cancelled / rejected documents must be corrected, not silently reissued
```

Minimum fields that trip people up: buyer **TIN** (not just SSM number), **classification
code** per line, **tax type** (sales / service / exempt / not-applicable — verify the current
code list), and **unit price vs quantity** consistency after discount.

Practical build: keep one canonical invoice JSON per sale, generate the MyInvois payload from
it, store the returned `submissionUid` + `longId` beside your own invoice number. Never let the
portal be your only record.

## SST mechanics

- Two taxes: **Sales Tax** (goods, at manufacturer/import stage) and **Service Tax** (services).
  They are not VAT — no input credit chain like the old GST.
- Registration threshold differs by category (commonly RM500,000 for general taxable services;
  specific categories differ) — confirm per category and register before crossing it.
- Charging: tax is on the **taxable value**; display it separately on the invoice with the rate
  and your SST registration number.
- Exemptions and rate changes arrive via minister orders — cite the order, not a blog.

Computation pattern (illustrative — confirm the rate is current before use):

```
subtotal      = sum(line_qty * unit_price) - trade_discounts
tax           = round(subtotal * rate, 2)
total_payable = subtotal + tax
```

## Common treatment questions (answer shape)

| Item | Where it goes |
|---|---|
| Deposit received before delivery | liability (contract liability), not revenue |
| Trade discount vs rebate | discount reduces revenue; post-sale rebate is often a refund liability |
| Provision for doubtful debts | expected credit losses (MFRS 9) vs MPERS simplified model — do not mix |
| Capital allowance (tax) vs depreciation (accounting) | two separate schedules, never one ledger line |
| Deferred tax | only from temporary differences; small entities often have none |
| Related-party transactions | disclose; SSM/MFRS disclosure differs from tax transfer-pricing rules |

## Working file pattern

For a schedule or computation, build an `.xlsx` with three sheets so numbers are auditable:

1. `Input` — raw transactions, one row each, with source document reference.
2. `Calc` — formulas only, no hardcoded results.
3. `Output` — the schedule/statement, referencing `Calc`.

Include a totals check (`SUM` of detail = control total) and a difference cell that must read 0.
A schedule whose difference cell is not 0 is not finished.

## Pitfalls

- Quoting a superseded rate — always attach the effective date.
- Treating SST as recoverable input tax (it is not, unlike the old GST).
- Mixing MPERS simplifications into an MFRS set (or the reverse) in one statement.
- Ignoring the e-Invoice rejection window; a rejected document is not a valid invoice.
- Using a buyer's SSM number where a **TIN** is required.
- **Inventing a compliance identifier to fill a field.** MSIC codes, e-Invoice classification
  codes and TINs are lookups against LHDN/SSM tables, not values a generator may guess — a
  plausible-looking code produces a valid-looking invoice that rejects at validation, or worse, a
  wrong return. Leave them as empty, user-supplied inputs and say why.
- **Locking a tax rate into a tool.** Any calculator script must take the rate as a parameter,
  print the rate it used plus a "verify at mysst.customs.gov.my" line in its own output, and stamp
  the generation time — a saved HTML/PDF invoice outlives the order that set the rate.
- Rounding only at the final line instead of per line: SST totals then disagree with the
  per-line display and the invoice fails reconciliation.

## Deliverable checklist

- [ ] Framework named (MFRS / MPERS / non-framework) with the reason
- [ ] Every rate carries an effective date + source page
- [ ] All figures come from a sheet with formulas, difference cell = 0
- [ ] Tax vs accounting differences in separate columns
- [ ] Open questions listed explicitly instead of silently assumed
