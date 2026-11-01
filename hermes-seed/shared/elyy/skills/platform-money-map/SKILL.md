---
name: platform-money-map
description: "Use when deciding where content money is: platform payout reality."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [monetization, youtube, tiktok, threads, rpm, affiliate, content]
    related_skills: [video-factory, cash-engine, offer-factory, delivery-desk]
---

# Platform Money Map — where the money actually is

## When to Use

Before promising anyone (including yourself) that content will pay. This skill holds the verified
2026 payout reality per platform, the thresholds that gate each payout, and which of those lanes
Hermes can execute end-to-end today.

Every number here carries a dated source. Thresholds move — re-verify before quoting a client.

## Verified payout reality (checked Oct 2026)

| Platform | Pays creators? | Gate | Per 1,000 views |
|---|---|---|---|
| **YouTube long-form (8 min+)** | yes, ads 55% | 1,000 subs + 4,000 public watch hours/12mo | median **$2.30** RPM; education **$10.22**; kids $0.33 |
| **YouTube Shorts** | yes, pooled 45% | 10M Shorts views/90 days (or the 1k+4k route) | **$0.07–0.20** — 3–14% of long-form RPM |
| **TikTok Creator Rewards** | yes, per-view pool | 10k followers + 100k views/30d + eligible country + videos ≥1 min | varies by market; not a MY-first program |
| **TikTok Shop affiliate (MY)** | yes, commission per sale | seller/affiliate account, product in Open Collaboration | % of order value, not views |
| **Threads** | **no** — no fund, no ad share, no tipping in 2026 | none | **$0** direct; funnel value only |
| **Instagram Reels** | no direct MY payout program | — | $0 direct; brand deals only |

Sources: YouTube Help "YPP overview & eligibility" + "Shorts monetization policies"; ClipFlux/AIR
Media-Tech 300-channel Studio study (Oct 2026) for RPM medians and the Shorts-vs-long-form ratio;
TikTok Support "Creator Rewards Program" eligibility page; Threads/Meta monetization statements
(no creator fund in 2026). Re-check each before a client conversation.

## The uncomfortable arithmetic

```
1,000,000 Shorts views  ≈ $70–200
1,000,000 long-form views ≈ $2,300 (median), $10,220 (education)
1 client paying RM300/month for 12 shorts = 1,500,000 Shorts views of equivalent payout
```

That single line decides the strategy: **content is the distribution, service and product are the
revenue.** A channel is a lead generator that occasionally pays ad revenue; it is never the first
ringgit.

## Four lanes, ranked by days-to-first-ringgit

| # | Lane | First RM | Gate | Hermes executes |
|---|---|---|---|---|
| 1 | **Video repurposing service** for local businesses (12 shorts/mo) | **1–7 days** | none | `video-factory --batch`, client folder per shop |
| 2 | **TikTok Shop affiliate** clips for products already selling | 3–14 days | affiliate account + product pick | `video-factory` + product page recon |
| 3 | **Own digital product** funnel (Threads/TikTok → RM29 kit) | 7–30 days | offer + payment rail | `offer-factory` + `delivery-desk` |
| 4 | **Long-form education/finance channel** (own ad revenue) | 60–180 days | YPP thresholds | `video-factory --aspect 16:9`, 8-min episodes |

Rule: run lane 1 for cash now, lane 3 in parallel because it compounds, and only start lane 4 if
BOZ wants an asset rather than income this month.

## What Hermes can and cannot do per platform

| Task | Can (verified) | Cannot (honest) |
|---|---|---|
| Script → narrated captioned MP4 | yes, `video-factory`, ffmpeg + edge-tts | — |
| Batch 12 videos | yes, ~1 min compute per video | — |
| Metadata/title/hashtag set | yes, emitted per video | — |
| Upload to TikTok/YouTube | needs session cookie or official API + OAuth | no credential-free upload |
| Read analytics | only with logged-in session or API | no public analytics API |
| Auto-reply on Threads | needs session; ToS risk | not worth the ban |
| Buy followers / fake views | **never** — voids every program above | — |

So the honest delivery shape is: **Hermes produces the files + metadata + schedule; publishing is
one human tap or one authenticated API call.** Sell the production, not the posting.

## Objection handling for the service lane

| Owner says | Answer |
|---|---|
| "Saya tak larat nak rakam" | "Saya hantar fail siap. Awak tekan upload, 30 saat." |
| "AI video nampak murah" | show the sample: brand colour, real numbers, Malay captions — not stock AI slop |
| "Berapa lama?" | "12 video setiap bulan, batch pertama dalam 48 jam." |
| "Boleh dapat views?" | never promise views; promise **12 finished videos on time** |

## Compliance edges that kill accounts

1. **Reused-content policy** — pure template + TTS with no original angle gets limited on YouTube.
   Fix: real numbers, real local examples, one opinion per video.
2. **TikTok Creator Rewards** requires original content ≥1 min and an eligible country; do not
   promise MY creators that program as income.
3. **Affiliate disclosure** must be visible in the first line of the caption.
4. **Client footage** stays in that client's folder, never reused in another account.
5. **AI voice + claims about money** — no guaranteed-return language, no fake testimonials.

## Verification gates

| Claim | Proof |
|---|---|
| "video siap" | ffprobe duration/codec/resolution + frame check + audio mean_volume not -91 dB |
| "12 shorts bulan ini" | 12 folders each with video.mp4 + metadata.md |
| "klien bayar" | ledger row in `cash_engine.py report` with ref |
| "platform bayar" | payout screenshot from the platform dashboard, not a third-party estimate |
