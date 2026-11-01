---
name: politeknik-exam-forecast
description: "Use when prepping polytechnic exams: mine past papers."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [politeknik, exam, past-papers, dpa, accounting, revision, malaysia]
    related_skills: [malaysian-accounting-compliance, pdf, invoice-and-report-pipeline]
---

# Politeknik Exam Forecast

## When to Use

Preparing for a Politeknik Malaysia final exam and you want **evidence-based priorities** instead
of reading the whole module: which topics keep appearing, what question shapes repeat, and what to
practise first. Works for any course code (DPA, SPP, DBM, DBS...), any department.

## Honest scope — read this before promising anything

**No skill, model, or tool can know the questions of an exam that has not been sat.** A paper for
Sesi 1 2026/2027 does not exist until it is printed, and leaked papers are not a thing this skill
provides. What it produces is a **forecast**: topic weights and question archetypes derived from
*public* past papers of the same course code, cross-checked against the course outline.

Every output must say: "forecast from N past papers covering sessions X–Y", never "soalan yang
akan keluar".

## Where the real papers live (verified 27 Oct 2026 WIB)

| Resource | URL |
|---|---|
| Repository root | `https://repositori.mypolycc.edu.my/jspui/` |
| Search by course code | `/jspui/simple-search?query=DPA10183` |
| Item page | `/jspui/handle/123456789/<id>` |
| PDF bitstream | `/jspui/bitstream/123456789/<id>/1/<CODE>.pdf` |
| Exam timetable (session dates) | `pmm.mypolycc.edu.my/images/pdf/exxem/...` |

Working example verified end-to-end: `DPA10183 BUSINESS ACCOUNTING` → 8+ papers across sessions;
handle `123456789/6492` → PDF 376 KB, 10 pages, header reads
`PEPERIKSAAN AKHIR SESI II : 2024/2025 … Subjektif : 4 Soalan … MASA : 2 JAM`.

Departments publish under their own collections (`JABATAN PERDAGANGAN (JP)`, `JMSK`, etc.), so the
same course code can appear from several polytechnics — that is a feature: more sessions, more
signal.

## Step 1 — harvest

Use the bundled script (stdlib + `pdfplumber`, both installed):

```bash
python "$HERMES_HOME/skills/productivity/politeknik-exam-forecast/scripts/harvest_papers.py" \
  --code DPA10183 --out "$HOME/exam/DPA10183"
```

It prints every paper found with its session, saves `*.pdf` and `*.txt` per paper, and writes
`index.json`. Re-run per course code; one folder per subject.

## Step 2 — extract and cluster questions

```python
import json, re, pathlib, collections
txts = [p.read_text(errors="ignore") for p in pathlib.Path("exam/DPA10183").glob("*.txt")]

# question markers used by politeknik papers: SOALAN 1 / (a) / (i)
qs = []
for t in txts:
    for m in re.finditer(r"(?m)^\s*(?:SOALAN|QUESTION)\s*([1-9])\b", t):
        qs.append(t[m.start(): m.start() + 1600])
print(len(qs), "question blocks")
```

Then tag each block against the subject's topic vocabulary and count. Frequency across **distinct
sessions** matters more than raw count — one topic repeated four times in one paper is one data
point, not four.

| Signal | Weight |
|---|---|
| appears in ≥70% of sessions | core — expect it |
| appears in 40–69% | likely |
| appears once, in the newest paper | watch — new syllabus drift |
| appears only in old papers (pre-syllabus change) | low |

## Step 3 — accounting archetypes (DPA / SPP family)

Papers in this family recycle a small set of task shapes. Match each harvested question to one:

| Archetype | Typical ask |
|---|---|
| Journal & ledger | record transactions, post to ledger, balance off |
| Trial balance | extract TB, find and correct errors (suspense account) |
| Adjustments | accruals, prepayments, depreciation, bad debts, provision |
| Financial statements | SOFP / SOPL for sole trader, partnership, or company |
| Bank reconciliation | adjusted cash book + reconciliation statement |
| Depreciation schedule | straight line vs reducing balance over N years |
| Control accounts | sales ledger / purchases ledger control |
| Cost accounting | material/labour costing, overhead absorption, job & process costing |
| CVP | break-even units/value, margin of safety, target profit |
| Budgeting | cash budget month by month, production budget |
| Ratio analysis | compute + interpret 4–6 ratios from statements |
| Theory short answers | definition, principle, difference-between, why-it-matters |

If a question matches none of these, it is either a new syllabus item or a trick — flag it
explicitly rather than forcing it into a bucket.

## Step 4 — output format

```
Subject: DPA10183 Business Accounting (Sem 1 2026/2027)
Evidence: 8 past papers, Sesi I 2023/2024 – Sesi II 2024/2025
Format observed: 4 subjective questions, 2 hours, answers in booklet

Topic weights (by session frequency)
  Adjustments + financial statements   7/8 sessions   expect 1 full question
  Journal → ledger → TB                6/8             likely
  Bank reconciliation                  4/8             likely
  Depreciation schedule                3/8             watch
  Theory short answers                 8/8             certain, 10–20 marks

Revision order (highest expected marks per hour first)
  1. ...

Practice set (built from the archetypes, not copied)
  1. ...
```

## Step 5 — verify before handing over

| Claim | Proof |
|---|---|
| "N papers harvested" | `index.json` with one entry per handle, plus file sizes |
| "topic appears in X sessions" | a table mapping session → matched question |
| "format is 4 questions / 2 hours" | quoted header line from the newest paper |
| "syllabus covers this" | course outline (CS/CI) line, or marked "not in outline — verify with lecturer" |

## Pitfalls

- Old papers from a **different syllabus version** skew the forecast — always print the session of
each paper and let BOZ see the spread.
- Scanned PDFs have no text layer: `pdfplumber` returns `None`. Flag it and ask before OCR; no OCR
  binary is installed on this host.
- Repository item pages sometimes list the PDF under a differently-cased filename — read the
  `bitstream` href from the item page instead of constructing it from the code.
- Do not stuff a forecast with 20 "likely" topics. Five ranked topics with evidence beat twenty
  guesses.
- Course outline (CS) carries the **CLO and mark allocation** — that, not the past papers, decides
  which topics can carry a 20-mark question.
