---
name: delivery-desk
description: "Use when a paid order must ship a file once: idempotent delivery."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [delivery, payments, webhook, idempotent, license, sales-ledger]
    related_skills: [cash-engine, offer-factory, digital-product-storefront]
---

# Delivery Desk — one paid order, one delivery

## When to Use

Money is coming in and files must go out without shipping twice, without missing a buyer, and with
a sales record that survives an audit. Covers DuitNow manual fulfilment, Billplz/ToyyibPay
callbacks, and licence keys.

## The one rule

`INSERT OR IGNORE` on the gateway's order id is the entire safety mechanism. Gateways retry
callbacks. Without a unique-key insert, a retry ships the file twice and issues two licences.

Two corollaries that keep it true in production:

- **Answer HTTP 200 even when delivery raised.** A 5xx tells the gateway the order failed and it
  retries harder; return 200, log the raw body, and reconcile from the dashboard. The money already
  arrived, so the bug is yours to fix, not the gateway's to retry.
- **`--http` in the selftest is not optional garnish.** It fires the real webhook path three times
  and counts rows, which is the only check that exercises the handler rather than the function.

## Commands

```bash
D="$HOME/AppData/Local/hermes/shared/elyy/skills/delivery-desk/scripts/delivery.py"

python "$D" selftest --runs 5 --http      # proof: 3 duplicate callbacks -> 1 delivery, 5x
python "$D" serve --port 8787             # POST /callback  {order_id,email,product,amount}
python "$D" order --order-id A-1001 --email b@x.com --product "Kit Invois" --amount 29 --manual
python "$D" report                        # paid orders, undelivered, revenue
python "$D" verify --order-id A-1001      # license + delivery file on disk
```

DB: `~/money-engine/store/orders.db` (WAL). Delivered payloads land in `~/money-engine/store/outbox/`.
SMTP is optional — set `SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS/SMTP_FROM` and the same order ships
by email; if unset the outbox file is the delivery record and the buyer is handled by WhatsApp.

## Verification gates before taking real money

| Claim | Proof |
|---|---|
| idempotent | `selftest --runs 5 --http` prints `6/6 PASS` (5 function runs + 1 real HTTP path), each run "3 callbacks -> 1 delivery" |
| no lost order | `report` shows paid count == delivered count + undelivered count |
| licence unique per order | two orders -> two different keys, same order -> same key |
| buyer got the file | outbox file exists with order id, or SMTP send returned 250 |
| money reconciled | `report` gross == sum of `cash_engine.py report` gross |

## Failure modes and what to do

| Symptom | Cause | Fix |
|---|---|---|
| duplicate delivery | order id not unique / DB wiped between callbacks | never delete orders.db; back it up before edits |
| callback never arrives | wrong callback URL, HTTP not HTTPS, localhost from gateway | expose via tunnel, verify with `curl -X POST` from outside |
| buyer paid, no order | callback signature rejected silently | log raw body; reconcile against gateway dashboard daily |
| licence collides | missing pepper env | set `LICENSE_PEPPER`, never rotate it mid-campaign |
| email lands in spam | no SPF/DKIM on custom domain | send from a warmed provider, or deliver by WhatsApp |

## Manual fulfilment is not a failure

DuitNow QR has no callback. The honest flow is: buyer sends screenshot -> `order --manual` records
it -> file goes out by WhatsApp -> `report` shows the row. Automate only after volume makes the
manual step the bottleneck, and only with a rail that actually retries a verifiable callback.
