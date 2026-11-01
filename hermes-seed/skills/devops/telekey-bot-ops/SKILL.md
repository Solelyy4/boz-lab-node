---
name: telekey-bot-ops
description: "Use when operating the TeleKey bot and AI gateway."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [telegram, bot, gateway, ops, uptime, devops]
---

# TELEKEY-BOT-OPS

## When to Use
- Bot/gateway TeleKey perlu hidup, disemak, atau diubah (upstream, cap, command baru).
- Debugging bot senyap, 409 Conflict di `bot.log`, key ditolak 401, atau metering pelik.
- Kerja perlu kekal hidup selepas sesi Hermes tutup (supervisor, folder Startup, persist).

Satu proses python membawa dua benda: bot Telegram (python-telegram-bot 22) + gateway
OpenAI-compatible, semuanya daripada `C:/Users/zahin/projects/telekey-bot/`:

| Fail | Peranan |
|---|---|
| `telekey.py` | bot polling + gateway ThreadingHTTPServer (env `TELEKEY_PORT`, default 8766) |
| `config.json` | caps (`daily_cap`, `daily_token_cap`) + senarai `upstream[]` |
| `keys.db` | SQLite WAL — api_keys, usage_log, chat_log, chat_usage |
| `run_telekey.bat` | supervisor: python exit → tunggu 5s → semula; log rotate 10MB |
| `bot.log` | semua stdout (banner bot, getUpdates, traceback) |

Token bot dari `$HERMES_HOME/.env` (`TELEGRAM_BOT_TOKEN`); key upstream dari
`api_key_file`/`api_key_env` — muat dengan `load_env()`, cetak dengan `mask()` sahaja.

## 1. Start / stop — urutan wajib

1. **Stop penuh dulu, berperingkat**: kill session supervisor (`process_manage kill`),
   kemudian SEMAKKOSONG: senarai proses dengan `CommandLine -like *telekey*` DAN `netstat`
   port gateway. Dua instance hidup serentak berebut SATU `getUpdates` consumer offset
   (had Telegram) → Conflict 409 yang memutaskan long-poll in flight si bot.
2. **Start**: `terminal(command="cd C:/Users/zahin/projects/telekey-bot && cmd.exe /c run_telekey.bat",
   background=true, persist_on_release=true, notify=true)`. `persist_on_release` yang
   buat bot hidup walau sesi Hermes tutup; jalur boot = salinan `run_telekey.bat` dalam
   folder Startup (`%APPDATA%/Microsoft/Windows/Start Menu/Programs/Startup`).
3. DILARANG bungkus shell (`nohup`/`disown`) — tool menolak wrapper begitu; jangan
   foreground — timeout sesi mematikan pokok proses bot sekali gus.

## 2. Verify — bukti sebelum klaim hidup

- `curl -s http://127.0.0.1:8766/health` → `{"ok":true,"upstreams":N}`.
- `tail bot.log` → streak `getUpdates "HTTP/1.1 200 OK"`; `grep -c 409 bot.log` = 0.
- E2E metering: ambil key dari `keys.db`, POST `/v1/chat/completions` dengan Bearer,
  baca semula `usage_log` melalui **sambungan SQLite baru** (read-after-write) — `tokens` naik.
- **Gate sebelum deploy sebarang edit**: `python telekey.py --selftest` wajib cetak baris akhir
  `SELFTEST: LULUS` (ringkasan `5/5 PASS + ai 5/5 + race + cool + route + plain + parse + xform`)
  + exit 0. Gagal sekali pun = belum siap.

### 2b. E2E Telegram tanpa jadi BOZ

Tidak perlu tunggu BOZ menaip untuk uji laluan pesan→jawapan. Bina `Update` daripada mesej
sebenar Bot API, kemudian panggil handler terus — balasan tetap sampai ke chat sebenar:

```python
from telegram import Bot, Update
m = await Bot(TOKEN).send_message(CHAT, "baca fail C:/.../config.json")   # mesej sebenar
await telekey.handler_text(Update(update_id=int(time.time()*1000), message=m), None)
```

