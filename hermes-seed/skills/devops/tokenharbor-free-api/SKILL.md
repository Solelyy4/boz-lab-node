---
name: tokenharbor-free-api
description: "Use when wiring Token Harbor free API into Hermes."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [api, free-tier, provider, tokenharbor, hermes-config]
---

# TOKEN HARBOR FREE API — WIRING

Gateway OpenAI-compatible: `https://tokenharbor.ai/v1` (juga Anthropic-compatible di `https://tokenharbor.ai`).
Satu key untuk 77 model; 4 daripadanya free tier.

## Fakta yang menentukan segalanya

| Fakta | Nilai |
|---|---|
| Model free (Okt 2026) | `deepseek-v4.1-flash:free` · `deepseek-v4-flash:free` · `mimo-v2.6-flash:free` · `mimo-v2.5:free` |
| Had free | 60 req/min · 1,800 req/jam per akaun · 100/min · 3,000/jam per IP · 4 MB/request |
| Allowance | Nilai USD, tetingkap **rolling 7x24 jam** dari request free pertama. Bukan kiraan token. Dashboard tunjuk **peratus**. Baki tak dibawa ke tetingkap berikut |
| Key luput? | Tidak — kekal sampai revoke |

## Urutan setup (jangan lompat)

1. **Daftar + sahkan email.** Tanpa ini API balas `403 email_verification_required`. Signup ada Cloudflare Turnstile ("Quick human check") yang **tak render dalam browser headless** -> langkah ini perlu manusia.
2. **Opt-in free models di dashboard** (Settings/Privacy). Default **OFF**. Tanpa ini: `403 free_models_disabled` walaupun key sah.
3. **Probe** guna `scripts/th_probe.py`: sahkan `/v1/models` 200, kemudian chat setiap model free, baca medan `usage`.
4. **Daftar sebagai custom provider** dalam `config.yaml`:

```yaml
custom_providers:
  - name: tokenharbor
    base_url: https://tokenharbor.ai/v1
    api_key: thk_live_...
    model: deepseek-v4.1-flash:free
    models:
      deepseek-v4.1-flash:free: {}
      deepseek-v4-flash:free: {}
      mimo-v2.6-flash:free: {}
      mimo-v2.5:free: {}
```

5. **Uji melalui Hermes** (bukan cuma curl):

```bash
hermes -z "Balas tepat: OK" -m deepseek-v4.1-flash:free --provider custom:tokenharbor -t ""
hermes -z "Jalankan date dan beritahu output" -m deepseek-v4.1-flash:free --provider custom:tokenharbor -t terminal
```

## Perangkap yang sudah kena

- **Jangan** guna butang *Continue with Google/GitHub* kalau inbox untuk pengesahan tak boleh diakses — pengesahan ikut email OAuth.
- Email pengesahan kadang tak sampai (provider blok / typo). Jalan keluar: mailbox `api.mail.tm` (HTTP API, percuma) yang skrip boleh pantau sendiri, kemudian klik link pengesahan dengan GET biasa.
- `/api/*` di tokenharbor.ai ialah route SPA (balas HTML), bukan REST — jangan tafsir 200 sebagai kejayaan.
- Browser headless: `[name="cf-turnstile-response"]` kekal kosong dan tiada iframe -> signup mustahil tanpa tangan manusia.
- Selepas edit `config.yaml`, sahkan guna `validate_config_structure()` dari `hermes_cli.config` sebelum restart.

## Bila boleh kata "guna sepenuhnya"

Empat model free lulus lima ujian ini (dah diuji live):

| Ujian | Hasil |
|---|---|
| chat 200 | semua 4 |
| streaming SSE | semua 4 (7–70 chunk) |
| tool call `tool_choice:auto` | semua 4 panggil fungsi + argumen betul |
| patuh system prompt | semua 4 |
| output 1,000 token | 544–1,536 token, tak terpotong |

Guna `scripts/th_probe.py` untuk chat; untuk lima ujian penuh guna `scripts/gateway_fulltest.py`
dalam skill `free-llm-api-keys`.

**Jadikan fallback, bukan default** — had 4 MB/request memotong sesi agent panjang:

```yaml
fallback_model:
  - provider: custom:tokenharbor
    model: deepseek-v4.1-flash:free
  - provider: custom:tokenharbor
    model: mimo-v2.6-flash:free
```

Sahkan dengan `hermes fallback list` (cetak primary + rantai).

**Semantik allowance yang selalu disalah faham:** request **tidak** terhad kepada sekali sehari.
Boleh hantar sehingga 1,800 req/jam sepanjang tetingkap; yang reset setiap 7 hari hanyalah
**nilai allowance**, dan jam randik bermula pada request free **pertama**, bukan tengah malam.
Habis allowance = free route tolak request baru sampai tetingkap berikut.

## Trade-off yang WAJIB diberitahu ke BOZ

Laluan `:free` = prompt + jawapan **boleh disimpan, dibaca staf**, dan provider free (DeepSeek/MiMo) **boleh latih model mereka**. Jangan hantar kod sulit/kunci API/data peribadi melalui `:free`. Laluan berbayar (ID tanpa `:free`) tak kena syarat ini.
