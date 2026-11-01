---
name: text-to-video-longform
description: "Use when generating long text-to-video from a script."
version: 1.1.0
author: BOZ-AGENT
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [video, tts, ffmpeg, longform, youtube, explainer, anime, vps-gpu]
---

# Text → video panjang (1 jam+) tanpa model video

## When to Use

- "buat video dari teks", "video penjelasan", "video 1 jam", "kursus dalam video".
- Bila tiada akses model generatif video (Sora/Veo) — pipeline ini murni ffmpeg + PIL + TTS.

## Cara kerja (arkitektur)

1. Skrip markdown → dipecah ikut `## Tajuk` = satu scene.
2. Setiap scene: satu PNG 1920×1080 dilukis PIL (tajuk + bullet + progress).
3. Narasi: **edge-tts** (percuma, tanpa key) → mp3 per scene.
4. ffmpeg: PNG + mp3 → klip scene (zoom halus `zoompan`), durasi = audio + 0.7s.
5. `concat` semua klip → MP4 akhir (`-c copy`, pantas).

Kunci kepantasan: **satu gambar per scene**, bukan render 86.400 frame. Video 1 jam = 60–90 gambar.

## Guna

```bash
PY="$LOCALAPPDATA/hermes/installs/*/environments/*/venv/Scripts/python.exe"
"$PY" <HERMES_HOME>/skills/media/text-to-video-longform/scripts/build_video.py \
   skrip.md --out hasil.mp4 --style cartoon --voice ms-MY-YasminNeural
```

Format skrip:

```markdown
## Tajuk scene
Ayat narasi yang akan dibacakan oleh suara TTS.
- Bullet 1 (dipaparkan di skrin)
- Bullet 2
```

Style: `clean` (navy), `cartoon` (krim + Comic), `dark` (hitam-hijau).
Suara Melayu: `ms-MY-YasminNeural` (perempuan), `ms-MY-OsmanNeural` (lelaki). Indonesia: `id-ID-GadisNeural`.

## Skala ke 1 jam+

| Metrik | Nilai praktikal |
|---|---|
| Scene untuk 1 jam | 60–80 scene (45–60 saat narasi/scene) |
| Masa render | ~1.5–3× durasi video pada CPU 8-core (1 jam → 1.5–3 jam) — jalankan `background=true` |
| Saiz fail | ~1.1 MB / 30s @1080p25 CRF22 → **~130–180 MB sejam** |
| Had TTS | edge-tts percuma; jangan hantar perenggan > ~1.500 aksara sekali |

Untuk projek besar: pecah kepada 3–5 fail skrip (bab), render berasingan, kemudian gabung:
`ffmpeg -f concat -safe 0 -i senarai.txt -c copy penuh.mp4`.

## Perangkap yang sudah diuji

- `concat.txt` **mesti** path absolut — path relatif diselesaikan ikut folder senarai, menyebabkan `_kerja/_kerja/...` tidak dijumpai.
- ffmpeg di Windows: guna `C:/...` atau `\` asli, jangan `/c/...` (MSYS path tidak diterjemah untuk exe native).
- `zoompan` mahal di 1080p: `fps=25` dan `veryfast` sudah cukup; naik ke `medium` hanya untuk render akhir pendek.
- Audio tiada → klip jadi 2s. Semak `ffprobe` jika TTS gagal senyap.
- Jangan guna `-shortest` tanpa `apad`; audio terpotong di hujung scene.
- Glyph `→` boleh jadi kotak (tofu) pada font Comic/Segoe — guna perkataan "ke".

## Had jujur — dan bila perlu melangkah ke model generatif

- Ini **bukan** penjana video AI: tiada gerakan watak, tiada babak sinematik. Ia motion-graphic dari kad teks + narasi.
- Untuk visual sebenar per scene (gambar/footage), ganti PNG scene dengan imej sendiri — struktur pipeline sama.
- Sari kata (subtitles) belum dibakar; boleh tambah `subtitles=` filter atau SRT berasingan di v2.

## Bila user mahukan watak berjalan / anime sebenar

User yang nampak output motion-graphic akan tanya: "macam mana nak buat watak berjalan?" atau "yang macam cerita anime tu". Ini isyarat mereka sudah melepasi keupayaan pipeline ini. Jangan ulangi cadangan lapisan yang sama. Nyatakan jurang hardware secara terus, kemudian tawarkan lapisan API:

1. **Semak hardware sebelum janji apa-apa** — `nvidia-smi` (CUDA), `wmic computersystem get totalphysicalmemory`, senarai GPU via `Get-CimInstance Win32_VideoController`. Tanpa NVIDIA CUDA + 8GB+ VRAM, model generatif tempatan (Wan 2.1, CogVideoX, LTX) mustahil. AMD Radeon integrated graphics tidak menyokong CUDA.
2. **App lokal percuma (free API, tanpa GPU)** — `uglylee/free-video-generator` (backend Agnes AI). Clone, venv, install, start server di `http://localhost:8765`. Mode Creative/Manuscript dengan visual style Anime. Kunci API percuma dari `platform.agnes-ai.com`. Lapisan pertama sebelum bayar API — lihat `references/generative-video-api-landscape.md` untuk arahan install Windows.
3. **Lapisan API berbayar (pay-per-clip)** — fal.ai (Wan 2.1 / MiniMax H3, ~$0.05-0.34/saat), ModelsLab ($21/bulan), Kling official (66 kredit/hari percuma = 1 klip 5 saat). Kunci API disimpan di `.env` dengan `chmod 600`.
4. **Hugging Face Inference API (free, rate-limited)** — `damo-vilab/text-to-video-ms-1.7b` atau `cerspense/zeroscope_v2_76w_t2v`. 5-50 klip sebulan, queue 45-90 saat, output 480p 5 saat. Sesuai untuk prototaip, bukan produksi.
5. **VPS GPU rental** — SimplePod.ai (RTX 3090, $0.14/jam), GPU Mart (RTX 5060, $85/bln), VPSTTT (GTX 1080 Ti, $60/bln). Minimum 8GB VRAM untuk video gen. Lihat `references/generative-video-api-landscape.md` untuk jadual penuh.
6. **Hybrid strategy** — gabung pipeline ini (narration kartun untuk penceritaan) dengan app lokal/API generatif (untuk babak watak berjalan kunci).

**Pola jawapan yang berkesan**: kenyataan had hardware satu baris → jadual lapisan kos/kualiti → tawarkan bina app jika user mahu. Jangan tinggalkan user tanpa jalan ke hadapan.

> Rujukan: `references/generative-video-api-landscape.md` — peta lengkap lapisan video generatif: app lokal percuma (free-video-generator/Agnes AI), API berbayar (fal.ai, Kling, ModelsLab), Hugging Face free route, VPS GPU rental (SimplePod, GPU Mart, VPSTTT), dan keperluan self-host.
>
> **Pitfall Windows install:** `start.sh` pada repo `uglylee/free-video-generator` hanya untuk Linux/macOS. Di Windows, buat venv manual (`.venv/Scripts/python.exe -m pip install -r requirements.txt`) dan start server dengan `.venv/Scripts/python.exe server.py &`. Jangan jalankan `start.sh` di MSYS.