- `m` dari `send_message` membawa `_bot`, jadi `m.reply_text()` dalam handler berfungsi.
- Command handler boleh dipanggil terus: `await telekey.cmd_status(update, None)`.
- Proses bot yang hidup TIDAK terlibat — tiada 409, tiada offset direbut (kita hanya hantar).
- Ujian pantas 3 model: `/bench` (satu completion ringkas setiap tier, 3–5s).
- Ujian penuh: satu kes setiap tier (easy baca fail, medium tulis fail, hard audit), kemudian
  semak `bot.log` baris `agen: model=... tier=...` — itu bukti routing, bukan tekaan.

Harness sedia guna: `scripts/e2e_telegram.py` — jalankan dari folder bot dengan venv Hermes;
ia hantar satu mesej bagi setiap kes ke chat BOZ dan cetak masa setiap satu.

## 3. Tukar upstream / naik cap

1. **Probe dulu**: `GET <base_url>/models` dengan key provider — ID model free tier kerap
   bertukar atau deprecated; pin dari ingatan = 404 senyap dan failover jadi berselang-seli.
2. Edit `config.json`: objek upstream = `{name, base_url, model, api_key_file|api_key_env, timeout}`;
   cap harian pada `daily_cap` / `daily_token_cap`.
3. Restart supervisor (§1), ulang verify (§2).

### 3b. Had harian (caps) — skop dan had selamat

| Kunci `config.json` | Skop | Lalai |
|---|---|---|
| `daily_cap` | setiap kunci API gateway | 20,000 req/hari |
| `daily_token_cap` | setiap kunci API gateway | 5,000,000 token/hari |
| `chat_daily_cap` | setiap `chat_id` | 2,000/hari |
| `agent_daily_cap` | setiap `chat_id` | 200/hari |

- Skop ikut jadual: `chat_usage`/`agent_usage` berkunci `(chat_id, day)`, manakala `daily_cap`
  dibaca dalam `make_gateway()` per kunci. Naikkan dengan edit `config.json` kemudian restart
  supervisor — tiada kod disentuh, tiada migrasi.
- **Cap melebihi kapasiti upstream = kosmetik, bukan kebolehan.** Kira siling sebenar dulu
  (skill `9router-gateway-ops` → `references/measuring-provider-limits.md`). Cap juga brek
  keselamatan: loop agen tanpa cap boleh menghantam akaun vendor sampai disekat. Naikkan
  berperingkat, bukan ke infiniti.
- `race(fanout=2)` hanya menghantar ke dua upstream dengan nilai `speed` terkecil. Letak
  upstream 9router pada `speed` 1 dan 2 → chat terjamin melalui 9router tanpa menyentuh kod
  pemilihan.
- Harness kesediaan model: `scripts/agent_battery.py` — tiga saiz tugasan setiap model, disahkan
  dari fail di disk (bukan kata-kata model). Jalankan selepas sebarang perubahan prompt, profil,
  atau senarai model.

## 4. Tambah command Telegram

- Daftar dalam `main()`: semua `CommandHandler` dahulu, kemudian
  `MessageHandler(filters.TEXT & ~filters.COMMAND, ...)` **mesti LAST** supaya slash
  menang ke atas teks biasa (PTB memilih handler mengikut turutan dalam group).
- `app.add_error_handler(on_error)` kekal dipasang — exception handler (termasuk
  NetworkError masa reply putus) menjadi log, bukan mematikan app.
- Handler PTB async; kerja blocking (requests, subprocess) bungkus `await asyncio.to_thread(...)`
  supaya event loop tak tersekat dan polling tetap jalan.
- Chat AI: hantar 12 mesej terakhir sahaja (`chat_history`, bounding token), meter ke
  `chat_usage` (n + tokens) ikut cap `CHAT_DAILY_CAP`.

## Pitfalls

