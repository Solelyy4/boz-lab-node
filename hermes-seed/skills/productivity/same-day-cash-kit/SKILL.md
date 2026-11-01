---
name: same-day-cash-kit
description: "Use when you need cash this week: sell a kit today."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [fast-cash, offer, pricing, malaysia, invoice, digital-product, whatsapp]
    related_skills: [invoice-and-report-pipeline, malaysian-accounting-compliance, digital-product-storefront]
---

# Same-Day Cash Kit

## When to Use

BOZ needs money fast and wants the agent to do the work: produce a **sellable asset today** — a
finished sample, a price sheet, a one-page guide, and the exact WhatsApp messages — so selling is
copy-paste, not design work.

## Speed ranking (honest, Malaysia, no capital)

| Lane | Time to first RM | Effort after setup |
|---|---|---|
| Service you can already deliver (invoice/e-Invoice setup for a small kedai) | **1–5 days** | low, one client at a time |
| Template/product to people who already know you (campus, family business circle) | **2–7 days** | low, one-off build |
| Freelance micro-gig (data cleanup, scraping, slide deck) | 3–10 days | medium |
| Bug bounty | 2–8 weeks | high |
| Content channel / airdrop farming | months | very high |

Anything needing platform onboarding (Billplz/ToyyibPay/Shopee) adds 1–7 days of waiting. For
day-one collection use **DuitNow QR to your own account** and fulfil manually — slower per sale,
zero setup delay.

## What the kit contains

```
kit/
  Template-Invois-Kedai.xlsx      editable invoice with SST line + totals that self-check
  Panduan-E-Invoice-1-Muka.pdf    one-page buyer-facing guide (proves competence)
  Harga-Dan-Pakej.md              pricing, scope, refund line
  Tawaran-WhatsApp.txt            3 messages: cold, follow-up, close
```

Generate it:

```bash
python "$HERMES_HOME/skills/productivity/same-day-cash-kit/scripts/make_kit.py" \
  --out "$HOME/OneDrive/Desktop/cash-kit" --name "<your name>" --phone "<wa number>"
```

All four files land in one folder; send the PDF + xlsx as the sample, paste the messages one by one.

## Offer that closes (the three numbers that matter)

```
Setup        RM150   — template + chart of accounts + 1 hour onboarding
Monthly      RM100   — invoice run + sales report + e-Invoice reminders
Walk-away   RM80/mo  — floor price; below this the support load eats the margin
```

Price the **outcome** ("invois siap, laporan tiap bulan, tak kena denda e-Invoice"), never the file.

## Sell sequence (this order)

1. **List 10 people who already trust you** — family businesses, campus staff, kedai near you.
2. Send message 1 (cold, value-first, one question) — no attachment on the first touch.
3. Anyone who replies gets the PDF sample, then the xlsx with their shop name filled in.
4. Close with message 3: price + a start date ("boleh mula Isnin" beats "bila-bila").
5. Collect by DuitNow QR, deliver within 24h, ask for one referral — that is the compounding step.

## Customisation rule

Before sending, replace every placeholder: shop name, SST status (registered or not), invoice
prefix, and goods-vs-services (it changes the tax wording). A generic file reads as a template; a
file with their name reads as work already done.

## Verification before quoting a price

| Claim | Proof |
|---|---|
| "template works" | open the xlsx, totals row computes, difference cell = 0 |
| "guide is accurate" | every rate/date carries its source page; no remembered numbers |
| "ready to send" | 4 files exist with sizes, placeholders replaced |

## Pitfalls

- Selling "AI service" scares small owners — sell "invois siap + laporan bulanan".
- Never promise e-Invoice filing on their behalf before their TIN/intermediary access is confirmed.
- One client's data never sits in another client's file — one folder per client.
- Collect before delivering the customised version; the generic sample is the free hook.
