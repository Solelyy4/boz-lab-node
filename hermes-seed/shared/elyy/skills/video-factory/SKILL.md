---
name: video-factory
description: "Use when making faceless videos to sell: shorts and long-form from text."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [video, faceless, shorts, tiktok, youtube, ffmpeg, tts, monetization]
    related_skills: [platform-money-map, cash-engine, offer-factory, programmatic-video]
---

# Video Factory — text in, publishable video out

## When to Use

BOZ wants video output that can be posted or sold: a vertical short for TikTok/Reels/Shorts, a
long-form 16:9 for YouTube ad revenue, or 12 shorts for a client who pays for repurposing. One
command does narration, captions, background, brand mark, and metadata — no editor, no browser.

## What it actually does

```
script.txt  ->  edge-tts narration (ms-MY / id-ID / en voices)
            ->  caption chunks split at sentence/word boundaries
            ->  ASS subtitle track with per-chunk timing proportional to characters
            ->  PIL generated background (gradient + title lockup + brand)
            ->  ffmpeg burn-in, H.264 + AAC, yuv420p, faststart
            ->  MP4 + captions.srt + metadata.md + manifest.json
```

## Commands

```bash
V="$HOME/AppData/Local/hermes/shared/elyy/skills/video-factory/scripts/video_factory.py"

# vertical short, Malay voice
python "$V" --script hook.txt --out out/short1 --aspect 9:16 \
  --title "3 KESILAPAN KIRA CASHFLOW" --brand "@akaun_kedai" --voice ms-MY-OsmanNeural

# long-form 16:9 for ad revenue (8 min+ carries mid-rolls)
python "$V" --script episode.txt --out out/ep1 --aspect 16:9 --title "CASHFLOW KEDAI" --theme paper

# batch: every .txt in a folder becomes one short
python "$V" --batch scripts/ --out out/batch --aspect 9:16 --brand "@akaun_kedai"
```

Outputs per video: `*.mp4`, `captions.srt`, `captions.ass`, `bg.png`, `metadata.md`, `manifest.json`.

## ffmpeg invocation rules (host-verified)

Four details decide whether a batch renders once or takes an afternoon.

1. **Resolve the binary explicitly.** `export FFMPEG_DIR="$HOME/AppData/Local/hermes/tools/ffmpeg-9.0.1-win32-x64/bin"` before any run. The script falls back to `PATH` then to that bundled path, but an unset path on another host becomes "ffmpeg not found" halfway through a 12-video batch.
2. **Burn subtitles with `cwd` = the output folder.** `subtitles=captions.ass` only resolves as a bare relative filename; a Windows path inside a filter graph needs `C\:/...` escaping and otherwise fails with an unrelated-looking error. Run ffmpeg with `cwd=<outdir>` and leave the name bare.
3. **Still image → video:** `-loop 1 -framerate 30 -i bg.png -i narration.mp3 ... -shortest`. Audio sets the length, but the MP4 container can run ~2s past the audio stream from loop rounding — judge duration from the **audio stream**, not the container.
4. **ASS needs `PlayResX/PlayResY` and one explicit `Style:` line.** Match them to the real output size, `Alignment=2`, `Outline` ≈ size/7, vertical `MarginV` ≈ 22% of height. Without PlayRes, libass scales captions to the wrong size and they land under the TikTok UI.

Throughput on this host: **3 shorts ≈ 53s** end to end (TTS + encode), so a 12-short client batch is ~4 minutes. Batch is the sellable product; single renders are for samples.

Verify with commands, not by opening the file:

```bash
FF="$HOME/AppData/Local/hermes/tools/ffmpeg-9.0.1-win32-x64/bin/ffprobe.exe"
"$FF" -v error -show_entries stream=codec_name,width,height,duration -of default=nw=1 video.mp4  # h264 + aac + aspect
"${FF/ffprobe/ffmpeg}" -hide_banner -i video.mp4 -af volumedetect -f null - 2>&1 | grep mean_volume   # speech ≈ -24 dB, silence ≈ -91 dB
"${FF/ffprobe/ffmpeg}" -ss <half-duration> -i video.mp4 -frames:v 1 -y frame.jpg                            # then vision_analyze it
```

The frame check is the only way to catch "captions rendered but landed off-screen" — ffprobe reports a perfectly valid file with unreadable text. Written duration ≠ watchable video.

## Honest economics (why format matters more than effort)

| Format | Pay per 1,000 views | Gate to get paid |
|---|---|---|
| Shorts | **$0.07–0.20** (3–14% of long-form RPM) | 10M Shorts views / 90d, or 1k subs + 4k hours |
| Long-form 8 min+ | median **$2.30** RPM; education **$10.22** | 1,000 subs + 4,000 public watch hours / 12 months |
| TikTok Creator Rewards | per-view pool, ≥1 min videos | 10k followers + 100k views/30d, eligible country |
| Threads | **no payout in 2026** | none — it is a funnel, not a payer |

Sources: YouTube Help (YPP eligibility), AIR Media-Tech 300-channel Studio study via ClipFlux
(Oct 2026), TikTok Creator Rewards support page, Meta/Threads monetization statements. Re-check
before quoting a number to a client — thresholds move.

**Consequence:** never sell "Shorts monetization" to anyone. Sell (a) client repurposing, (b)
long-form education/finance channels where RPM is real, (c) traffic to a product you own.

## Service that sells today (no platform gatekeeping)

| Offer | Price | Deliverable from this skill |
|---|---|---|
| 12 shorts / month | **RM300–500** | `--batch` run, client logo as brand, captions in Malay |
| 1 long-form episode | **RM450–800** | 16:9, 8–12 min, chaptered script |
| Setup + 1 training hour | **RM150** | template folder + recorded walkthrough |
| Per short, ad-hoc | **RM40** | single run, 24h turnaround |

Sell to: klinik, kedai servis aircond, tuition centre, ejen hartanah, kedai gunting — anyone
already posting badly on TikTok. Pitch line: "12 video sebulan, siap caption, RM300."

## Rules

1. Narration must be a real script — one idea, one number, one action. No "hello guys".
2. Caption chunks ≤ 60 chars; two short lines beat one long line on a phone.
3. Vertical: keep text inside the middle 80% — TikTok UI eats the top and bottom.
4. Never publish the same file to two platforms without changing the first 2 seconds.
5. Client work: one folder per client, logo + palette in `bg` config, never reuse their footage.

## Verification before delivery

| Claim | Proof |
|---|---|
| video plays | ffprobe shows duration > 0, codec h264, resolution matches aspect |
| audio present | ffprobe stream list has one audio stream, not silent (check `volumedetect` mean) |
| captions burned | extract frame at 50% duration, OCR/eyeball shows text |
| on-spec | duration within ±1s of narration length, size < platform limit |
| metadata ready | `metadata.md` has title, description, hashtags, no placeholder |