- **`HERMES_HOME` TIDAK diwarisi** oleh Task Scheduler / watchdog / sesi bukan-Hermes → `load_env()`
  tak jumpa `.env` → bot keluar "TELEGRAM_BOT_TOKEN kosong" setiap 5s. Fix kekal dalam kod+skrip:
  `_hermes_home()` fallback (`%LOCALAPPDATA%\hermes`, `~/.hermes`) + `run_telekey.bat` set
  `HERMES_HOME=%LOCALAPPDATA%\hermes`; exit rc=2 = tunggu **300s** (bukan spam 5s).
- **Watchdog mesti dedupe**: bila bot BLOCKER-loop, `netstat 8766` sentiasa kosong → watchdog
  spawn supervisor baharu tiap 5 minit (3+ pendua bertindan). `watchdog.bat` kini Semak cmd
  `run_telekey.bat` dulu dan keluar jika sudah ada.
- **"waiting for provider" ada DUA punca berbeza — jangan salah tuduh.** (a) Gateway 8766 mati →
  semak `/health` dulu. (b) Gateway hidup tetapi upstream balas 429 yang 9router balut jadi 503 →
  Hermes retry berulang dan desktop tergantung. Punca (b) ialah kes biasa bila model premium
  (large-4) dipilih; lihat seksyen "429 → 503" di bawah untuk pembetulan penuh.
- **`hermes -z` boleh tersekat 300s+ dalam mod user-config** (bootstrap `-h`/`--version` laju,
  `--safe-mode` fail 5s, `gateway status` sihat) — kesan: /agent & /vision timeout. Bot kini
  **auto-fallback ke chat laju** bila err mengandungi "lebih"/"dipotong". Fix penuh = restart
  penuh Hermes Desktop (dijadualkan, bukan semasa sesi aktif).
- **Jangan buat panggilan `getUpdates` manual semasa bot hidup** — merebut offset, memutus
  long-poll (409). Kesihatan = `/health` + `bot.log` sahaja.
- **Dua poller satu token = data bercabang; pilih salah satu dengan sedar.** Telegram benarkan
  satu poller per token, jadi pilihan ialah (a) bot BERASINGAN dengan token baharu, atau
  (b) **penunggu berpagar nadi** pada token yang sama: hos utama tulis nadi setiap minit, nod
  hanya poll bila nadi basi > 3 min, dan lepas balik ~45s selepas nadi pulih. (b) memerlukan
  sifar kerja daripada BOZ tetapi `keys.db` tetap bercabang — kunci yang dicipta melalui Telegram
  semasa laptop mati akan hilang bila laptop hidup semula; beritahu BOZ guna `/getkey` hanya bila
  laptop hidup. Resipi + tiga laluan ujian: skill `free-node-bore-tunnel` →
  `references/single-consumer-standby.md`.
- **Agen di nod perlukan tiga penyesuaian, bukan sekadar salinan fail.** `_hermes_exe()` mesti
  cari `<HERMES_HOME>/bin/hermes` di samping `hermes.exe`; `--profile <nama>` mesti dilangkau bila
  `<HERMES_HOME>/profiles/<nama>` tiada (profil hanya wujud pada pemasangan PC); dan model PC
  tidak sampai ke nod kerana `9router` hidup di `127.0.0.1:20128` — guna
  `TELEKEY_AGENT_PLAN="model|provider,..."` untuk menimpa jadual tier tanpa ubah kod.
  Uji dengan memanggil `_agent_core` sendiri (importlib) dan minta ia jalankan alat terminal:
  jawapan menyebut hostname sebenar + tajuk skill verbatim = binari, tools dan skills hidup.
  Resipi penuh: skill `free-node-bore-tunnel` → `references/hermes-agent-on-node.md`.
- **Belum ada alat ≠ tak boleh buat kerja.** Bukti 1 Nov 2026: model farm (codestral/ministral/
  large-4) semuanya boleh `tool_calls` melalui Hermes — fail benar-benar ditulis ke disk. Kalau
  balasan berbunyi "tiada tools", salahkan **router**, bukan model: semak `needs_agent()`,
  `NO_TOOL_MARK`, dan timeout agen dahulu.
