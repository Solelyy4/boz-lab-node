# Hermes Agent penuh di nod sementara

Sasaran: `/agent` dalam bot Telegram (atau apa-apa kerja agen) berjalan **di nod Linux**, bukan
di PC, supaya ia hidup walaupun laptop ditutup. Nod tiada apa-apa selain Ubuntu + python3.

## 1. Pasang (start.sh, setiap boot)

```bash
python3 -m venv "$PWD/hvenv"
"$PWD/hvenv/bin/pip" install -q --upgrade pip
"$PWD/hvenv/bin/pip" install -q hermes-agent      # ~20-60s dengan cache pip
mkdir -p "$PWD/bin"; ln -sf "$PWD/hvenv/bin/hermes" "$PWD/bin/hermes"
```

`hvenv` **tidak** masuk blob simpanan (100MB dipush tiap 2 minit = push gagal senyap). Pasang
semula setiap boot; `start.sh` berjalan di latar jadi bot tidak menunggu.

Kod yang memanggil agen mesti tahu kedua-dua nama binari:

```python
def _hermes_exe():
    home = Path(os.environ.get("HERMES_HOME") or "")
    exe = home / "bin" / "hermes.exe"     # Windows
    if not exe.exists():
        exe = home / "bin" / "hermes"      # Linux
    return exe
```

## 2. config.yaml — bentuk `providers:` MESTI peta

Perangkap paling memakan masa: `providers:` sebagai SENARAI menghasilkan
`Unknown provider '<nama>'` walaupun setiap medan betul. Bentuk yang didaftarkan ialah peta
berkunci nama:

```yaml
model:
  default: deepseek-v4.1-flash
  provider: tokenomix
providers:
  tokenomix:
    base_url: https://api.tokenomixai.com/v1
    api_key: sk-...            # v0.19 tiada key_env; tulis nilai, chmod 600
    model: deepseek-v4.1-flash
    api_mode: chat_completions
    models:
      deepseek-v4.1-flash: {}
  groq:
    base_url: https://api.groq.com/openai/v1
    api_key: gsk_...
    model: qwen/qwen3.8-27b
```

Nota lain yang diuji pada v0.19.0:

- Senarai `providers:` (dengan `name:`) → `Unknown provider`; `custom:<nama>` juga tidak dikenali
  pada laluan `-z`. Lokasi kod: `hermes_cli/auth.py` (fungsi yang menaikkan ralat) dan
  `hermes_cli/config.py::_normalize_custom_provider_entry` (komennya mendedahkan bentuk peta).
- `key_env:`/`api_key_env:` tidak dihormati oleh setiap laluan; `api_key:` literal paling selamat
  pada fail ephemeral (chmod 600) yang mati bersama VM.
- `hermes model` dan `hermes tools` (tanpa argumen) perlukan TTY — jangan panggil dari subprocess.
  `hermes tools list` dan `hermes prompt-size` selamat bukan-interaktif.

## 3. Skills dari repo

```yaml
skills:
  auto_load: [tool-discipline, elyy-ops-atlas]
  external_dirs: [/home/runner/persist/skills]
```

Tiga langkah yang mesti betul serentak:

1. Salin subset skills ke dalam repo (bukan 500MB `$HERMES_HOME/skills` — pilih 8-10 skill
   teras; ~200KB).
2. `cp -r skills/. "$P/skills"/` **tanpa syarat** semasa bootstrap; jangan guna
   `[ -d "$P/skills" ] || cp` kerana blob boleh menyimpan direktori kosong.
3. Sahkan dengan `hermes prompt-size | grep -i skill` — baris `skills index` mesti bukan sifar.

## 4. Model: PC tidak sama dengan nod

`9router` hidup di `127.0.0.1:20128` pada PC sahaja. Kod yang menetapkan model tier mesti boleh
ditimpa tanpa ubah kod:

```python
override = (os.environ.get("TELEKEY_AGENT_PLAN") or "").strip()   # "model|provider,model|provider"
if override:
    plan = [(m.strip(), p.strip()) for m, p in (i.split("|", 1) for i in override.split(","))]
```

Dan `--profile <nama>` mesti dilangkau bila profil tiada di hos itu:

```python
use_profile = (Path(os.environ.get("HERMES_HOME") or "") / "profiles" / prof).is_dir()
cmd = [str(exe)] + (["--profile", prof] if use_profile else []) + ["-m", model, "--provider", provider, "-z", prompt]
```

## 5. Uji dengan fungsi bot itu sendiri

Jangan uji `hermes -z` sahaja — uji laluan yang bot guna, supaya isu env/cwd/config ikut teruji:

```python
import importlib.util, os
spec = importlib.util.spec_from_file_location("tk", os.path.expanduser("~/persist/telekey/telekey.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m._hermes_exe().exists())
out, err, note = m._agent_core(
  "Guna alat terminal jalankan: hostname. Kemudian buka skill tool-discipline guna skill_view "
  "dan sebut tepat tajuk seksyen 4. Ringkas.")
print(out, err, note)
```

Lulus = ia menyebut hostname SEBENAR nod **dan** tajuk seksyen skill secara verbatim. Satu
panggilan membuktikan tiga perkara serentak: binari, alat, dan skills.

Import `telekey.py` perlukan `python-telegram-bot` dalam interpreter yang menjalankannya —
sistem `python3` di nod ada PTB (start.sh pasang ke situ), venv Hermes tidak. Guna `python3`.

## 6. Had

- `browser` perlukan Playwright yang tidak dipasang → `web`, `terminal`, `file`,
  `code_execution` jalan; automasi pelayar belum.
- Masa pemasangan tambah ~20-60s pada boot; jangan letak di hadapan gerbang penunggu.
- Setiap boot hilang state agen (memori/sesi) — `~/persist` hanya simpan fail, bukan SQLite sesi
  Hermes melainkan ia turut disalin.
