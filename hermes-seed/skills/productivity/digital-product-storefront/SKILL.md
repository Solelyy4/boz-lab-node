---
name: digital-product-storefront
description: "Use when selling digital goods: price to delivery."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [digital-products, pricing, license-keys, malaysia, payments, delivery]
    related_skills: [malaysian-accounting-compliance, product-price-monitor]
---

# Digital Product Storefront

## When to Use

Selling anything delivered as a file or access: templates, spreadsheets, e-books, presets,
mini-courses, licence keys. Covers unit economics, MY payment rails, delivery automation,
licence design, and the refund/tax edges that bite small sellers.

## Unit economics first, design second

```
net_per_sale     = price - gateway_fee - platform_fee - tax_you_absorb - delivery_cost
margin           = net_per_sale / price
breakeven_units  = fixed_costs / net_per_sale
```

Rules that keep a small store alive:

1. **Whole ringgit prices**, anchored at RM19 / RM29 / RM49 — not RM19.90, where a fixed fee eats
   the point of the .90.
2. **Fixed fees dominate at low price.** RM2 + 3% on RM10 is 23% of revenue; on RM99 it is 5%.
   Raise the price or bundle.
3. **One hero product, not a catalogue.** Ten half-finished products sell worse than one with
   proof of use.
4. **Charge for the outcome, not the file.** "Cash-flow workbook for a small kedai" beats
   "Excel template" at identical effort.

## Malaysia payment rails

| Rail | Shape | Good for | Watch |
|---|---|---|---|
| **DuitNow QR** (bank/PGW) | QR transfer | local, low volume | no automatic delivery hook on a personal QR — manual fulfilment |
| **Billplz** | hosted bill, FPX + card, callback | automated delivery + invoices | per-transaction fee, bill expiry default |
| **ToyyibPay** | FPX-first, callback URL | cheap FPX collection | callback retries can duplicate — delivery must be idempotent |
| **Stripe / PayPal** | global card | international buyers | MY merchant eligibility and fees differ; check onboarding |

What actually matters operationally: **a verifiable callback that fires once per paid order.**
Design for duplicate callbacks from day one.

## Idempotent delivery service (the core piece)

```python
# delivery.py — one paid order → one delivery, however many callbacks arrive
import hashlib, json, os, sqlite3, time

DB = os.path.expanduser("~/store/orders.db")

def conn():
    c = sqlite3.connect(DB, timeout=10)
    c.execute("PRAGMA journal_mode=WAL"); c.execute("PRAGMA busy_timeout=5000")
    c.execute("""CREATE TABLE IF NOT EXISTS orders(
        order_id TEXT PRIMARY KEY, email TEXT, product TEXT, amount REAL,
        status TEXT, license TEXT, delivered_at INTEGER, raw TEXT)""")
    return c

def on_paid(order_id, email, product, amount, raw):
    c = conn()
    cur = c.execute(
        "INSERT OR IGNORE INTO orders(order_id,email,product,amount,status,raw) VALUES(?,?,?,?,'paid',?)",
        (order_id, email, product, amount, json.dumps(raw)))
    c.commit()
    if cur.rowcount == 0:
        return "duplicate-ignored"          # callback retry, not a new sale
    lic = make_license(order_id, email, product)
    c.execute("UPDATE orders SET license=?, delivered_at=? WHERE order_id=?",
              (lic, int(time.time()), order_id))
    c.commit()
    send_email(email, product, lic)
    return "delivered"

def make_license(order_id, email, product):
    seed = f"{order_id}|{email}|{product}|{os.environ['LICENSE_PEPPER']}".encode()
    h = hashlib.sha256(seed).hexdigest().upper()
    return "-".join(h[i:i+5] for i in range(0, 20, 5))
```

`INSERT OR IGNORE` against a unique order id is the whole trick. Without it, a gateway retry
ships the file twice and issues two licences.

## Licence design that survives sharing

| Level | Mechanism | Effort |
|---|---|---|
| Honesty | buyer name + email watermarked in the file footer | trivial, stops casual resale |
| Key | deterministic key per order, checked at download | low |
| Bound key | key + email, limited activations in your DB | medium |
| Revocable | server-side check per download, revoke list | highest |

Start at watermark + deterministic key. Anything stronger needs a download endpoint you control —
once the file is delivered, the copy is already gone.

## Product page that converts

1. One sentence: who it is for and what changes after they use it.
2. Proof: a real screenshot or a redacted sample of the actual artifact (not a mockup).
3. Exactly what is inside, with counts: "12 tabs, 3 dashboards, 1 tax schedule".
4. Price, and what happens right after payment ("file + licence key by email in 1 minute").
5. Refund line, plainly worded.

## Tax and refund edges (Malaysia)

- Digital products to consumers usually fall inside the service-tax net in current
  configurations — confirm whether **you** or your platform is the taxable person before
  charging or absorbing it.
- Keep an invoice record per sale, with the buyer's TIN for business buyers — it feeds the
  e-Invoice workflow.
- Digital goods are usually non-refundable, but honour genuine double-charge and non-delivery
  immediately. A chargeback costs more than the product.

## Launch checklist

- [ ] Unit economics computed with the real gateway fee, not a guess
- [ ] Callback idempotent (test: fire the same callback 3×, expect 1 delivery)
- [ ] Licence key deterministic and recorded in the DB
- [ ] Delivery email tested against a real inbox (spam folder, SPF/DKIM if self-hosted)
- [ ] Refund / non-delivery path written down
- [ ] Sales record file kept for tax + e-Invoice