- **Dalam `.bat`, pakai `%SystemRoot%\System32\timeout.exe`** — PATH mesin ini membawa
  GNU `timeout` git-bash yang mentafsir `/t` sebagai selang masa → restart loop crash tepat.
- **Port bebas ≠ poller bebas** — proses bot boleh hidup selepas bind gateway gagal;
  semak senarai proses DAN port bersama sebelum menyatakan bot mati.
- Model provider free & cap harian provider = luar kawalan; yang deterministik hanya cap
  kita dalam `config.json` — jangan janjikan kecekapan luar pada angka dalam sistem kita.
- **Restart bot = beberapa 409 sementara, bukan kerosakan.** Selepas proses lama dibunuh,
  Telegram masih memegang long-poll lama di pihak server ~30–60s; instance baharu dapat
  `409 Conflict` 3–5 kali, kemudian `200 OK` berterusan. Jangan spawn instance ketiga atau
  matikan supervisor sebab ini — tunggu 60s, kemudian bandingkan bilangan `409` baharu
  (menokok = memang ada poller lain; berhenti = normal).
- **Tanya "dah ok?" / "pakai model apa?" = minta bukti, bukan jaminan.** Jawab dengan
  jadual peran→model (chat race · agen hard/medium/easy) + angka yang diukur pada giliran itu
  (health, `grep -c 409`, `--doctor`, latensi per model). BOZ menolak ayat "semua selesai"
  tanpa bukti bernombor.

## Router agen (v6) — punca "model kata tiada tools"

`needs_agent()` hanya meluru ke agen kalau `AGENT_HINT` padan. Set verba asal tak ada
`upgrade`, `naik taraf`, `tambah`, `baiki`, `refactor`, `patch`, `otomasi` — jadi
"upgrade telegram bot" jatuh ke laluan **chat yang memang tiada alat**, dan model jawab
"saya tiada tools" (betul secara literal, salah dari segi tugasan). Dua pembetulan wajib:

1. `AGENT_HINT` mesti mengandungi verba kerja (upgrade|naik taraf|tambah|baiki|betulkan|refactor|
   optimasi|selenggara|migrate|patch|automate|tulis skrip|command baru|debug). Uji dengan
   `needs_agent("upgrade telegram bot") is True` — masuk selftest, bukan ujian manual.
2. `NO_TOOL_MARK` ("tiada tools", "no tools", "tiada akses kepada alat") dikesan pada jawapan
   chat → `_run_ai` naik sendiri ke `_agent_core`. Jangan pulangkan jawapan "tiada tools" ke BOZ.

Timeout `_dispatch` mesti `AGENT_TIMEOUT_S` (300s). Nilai 90s memotong kerja sebenar separuh
jalan, jatuh ke chat, dan hasilnya sama "tiada tools" walaupun router betul.

## Command map

| Command | Fungsi |
|---|---|
| `/getkey` `/keys` `/key` `/usage` `/revoke` | lifecycle key + metering per key |
| teks biasa / `/ai` | **router `_dispatch`**: `needs_agent()` — soalan pengetahuan (QUESTION_SHAPE) → chat race `BM_SYSTEM`; tugasan aksi (AGENT_HINT: github/install/jalankan/fail...) → **agent auto** `_agent_core(BM_AGENT_PREFIX+text)` (had `AGENT_DAILY_CAP` 200/hari, jadual `agent_usage`) |
| `/agent [hard|medium|easy|max]` | manual — subprocess `hermes -z` ikut tier (700/420/360/900s) |
| `/reset` `/status` `/models` `/ping` | memori chat · uptime/gateway · upstream · latency |

