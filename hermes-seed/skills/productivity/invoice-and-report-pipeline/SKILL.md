---
name: invoice-and-report-pipeline
description: "Use when making invoices/reports: xlsx, PDF, QR."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [invoice, xlsx, pdf, qr, duckdb, reportlab, deliverable]
    related_skills: [digital-product-storefront, malaysian-accounting-compliance, xlsx]
---

# Invoice & Report Pipeline

## When to Use

Producing a client-facing deliverable from data: invoice, statement, schedule, sales report,
dashboard export. One script emits the auditable workbook, the PDF, the payment QR, and a
verification query — instead of four manual steps that drift apart.

## Installed stack (verified on this host)

| Job | Package | Version |
|---|---|---|
| workbook with formulas | `openpyxl` / `xlsxwriter` | 3.1.5 / 3.3.0 |
| PDF | `reportlab` | 5.1.0 |
| PDF read/merge/extract | `pypdf` / `pdfplumber` | 6.21.3 / 0.11.10 |
| QR | `qrcode` | 8.2 |
| charts | `matplotlib` (Agg) | 3.11.2 |
| query verification | `duckdb` | 2.0.0 |
| docx / pptx | `python-docx` / `python-pptx` | 1.2.0 / 1.0.2 |
| templating | `jinja2` | 3.1.6 |

## The four-artifact pattern

### 1. Workbook: Input / Calc / Output, difference cell = 0

```python
from openpyxl import Workbook

wb = Workbook(); inp = wb.active; inp.title = "Input"
inp.append(["item", "qty", "unit_price", "discount"])
rows = [("workbook", 1, 49.0, 0.0), ("checklist", 3, 15.0, 5.0)]
for r in rows:
    inp.append(list(r))

calc = wb.create_sheet("Calc")
calc.append(["subtotal", "=SUMPRODUCT(Input!B2:B3,Input!C2:C3)-SUM(Input!D2:D3)"])
calc.append(["rate", 0.08])
calc.append(["tax", "=ROUND(B1*B2,2)"])
calc.append(["total", "=B1+B3"])

out = wb.create_sheet("Output")
out.append(["Subtotal", "=Calc!B1"])
out.append(["Tax", "=Calc!B3"])
out.append(["Total", "=Calc!B4"])
out.append(["Difference (must be 0)", "=ROUND(Calc!B4-(Calc!B1+Calc!B3),2)"])
wb.save("invoice.xlsx")
```

**openpyxl writes the formula string, not a cached value.** The cell shows `=SUMPRODUCT(...)`
until Excel/LibreOffice opens the file and calculates. Verify in code instead:

```python
from openpyxl import load_workbook
wb = load_workbook("invoice.xlsx")
assert wb["Calc"]["B1"].value.startswith("=SUMPRODUCT")
subtotal = sum(q * p for _, q, p, _ in rows) - sum(d for *_, d in rows)   # cross-check
```

### 2. PDF with a payment QR

```python
import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

qr = qrcode.make(f"https://pay.example/inv=INV-1&amt={total}")
qr.save("qr.png")

c = canvas.Canvas("invoice.pdf", pagesize=A4)
c.setFont("Helvetica-Bold", 16); c.drawString(50, 800, "INVOICE INV-1")
c.setFont("Helvetica", 10)
c.drawString(50, 760, f"Total payable: RM{total:.2f}")
c.drawImage("qr.png", 420, 690, width=110, height=110)
c.showPage(); c.save()
```

reportlab 5.x keeps the classic `canvas` API — `drawString` takes points from the **bottom-left**,
so `y=800` on A4 is near the top. Getting that wrong puts the header off-page, not in the wrong
place.

### 3. Verify the numbers in SQL, not by eye

```python
import duckdb
con = duckdb.connect()
con.execute("CREATE TABLE sales(item VARCHAR, qty INT, price DOUBLE, disc DOUBLE)")
con.executemany("INSERT INTO sales VALUES (?,?,?,?)", rows)
print(con.execute("SELECT ROUND(SUM(qty*price)-SUM(disc),2) FROM sales").fetchone()[0])
```

If the workbook total and the duckdb total disagree, the workbook is wrong — the formula range is
the usual culprit (an appended row outside `B2:B3`).

### 4. Chart for the summary page

```python
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, ax = plt.subplots(figsize=(6, 3.2))
ax.plot(prices, margins, marker="o"); fig.tight_layout()
fig.savefig("chart.png", dpi=120)
```

`matplotlib.use("Agg")` before importing pyplot — a GUI backend on a headless script hangs.

## Verified smoke result

Same pipeline executed here produced: `invoice-smoke.xlsx` 6,294 B (3 sheets, formulas stored),
`invoice-smoke.pdf` 9,778 B (1 page, text extractable), `pay-qr.png` 874 B, `margin-chart.png`
24,047 B; python-side totals `169.00 + 13.52 = 182.52`, difference `0.0`, duckdb recomputed
subtotal `169.0`.

## Pitfalls

- Formulas without cached values: openpyxl is fine for delivery, `data_only=True` reads `None`.
  Use xlsxwriter if the file must carry computed values without being opened by Excel.
- `qrcode.make()` returns a PIL image — `.save()` needs a path with a real extension.
- Money as `float` drifts. Format to 2 dp at the boundary and round with `ROUND(...,2)` in-sheet.
- Currency and tax rate belong in one `Calc` cell, referenced everywhere — never typed twice.
- Windows: native tools need `C:/...` paths; the Hermes venv has no `pip` (use uv).

## Checklist

- [ ] Workbook has Input / Calc / Output and a difference cell reading 0
- [ ] Totals cross-checked in code or SQL, not just in the sheet
- [ ] PDF text extractable (`pypdf`) — proves fonts embedded
- [ ] QR encodes the exact amount shown on the PDF
- [ ] Files written to an absolute path, sizes printed as proof
