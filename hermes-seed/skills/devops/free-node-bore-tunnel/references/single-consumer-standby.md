# Penunggu satu-poller untuk bot Telegram

Masalah: Telegram hanya benarkan SATU poller per token. Bot BOZ sudah poll di PC, tetapi ia
mesti terus berfungsi bila laptop ditutup. Jawapan: nod menjadi **penunggu** — senyap semasa
PC hidup, ambil alih bila PC senyap, lepas balik bila PC pulih.

```
PC hidup (nadi < 3 min)   -> TeleKey di PC, nod senyap
Laptop tutup > 3 min      -> nod ambil alih poll
Laptop hidup semula       -> nod lepas dalam ~45s, PC ambil balik
```

## 1. Penulis nadi (hos utama)

Cron Hermes `no_agent`, setiap minit, senyap bila berjaya. Tulis epoch ke gist melalui API
(`gh api`), bukan ke fail tempatan — nod tiada akses fail ke PC.

```bash
#!/usr/bin/env bash
set -eu
GID=$(cat "$HOME/.boz-node/gist_id")
GH="$LOCALAPPDATA/hermes/bin/gh.exe"
NOW=$(date -u +%s)
printf '%s' "$NOW" > /tmp/alive.txt
"$GH" api -X PATCH "/gists/$GID" -f "files[alive][content]=$NOW" >/dev/null
```

## 2. Pembaca nadi (nod)

```bash
hb_age() {
  local f now; now="$(date -u +%s)"
  # ?cb= WAJIB: gist.githubusercontent.com di-cache CDN ~5 minit. Tanpa cache-buster,
  # nadi 2 minit kelihatan 6 minit basi dan nod merampas poll daripada PC yang sihat.
  f="$(curl -sS -m 10 "$HB_URL?cb=$now" 2>/dev/null | tr -dc '0-9')"
  [ -n "$f" ] || { echo 999999; return; }
  echo $(( now - f ))
}
```

Gerbang utama, satu gelung:

```bash
running() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
while :; do
  age="$(hb_age)"
  if [ "$age" -lt "$FRESH" ]; then          # PC hidup
    if running; then kill "$(cat "$PIDF")"; rm -f "$PIDF"; say "PC hidup semula — dilepas"; fi
  else                                       # PC senyap
    if ! running; then nohup $BOT_CMD & echo $! > "$PIDF"; say "DIAMBIL ALIH pid $!"; fi
  fi
  sleep "$CHECK"
 done
```

Nilai: `FRESH=180`, `CHECK=45`. `BOT_CMD` mesti boleh ditimpa (`BOT_CMD="sleep 300"`) supaya
ujian tidak menyentuh Telegram langsung.

## 3. Tiga laluan ujian (semua mesti lulus sebelum dakwa berfungsi)

| Ujian | Persediaan | Jangkaan |
|---|---|---|
| A — PC hidup | nadi segar | tiada pidfile, log hanya `penunggu bermula` |
| B — PC senyap | `HB_URL="http://127.0.0.1:1/alive"` | `DIAMBIL ALIH`, pidfile ditulis, proses `sleep 300` hidup |
| C — PC pulih | mula proses + tulis pidfile, nadi segar | proses dibunuh, pidfile dipadam, log `PC hidup semula` |

Jalankan dengan `BOT_CMD="sleep 300" CHECK=4 timeout 12 bash standby.sh || true` — **`|| true`
wajib**, `timeout` pulang 124 dan `set -e` mematikan skrip sebelum ia mencetak log.

## 4. Perangkap

- **`pgrep -f telekey.py` memadankan shell yang memanggilnya** (arahan SSH pembungkus juga
  mengandungi rentetan itu) → gerbang menyangka bot sudah hidup lalu tidak memulakannya.
  Pidfile + `kill -0` sahaja.
- **Nadi basi palsu** kerana cache CDN ialah punca #1 pengambilalihan palsu. Sahkan dengan
  `gh api /gists/<id> --jq '.files.alive.content'` (tiada cache) berbanding bacaan curl.
- **Cron penulis nadi mesti wujud.** Tanpa cron, nadi berhenti sejam selepas ujian manual dan
  nod merampas poll daripada PC yang hidup — gejala kelihatan seperti "bot bercabang".
- **`keys.db` bercabang.** Kunci API yang dicipta melalui Telegram semasa laptop mati (bot di
  nod) hilang bila laptop hidup semula, kerana PC memegang salinannya sendiri. Beritahu BOZ:
  `/getkey` hanya bila laptop hidup.
- **Pengambilalihan sebenar tidak boleh diuji dari meja.** Laluan A/B/C membuktikan gerbang;
  hanya menutup laptop > 3 min membuktikan poll sebenar. Jangan dakwa lebih daripada itu.