**Anti-refusal chat:** `BM_SYSTEM` larang menolak; kalau keluaran kena refleks model
(`REFUSE_MARK` — "tidak dapat membantu" dsb.), `_ai_core` **retry sekali** dengan
`BM_REFUSE_HARD` sebelum pulangkan. Refleks muncul dua kali berturut = log, bukan senyap.

**Race vs sekuens:** chat guna `Upstreams.race()` (ThreadPoolExecutor, FIRST_COMPLETED);
gateway API-key guna `call()` sekuen. Masa ikut provider sihat — malam 31 Okt: groq ~1.1s,
tokenharbor 2.9–54s (jitter), gemini pernah 503 — jangan janjikan milisaat; race ambil
kepantasan SEMANDAING provider sihat pertama. Latensi bukan sahaja nombor: model berfikir
(mimo) boleh 40s+ bila sesak.

**Bukti hidup 31 Okt (upgrade v4):** selftest `5/5 PASS + ai 5/5 + route 6/6 + agent 1/1`
exit 0; E2E tugasan GitHub melalui auto-agent: 52s, balasan BM guna `gh api` live
(star NousResearch/hermes-agent 259,082 — angka API sebenar); post-restart `409 = 0`.

## Bench 3 model 9Router (1 Nov 2026) — kerja sebenar, bukan teori

Semua lulus selepas prompt diberi peraturan teknikal. Angka = masa dinding penuh (subprocess + tools).

| Tugasan | large-4 | codestral | ministral-8b |
|---|---|---|---|
| git clone + baca README | 46.8s | 27.0s | 25.9s |
| GitHub API → simpan fail → sebut angka | 37.9s | 16.6s | 19.2s |
| muat turun raw.githubusercontent → fail | 38.7s | 20.0s | 24.5s |
| tulis fail python + jalankan | 38.0s | 20.9s | 24.0s |
| scrape `<title>` example.com | 26.6s | 13.0s | 12.6s |
| npm install dari GitHub (tarball) | 57.4s | 30.0s | 66.4s |
| pip install git+https (selepas ensurepip) | 70.1s | 40.7s | 35.9s |

Kesimpulan: ketiga-tiganya mampu buat kerja tools. **codestral paling laju dan paling konsisten**;
ministral hampir sama pantas tapi kadang lebih berjela; large-4 paling lambat dan **tidak boleh
diharap** untuk chat (429 + kandungan `thinking` sahaja). Tier semasa: hard=codestral,
medium=ministral, easy=ministral, max=large-4 (opt-in) — tukar melalui `config.json.agent_tiers`
tanpa sentuh kod.

### Resepi install yang terbukti (host ini)

- `git clone https://github.com/USER/REPO.git` — **jangan** `git@github.com:` (publickey ditolak).
  Pembetulan kekal: `git config --global url."https://github.com/".insteadOf git@github.com:`.
- npm dari GitHub: `npm install https://github.com/USER/REPO/tarball/BRANCH` — **jangan**
  `npm install github:user/repo` (npm gagal: temp git clone code 128 / SSH publickey).
- python: venv Hermes tiada pip asal → `python -m ensurepip` dahulu, kemudian
  `python -m pip install git+https://github.com/USER/REPO.git`.
- Model kadang lapor "read_file gagal / fail tiada" padahal fail wujud → prompt mesti suruh
  `ls` dahulu sebelum menyimpulkan. Sudah dimasukkan ke `BM_AGENT_PREFIX`.

### Routing yang diuji

`audit|analisis|periksa|kaji|teliti|review` kini masuk `AGENT_HINT` (dulu jatuh ke chat 3s tanpa alat).
`HARD_HINT` buang perkataan biasa (`penuh`, `semua`) supaya "tulis fail ... kandungan" kekal medium.

## 9router "waiting for provider" di Hermes (1 Nov 2026) — punca & pembetulan

**Punca sebenar:** bukan gateway mati. `mistral/mistral-large-4` kena **429 Rate limit**
dari hujung Mistral; 9router membalutnya sebagai **HTTP 503**, Hermes retry 3× dengan backoff
(8s → 16s → …) sampai **75s**, dan desktop memaparkan "waiting for provider" sepanjang itu.

