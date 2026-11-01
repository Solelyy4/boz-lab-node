# Generative video API landscape (for when motion-graphic is not enough)

When the user wants real character animation / anime / watak berjalan, this table maps
the realistic options. Hardware on this host (AMD Radeon integrated, 12 GB RAM, no CUDA)
makes local self-hosting of any generative model impossible — so API or VPS GPU is the route.

## Layer comparison

| Layer | Example | Free? | Quality | Latency | Limit |
|---|---|---|---|---|---|
| Local installable app (free API) | uglylee/free-video-generator (Agnes AI) | Yes (Agnes free tier) | API-dependent, anime style available | Per-clip | Free API quota |
| API (pay-per-clip) | fal.ai, Kling official, ModelsLab | No (signup credits only) | Anime-grade, cinematic | 45-90s/clip | Per-second billing |
| Hugging Face Inference API | damo-vilab/text-to-video-ms-1.7b, cerspense/zeroscope_v2_76w_t2v | Yes (rate-limited) | Moderate, 480p 5s | 45-90s queue | 5-50 clips/month |
| Self-host (open weights) | Wan 2.1, CogVideoX, LTX-2.5 | Yes (your GPU) | High | Render-dependent | NVIDIA 8-24GB VRAM required |
| VPS GPU rental | SimplePod, GPU Mart, VPSTTT | No (monthly/hourly) | Same as self-host | Render-dependent | 8GB+ VRAM for video gen |

## Local installable apps (free API, no GPU)

### uglylee/free-video-generator (Agnes AI backend)

GitHub repo that wraps Agnes AI's free API into a local web app — text-to-video,
image-to-video, keyframes animation, multi-scene with narration + subtitles. No GPU
needed; runs on an ordinary machine with Python 3.10+ and ffmpeg.

**Prerequisites on this host (all present):** Python 3.14 (Hermes venv), Node 24,
ffmpeg 9.0.1, git 2.53.

**Windows install (start.sh is Linux/macOS only — do NOT run it):**

```bash
cd ~/projects && git clone https://github.com/uglylee/free-video-generator.git
cd free-video-generator
python -m venv .venv
.venv/Scripts/python.exe -m pip install --upgrade pip
.venv/Scripts/python.exe -m pip install -r requirements.txt
# start in background
.venv/Scripts/python.exe server.py &
# verify
sleep 5 && curl -s -o /dev/null -w "%{http_code}" http://localhost:8765/  # expect 200
```

The server runs at `http://localhost:8765`. Web UI accepts the Agnes AI API key inline or
via `AGNES_API_KEY` env var. API key is free from `https://platform.agnes-ai.com` →
Developer Console → API Key section (shown once; copy immediately).

**Modes:** Simple (single clip), Creative (multi-scene from idea), Manuscript (script-driven),
Anchor (digital presenter). Visual style presets include Anime, Cartoon, Cinematic.

**Pitfall:** `moviepy>=2.0` in requirements pulls numpy 2.x — if the user has a global numpy
1.x pinned for another tool, the venv isolation prevents conflict. Always use the project
venv, not system Python.

**Limitation:** Output quality is API-dependent (Agnes AI free tier). For anime-grade
cinematic output, this is a prototype layer — combine with fal.ai/Kling for key scenes.

## API providers (pay-per-clip)

- **fal.ai** -- hosts Wan 2.1, MiniMax H3, Stable Video Diffusion. ~$0.05-0.34/sec. Free
  credits on signup (~$5-10). OpenAI-compatible endpoint. Good for prototyping.
- **ModelsLab** -- $21/mo basic, $149/mo open-source unlimited (Wan 2.1, LTX). Single
  REST endpoint, model selected by `model_id`.
- **Kling official** -- 66 credits/day free (no card) = 1 clip 5s. Paid tiers per-second.
  Direct API: `Authorization: Bearer <KLING_API_KEY>`.
- **free.ai** -- self-hosted CogVideoX path runs in daily token pool (30,000 tokens = 1
  clip every 2 days for free accounts).

## Hugging Face free route

```bash
# Free Inference API (rate-limited, queue-based)
# Models: damo-vilab/text-to-video-ms-1.7b, cerspense/zeroscope_v2_76w_t2v
# Endpoint: https://api-inference.huggingface.co/models/<model>
# Auth: Bearer <HF_TOKEN> (free, from huggingface.co/settings/tokens)
```

- 5-50 clips/month depending on model and traffic
- Output: 480p, 5 seconds, sometimes watermarked
- Cold starts 10-30s on unpopular models
- Good for prototyping, not production

## VPS GPU rental (when local hardware is insufficient)

This host has AMD Radeon integrated graphics, no CUDA — local generative video models
(Wan 2.1, CogVideoX, LTX) cannot run. A VPS with NVIDIA GPU is the upgrade path.

| Provider | GPU | VRAM | Price | Model |
|---|---|---|---|---|
| SimplePod.ai | RTX 3090 | 24 GB | $0.14/hour | pay-as-you-go, per-second |
| SimplePod.ai | RTX 4090 | 24 GB | $0.41/hour (Docker) | best for batch rendering |
| GPU Mart | RTX 5060 | 8 GB | $85/month | dedicated, unmetered bandwidth |
| GPU Mart | GT730 (entry) | 2 GB | $21/month | too weak for video gen |
| VPSTTT | GTX 1080 Ti | 11 GB | $60/month | middle ground |
| vps-mart.com | V100 | 16 GB | $229/month | professional tier |

**Decision rule:** for anime video generation, minimum 8 GB VRAM. RTX 5060 ($85/mo) is the
floor for regular use; SimplePod RTX 3090 at $0.14/hour is cheapest for occasional batches
(e.g. 10 hours of rendering = ~$1.40). Deploy <10 minutes for Linux OS.

**What a VPS gives the user:** 24/7 uptime independent of laptop, dedicated GPU for AI/
rendering, public IP for hosting bots/APIs, isolation from the main machine.

## Self-host requirements (for future hardware upgrade or VPS)

| Model | VRAM | Resolution | Notes |
|---|---|---|---|
| Wan 2.1 T2V-1.3B | ~8 GB | 480P | Lightest; runs on almost any consumer NVIDIA card |
| Wan 2.1 I2V-14B-480P | 8-12 GB | 480P | Image-to-video, character animation |
| CogVideoX-2b | ~19 GB (with CPU offload: <4 GB) | 720x480 | enable_sequential_cpu_offload() brings VRAM under 4 GB but very slow |
| LTX-2.5 | CUDA 12.7+, ~66 GB download | up to 4K | AMD ROCm path exists but complex setup |

## Hybrid strategy for app development

```
[App frontend] -> [Backend FastAPI]
                      |-- Layer motion-graphic (this skill) for narration/scene text cards
                      |-- Layer free-video-generator (Agnes AI) for anime-style prototype clips
                      |-- Layer Hugging Face API (free, rate-limited) for prototype clips
                      +-- Layer fal.ai/Kling (paid) for key character-animation scenes
```

Store API keys in `$HERMES_HOME/.env` with `chmod 600`. Never accept keys in chat --
use `freeapi import <file>` or write directly to `.env`.
