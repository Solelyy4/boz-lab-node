---
name: cash-engine
description: "Use when BOZ needs income fast: pick lane, plan, track to cash."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [income, fast-cash, plan, tracking, malaysia, zero-capital]
    related_skills: [offer-factory, delivery-desk, same-day-cash-kit, digital-product-storefront]
---

# Cash Engine — lane, plan, tracker

## When to Use

BOZ says "jana duit", "nak cash cepat", "start harini". This is the orchestrator: it picks the
lane with the shortest honest path to money, writes a 14-day plan, and tracks real sales so the
report is evidence, not vibes.

It does not sell. It decides, plans, and measures. Assets come from `offer-factory`; payment to
file delivery comes from `delivery-desk`.

## Lane table (honest, zero capital)

| Lane | First RM | Why it wins / loses |
|---|---|---|
| Service to businesses that already know BOZ (invois + e-Invoice setup) | **1–5 days** | highest close rate, needs one conversation |
| Video repurposing for local businesses (12 shorts/mo via `video-factory`) | **1–7 days** | no platform gatekeeping, RM300/client |
| Productised template bundle sold to a warm circle | **2–7 days** | one build, sold repeatedly |
| Freelance micro-gig (data cleanup, deck, scraping) | 3–10 days | marketplace waiting time |
| Paid community / mini-course | 7–21 days | needs audience first |
| Bug bounty | 2–8 weeks | payout latency, not effort |

Default pick when BOZ gives no preference: **service lane first, product lane in parallel** — the
service funds the week, the product compounds.

## Rules that keep it real

1. **One offer at a time.** Two half-launched offers earn less than one that closes.
2. **Price the outcome, not the file.** "Invois siap + laporan bulanan" closes; "template Excel"
   does not.
3. **Collection rail decided before the first message.** DuitNow QR to BOZ's own account = zero
   onboarding delay. Billplz/ToyyibPay only when automated delivery is worth the wait.
4. **No revenue claim without a ledger row.** A sale exists when `cash_engine.py sale` recorded
   amount + channel + date.
5. **Daily cadence beats bursts:** 10 outreach messages a day, every day, until first payment.

## Commands

```bash
PY="$HOME/AppData/Local/hermes/shared/elyy/skills/cash-engine/scripts/cash_engine.py"

python "$PY" plan   --out "$HOME/OneDrive/Desktop/money-engine" --target 1500 --days 14
python "$PY" sale   --product "Setup Invois" --amount 150 --cost 0 --channel duitnow
python "$PY" report
```

`plan` writes `RENCANA-14-HARI.md` (day-by-day, with the exact action and the number to hit).
`sale` writes one row to `ledger.db` (SQLite, WAL). `report` prints revenue, fees, net, margin,
breakeven units, pace vs target, and the best-performing channel — all from the DB.

### Prove the chain without faking revenue

`CASH_HOME` (cash_engine) and `DELIVERY_STORE` (delivery-desk) redirect storage. Run every demo
sale and every selftest against a scratch dir, so the real ledger still reads 0 sales when you
report to BOZ:

```bash
T="$TMPDIR/money-test"
CASH_HOME="$T" python "$PY" sale --product "Kit Invois" --amount 29 --ref TXN-DEMO-001
CASH_HOME="$T" python "$PY" report
DELIVERY_STORE="$T/store" python "$S/delivery-desk/scripts/delivery.py" order \
  --order-id TXN-DEMO-001 --email demo@buyer.my --product "Kit Invois" --amount 29 --manual
DELIVERY_STORE="$T/store" python "$S/delivery-desk/scripts/delivery.py" verify --order-id TXN-DEMO-001
```

A demo row left inside `~/money-engine/ledger.db` becomes a fake sale that inflates every later
report — the ledger is the only truth, so it never carries test data.

## Verification before declaring progress

| Claim | Proof |
|---|---|
| plan exists | file path + line count + today's row matches WIB date |
| sale recorded | `sqlite3 ledger.db "select * from sales"` row with amount + timestamp |
| target pace | `report` shows required/day vs actual/day |
| chain works end to end | demo sale + delivery verify in a scratch `CASH_HOME`/`DELIVERY_STORE`, while the live `report` still says `0 sale` |
| money actually received | bank/DuitNow notification screenshot or transaction ref in `sales.ref` |

Never report "dah jana RM X" from a message that says "ok saya bayar" — only from funds received.

## Pitfalls

- Building the product before naming the buyer = weeks lost. Name 10 buyers first.
- Discounting to close cheapens the offer and pulls in support-heavy clients. Hold the floor.
- Mixing personal and business money in one account makes the report useless — separate account
  or a tagged ledger row per sale.
- A plan without a daily number is a wish. Every day row must carry a count.