Pembetulan yang dipasang (semua melalui `hermes config set`, config di-cache ikut cap jari fail
jadi berkuat kuasa pada mesej berikutnya tanpa restart):

| Tetapan | Nilai | Kesan |
|---|---|---|
| `providers.9router.model` + `custom_providers.2.model` | `mistral/codestral-latest` | model lalai tidak lagi large-4 yang mudah kena 429 |
| `providers.9router.models.mistral-safe` | `{}` | combo auto-fallback boleh dipilih manual |
| `providers.9router.request_timeout_seconds` / `stale_timeout_seconds` | 60 / 30 | gagal cepat, bukan tergantung |
| `agent.api_max_retries` | 1 (dari 3) | model 429 jawab dalam **34s**, bukan 75s |
| `fallback_model` | 9router codestral → groq qwen3.8-27b → openrouter nemotron → tokenharbor | susunan lama mula dengan tokenharbor yang mati |

Combo dicipta melalui API CLI 9router (bukan UI):

```bash
POST http://127.0.0.1:20128/api/combos   # header x-9r-cli-token
{"name":"mistral-safe","models":["mistral/mistral-large-4","mistral/codestral-latest","mistral/ministral-8b-latest"]}
```

Selepas dicipta ia muncul dalam `/v1/models` sebagai `mistral-safe`. Nota: combo menambah
overhead (3–8s) dan boleh memilih model mana-mana dalam senarai, jadi jangan jadikan ia model
lalai untuk chat — guna `codestral` untuk lalai, combo hanya bila mahu auto-fallback.

Ujian akhir: `hermes -z ... -m <model> --provider 9router` → codestral 14s, ministral 12s,
large-4 41s, mistral-safe 20s (termasuk boot CLI ~10s), semua jawab `PONG`.

Bot hidup 24/7 walaupun laptop mati hanya dengan VPS + salinan folder ini — laptop-ON
adalah syarat seni bina semasa, bukan kelemahan konfigurasi.

## 9router di nod: jangan tunnel ke PC, jalankan di nod

Bila laptop mati, `127.0.0.1:20128` memang tiada — tunnel tidak membantu kerana PC juga mati.
Penyelesaian sebenar: **jalankan 9router sendiri di nod**.

- `npm i -g --prefix ~/persist/npm 9router@<versi>` — pakej npm awam, node >=18, tiada sekatan OS.
- Data dir Linux: `~/.9router` (Windows: `%APPDATA%\9router`). Jadikan `~/.9router` **pautan
  simbolik** ke `~/persist/nine` supaya DB (kunci Mistral) ikut blob simpanan tersulit.
- CLI: `9router --port 20128 --no-browser --skip-update`; kawal guna **pidfile**, jangan `pgrep -f`.
  Corak `pgrep -f` akan memadankan baris arahan SSH kau sendiri lalu membunuh sesi (exit 255).
- **`stream` mesti dihantar sebagai `false` secara eksplisit.** Tanpa medan itu, 9router di nod
  balas SSE (`data: {...}` … `data: [DONE]`) dan parse JSON gagal — berbeza daripada PC.
- Kunci API 9router (`SELECT key FROM apiKeys`) mesti masuk `.env` sebagai
  `HERMES_CUSTOM_9ROUTER_API_KEY`, jika tidak upstream bot 401.
- Kecualikan `npm/`, `hvenv/`, `nine/backups`, `nine/runtime` daripada blob simpanan; ia dipasang
  semula setiap boot (~2 minit) dan jika tidak, blob membengkak sampai push gagal senyap.

## Peraturan keras dalam prompt agen (diuji)

Model akan gagal pada perkara remeh kecuali dilarang secara eksplisit di **setiap** panggilan:

- **Kiraan wajib alat.** Tanpa peraturan ini, codestral menjawab `4273` dan ministral `4223`
  untuk 47×89 (dua-dua salah). Selepas peraturan: `4183` melalui `python3`. Soalan "balas
  nombor sahaja" ialah pencetus paling biasa untuk kiraan dalam kepala — larang secara spesifik.
- **Jalankan, jangan tunjuk.** Bila dilarang mengira dalam kepala tetapi tidak dilarang
  memapar kod, model membalas dengan blok ```` ```python print(47 * 89) ``` ```` tanpa
  melaksanakan. Dua larangan berasingan diperlukan.
- **Prompt besar mencemar model kecil.** Ministral 8B menulis `BARIS=128` kerana menyalin nombor
  `128` daripada teks skill `tool-discipline` yang disuntik auto_load. Uji dengan
  `--profile lite` (tanpa auto_load) untuk mengesan; jika tepat, hantar model 8B ke profil lite
  secara automatik dalam `_agent_core`.
- **Sahkan dari kesan fizikal, dan bandingkan NILAI.** Semakan `startswith("N=")` meluluskan
  model yang menulis `N=2` sedangkan kiraan sebenar `1`. Kira nilai dijangka dalam harness.

## Agen Hermes penuh di nod awan

`/agent` perlukan Hermes CLI sebenar di nod, bukan sekadar panggilan API model.

- **Pasang `hermes-agent` dari PyPI** dalam venv di nod, pautkan `$HERMES_HOME/bin/hermes`;
  `_hermes_exe()` cari laluan itu (`bin/hermes.exe` dahulu, kemudian `bin/hermes`).
- **`providers:` mesti bentuk PETA (mapping).** Bentuk senarai menghasilkan "Unknown provider";
  rujuk provider tersuai tanpa awalan `custom:`.
- **`--profile` hanya jika `$HERMES_HOME/profiles/<nama>` wujud.** Di nod profil tiada dan setiap
  panggilan gagal.
- **Alat pelayar perlukan Playwright + Chromium** (cache `~/.cache/ms-playwright` hilang setiap
  boot). Pasang dalam `start.sh` dengan semakan direktori; ~120MB.
- **Pilih model ikut tempat:** uji port `127.0.0.1:20128`. Terbuka = PC, guna 9router Mistral;
  tertutup = nod, guna provider awan. Jangan hardcode satu rancangan untuk dua mesin.
- **Gabung `keys.db` dengan `MAX`, bukan tambah.** Kedua-dua DB bermula daripada snapshot sama dan
  gerbang penunggu menjamin hanya satu bot aktif — `MAX` betul dan idempotent, `SUM` menggelembung
  pada setiap cron 10 minit. SQLite tidak terima nama tiga bahagian (`r.jadual.lajur`) dalam
  UPDATE; guna subkueri beralias.
- **Model dikunci semasa sesi dicipta.** `--resume` dengan `-m` berbeza ditolak secara reka bentuk;
  tukar dari dalam sesi dengan `/model`. Uji sesi lama dengan model yang sama.

## v8 (1 Nov 2026) — chat bersih, agen bertools, self-upgrade

| Perkara | Fakta terverifikasi |
|---|---|
| Teks keluar | `plainify()` buang `* ** __ ` # > ~~ | jadual paip`, pautan markdown, tag HTML; `reply_smart()` hantar tanpa `parse_mode`, potong ikut baris 3900 aksara |
| Upstream chat | `9r-codestral` (0.65s), `9r-ministral` (0.76s), `groq-fast` qwen3.8-27b (0.33–0.55s), `openrouter-free`; race 2 terpantas sahaja, baki sekuen; cooldown 120s (429) / 300s (4xx) |
| Model mati | `tokenharbor` `:free` habis sampai 5 Nov 2026 11:50 UTC + saldo $0; `gemini-3.8-flash` 429 kuota; `9r-large4` hantar blok `thinking` sahaja (bukan teks) → tak boleh jadi upstream chat |
| Agen bertools | `hermes -z -m <model> --provider 9router` dalam cwd bot; tools penuh + skills; tier dari `config.json.agent_tiers` |
| Tier | hard `codestral` (700s) · medium `ministral-8b` (420s) · easy `ministral-8b` (360s) · max `mistral-large-4` (900s, opt-in sahaja: 429 + thinking-only) |
| Self-upgrade | `/upgrade <arahan>` → snapshot `backups/` → agen ubah kod → `--selftest` → cap jari berubah → bot `os._exit(0)` → supervisor hidupkan semula; selftest gagal = fail dipulihkan dari backup |
| Satu poller | Token bot dipindah ke `$HERMES_HOME/secrets/telegram_bot_token`; baris `TELEGRAM_BOT_TOKEN` dalam `.env` di-comment supaya gateway Hermes tidak berebut getUpdates |

Command baharu: `/agent [hard|medium|easy]`, `/upgrade`, `/restart`, `/rollback`, `/tools`,
`/skills`, `/doctor`; `/models` papar tier + cooldown; `/status` papar upstream hidup.

### Pitfall v8 (semua terbukti live)

- **9router append `data: [DONE]` ke badan non-stream** → `r.json()` pecah (`Extra data`). Guna
  `parse_json_loose()` (json.loads → potong pada `data:` → `raw_decode`).
- **Mistral tolak greedy sampling tanpa `top_p=1`** → HTTP 400 `top_p must be 1 when using greedy
  sampling`. Gateway mesti set `top_p=1` bila klien tidak hantar.
- **`mistral/mistral-large-latest` = 403 subscription tier**; yang berfungsi `mistral-large-4`
  (reasoning, `content` senarai blok thinking) dan `mistral-medium-latest` (429).
- **`oc/*-free` (muse-spark, union, jev) = 502 `wreq-js unavailable`** — jangan masukkan sebagai upstream.
- **Dua poller satu token = 409 berulang + update berpecah.** Punca sebenar pada host ini: gateway
  Hermes turut poll `TELEGRAM_BOT_TOKEN`. Semak `gateway_state.json` →
  `platforms.telegram.error_code=telegram_polling_conflict`. Selesaikan dengan token peribadi
  bot + comment baris `.env`; jangan jalankan dua salinan bot pada satu token.
- **Bunuh proses bot guna filter `*telekey*` boleh bunuh shell sendiri** (command line bash
  mengandungi perkataan itu). Tapis ikut `Name -eq 'python.exe'` sahaja.
- **Ujian agen paling murah:** `_agent_core(prompt, "easy")` tulis fail probe; kalau fail wujud
  dengan isi tepat, tools benar-benar berfungsi — bukan sekadar jawapan model.
- **`mistral-large-4` kena 429 pada prompt ~50k token walaupun satu panggilan** (9router balas
  HTTP 503 `[429] Rate limit exceeded`). Codestral/ministral pada prompt sama: 200 dalam 2.6–3.3s.
  Jangan letak large-4 sebagai model lalai sesuatu provider atau tier automatik.
- **Agen yang hanya "mencadang" ialah kegagalan prompt, bukan model.** Masukkan arahan keras dalam
  prefix agen: jangan beri cadangan tanpa melaksanakan; cadangan hanya bila benar-benar mustahil,
  dengan sebab teknikal satu baris.
- **Prompt identiti 160 KB melumpuhkan model kecil.** Bila BOZ kata jawapan model "merapu/pening",
  ukur dulu dengan `hermes prompt-size` (SOUL + AGENTS + tool schema); model 8B hanya boleh berfungsi
  dalam profil ringkas — resepi penuh dalam skill `elyy-multiprofile-stack` seksyen profil `lite`.
- **Agen bot mesti pin profil.** `_agent_core` dan `_vision_core` memanggil
  `hermes --profile default ...`; tanpa pin, `hermes profile use lite` (yang BOZ buat untuk chat
  Mistral di desktop) menyeret kerja agen bot ke profil 34 KB tanpa atlas/identiti. Pin menjadikan
  pertukaran profil desktop selamat untuk bot.