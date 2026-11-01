---
name: free-node-bore-tunnel
description: "Use when BOZ needs a free SSH host without a VPS."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [ssh, tunnel, bore, github-actions, sshd, vps]
---

# FREE NODE + BORE TUNNEL

Tiada VPS, tiada kad, tiada port forwarding: hos Linux sementara yang boleh di-SSH dari
mana-mana. Kit rujukan: `C:/Users/zahin/Downloads/tunnel-kit` (repo `Solelyy4/boz-lab-node`).

## Bila guna

**Inventori dahulu.** Sebelum mencadangkan BOZ buat akaun/token/bot baharu, semak apa yang
sudah ada: proses berjalan (`ps -W`, `netstat -ano`), folder projek, dan `$HERMES_HOME/.env`.
Kesilapan paling memakan masa dalam kelas kerja ini ialah meminta BOZ mencipta sesuatu yang
dia sudah miliki — dia akan menjawab "aku bukan dah ada?" dan itu bermakna kau tidak buat
kerja rumah.

- BOZ mahu hos Linux untuk di-SSH tetapi tiada VPS.
- `ssh` gagal dengan `Permission denied (publickey)` pada kotak baru walaupun kunci betul.
- Perlu tunnel awam ke port 22 tanpa akaun/token.

## Aliran

```
bash spin-up.sh 120 --test     # dari PC: hidupkan nod + uji SSH
```

Dalaman: workflow `ephemeral-node` → `sudo bash node.sh install` → sshd + bore → alamat
dilaporkan ke issue `node-status` → `spin-up.sh` baca issue, cetak arahan SSH.

Pada VPS sebenar (Oracle/Hetzner/sandbox): `sudo bash node.sh install --key "ssh-ed25519 ..."`
kemudian `sudo bash node.sh status`. Fail yang SAMA — jadi ia diuji setiap kali nod dihidupkan.

## Mod berterusan (alamat tetap, tanpa sentuhan BOZ)

Bila BOZ minta "hidupkan sendiri, jangan susahkan saya":

1. `node.sh install --port 45001` — cuba port tetap supaya alamat SSH kekal merentas
   pertukaran, **tetapi sedia jatuh ke port rawak**. Klien `bore` zombie (dari run yang
   di-cancel: job mati, proses di VM lambat mati) boleh memegang port itu berjam-jam di
   pelayan dan menyekat SETIAP pengganti dengan `port already in use`. Beri ~2 minit
   (6 cubaan) pada port tetap, kemudian beralih ke rawak dan laporkan port itu.
2. **Rantaian dijaga di AWAN, bukan di PC.** Laptop BOZ tutup = cron PC mati = nod tamat =
   bot mati. Jadi: `keeper.yml` (cron Actions setiap 5 min) + `successor.yml`
   (`on: workflow_run` ephemeral-node `completed`) menghidupkan pengganti tanpa PC langsung.
   `keeper.sh` di PC kekal sebagai jaring tambahan dan MESTI langkau bila sudah ada run hidup.
   Reka bentuk penuh (kekangan GITHUB_TOKEN, kunci pemilikan, susunan boot supaya bot hidup
   dahulu): `references/node-chain-without-pc.md`.
3. `state.sh` — `~/persist` di-tar + disulitkan AES → branch `state`; nod baru pulih masa boot.
   Kecualikan direktori pemasangan besar (venv) — lihat perangkap 12.
4. `boz-ssh.sh` — pembungkus; `StrictHostKeyChecking=no` sebab host key berubah setiap nod.
   **Jangan hardcode port**: baca `PORT=` dari issue `node-status` pada setiap panggilan,
   kerana nod boleh berakhir di port rawak.

Jeda pertukaran terukur: **~40 saat**. Repo MESTI awam untuk minit Actions tanpa had
(private = 2,000 min/bulan, tidak cukup untuk 24/7).

**Susunan argumen ssh:** hos mesti sebelum arahan jauh. `ssh OPTS "$@" host` menjadikan
arahan itu hos (`hostname contains invalid characters`). Betulkan: `ssh OPTS host "$@"`.

**`openssl -pass env:PASS`** baca persekitaran proses — `export PASS` dulu, bukan sekadar
pemboleh ubah shell.

**Jangan guna "ada run in_progress?" sebagai penanda pengganti** — nod semasa juga in_progress.
Guna penanda setempat (`last_dispatch`, 15 min) yang deterministik.

## Perangkap yang sudah memakan masa (jangan ulang)

1. **`sshd_config.d` ikut abjad, NILAI PERTAMA MENANG.** Imej awan letak
   `PasswordAuthentication yes` dalam `50-cloud-init.conf`; drop-in `99-*.conf` kalah.
   Nama fail WAJIB `00-*.conf`. Sahkan dengan `sshd -T | grep -i '^passwordauthentication'`.
2. **Jangan tulis `AllowUsers`.** Nama user berbeza antara hos (GitHub runner = `runner`,
   Ubuntu = `ubuntu`, Oracle = `opc`/`ubuntu`). `AllowUsers ubuntu` menolak semua.
3. **`echo` status di dalam `$(...)` merosakkan nilai balik.** Dalam fungsi yang hasilnya
   ditangkap (`b="$(bore_bin)"`), semua mesej manusia mesti ke `>&2`.
4. **CRLF membunuh skrip shell.** Tulis fail dengan `newline="\n"`; `.gitattributes`
   `* text=auto eol=lf`. Kalau tidak, `set -eux\r` gagal di Linux.
5. **Lapisan redaksi output tool menopeng rentetan seperti `Basic <token>` menjadi `***`.**
   Jangan simpulkan bug daripada paparan; sahkan dengan semakan bait fail mentah
   (`b"literal" in open(p,"rb").read()`).
6. **`pgrep -f`/`pkill -f` memadankan baris arahan yang menjalankannya.** Pengawal
   `if pgrep -f bot.py; then langkau` menyangka proses sudah hidup lalu tidak memulakannya;
   sama juga bila `pgrep` dipanggil dalam arahan SSH dari PC. Lebih buruk: corak itu muncul
   dalam arahan SSH kau sendiri, jadi `pkill -f "…/9router"` membunuh shell SSH itu dan kau
   nampak `exit 255` / `Connection closed by remote host` — bukan ralat proses yang kau cari.
   Guna pidfile + `kill -0 "$(cat bot.pid)"` / `kill "$(cat pid)"`, bukan padanan corak.
7. **Workflow baharu kadang belum terdaftar selepas push pertama pada repo baharu**
   (`gh workflow run` → HTTP 404 walaupun fail ada di default branch). Sentuh fail (tambah
   komen), push semula, dan sahkan dengan `gh api repos/<r>/actions/workflows` sebelum
   menyalahkan YAML.
8. **Run `in_progress` ≠ tunnel hidup.** `bore` boleh mati (pelayan menutup port, klien
   keluar) sedangkan job terus `sleep` hingga tamat. `ssh` beri `Connection refused`
   manakala semua langkah workflow `success`. Penjaga WAJIB uji port sebenar
   (`timeout 12 bash -c "exec 3<>/dev/tcp/bore.pub/$PORT"`), bukan hanya `EXPIRES_UTC`;
   ganti selepas 2 kegagalan berturut supaya tidak berdenyut semasa nod baru boot.
9. **URL raw gist di-cache CDN ~5 minit.** Nadi yang ditulis melalui API kelihatan basi pada
   `gist.githubusercontent.com` → penunggu menyangka hos utama mati lalu merampas kerja.
   Selalu tambah cache-buster: `"$HB_URL?cb=$(date -u +%s)"`. Sahkan dengan membandingkan
   `gh api /gists/<id> --jq '.files.alive.content'` (tiada cache) dengan bacaan curl.
10. **`set -e` + `timeout` dalam arahan ujian SSH memotong output.** `timeout 15 bash x.sh`
    pulang 124, jadi skrip pembungkus mati sebelum sempat mencetak log — kau nampak output
    kosong dan menyangka ujian gagal. Buang `set -e` dalam arahan ujian, atau tambah `|| true`
    pada setiap `timeout`.
11. **Port sebenar hanya diketahui dari issue, bukan dari argumen workflow.** `-f port=45001`
    ialah PERMINTAAN; nod boleh berakhir di port rawak. Setiap pembaca (penjaga, pembungkus
    SSH, skrip ujian) mesti ambil `PORT=` dari body issue `node-status`, dengan 45001 hanya
    sebagai fallback terakhir. Hardcode = kau menguji/SSH ke port nod lama atau ke klien zombie.
12. **Blob simpanan yang dipush setiap 2 minit tidak boleh mengandungi venv/pemasangan besar.**
    `tar czf ~/persist` bersama `hvenv` (~100MB) menjadikan push lambat/gagal, dan `watch`
    menelan kegagalan itu (`|| true`) — jadi penyegerakan berhenti SENYAP dan semua kerja
    selepas titik itu hilang bila nod berganti. Kecualikan direktori pemasangan, pasang
    semula pada boot (`~20-60s` dengan cache pip), dan tulis penanda `/tmp/.state-last-ok`
    selepas push berjaya supaya kegagalan kelihatan.
13. **Bootstrap: fail milik repo sentiasa disegarkan, data pengguna tidak.** Ciri baharu tidak
    sampai ke nod bila bootstrap guna `[ -f ... ] || cp` pada `start.sh` / `telekey.py` —
    salinan lama dalam blob kekal selamanya dan `start.log` tidak menyebut ciri itu. Dan
    `[ -d "$P/skills" ] || cp` melangkau salinan bila blob menyimpan direktori KOSONG.
    Peraturan: `cp` tanpa syarat untuk kod yang dihantar repo (`start.sh`, `make-config.py`,
    `telekey.py`, `standby.sh`, `skills/`), dan semak ISI (`find … -name SKILL.md | wc -l`)
    bukan kewujudan dir. `keys.db`/`.env`/`secrets` tidak pernah disentuh.
14. **`gh workflow run` dari dalam workflow GAGAL SENYAP.** `GITHUB_TOKEN` tidak boleh
    mencetuskan run baharu; arahan pulang 0, log tulis "pengganti dihantar", tetapi tiada run
    muncul. Kekecualian: peristiwa `workflow_run` MEMANG dicetuskan — jadi rantaian diri mesti
    guna itu, bukan `gh workflow run`. Sandaran berjadual (`schedule`) juga berfungsi.
15. **Dua nod hidup = dua poller = `409 Conflict`.** Semasa pertukaran, nod baru boleh hidup
    sebelum yang lama tamat. Kunci pemilikan: tiap nod tulis `OWNER=<run_id>` ke issue dan
    hanya pemilik poll; id run GitHub menaik, jadi id lebih BESAR = lebih baru dan boleh ambil
    alih (tulis semula OWNER). Butiran: `references/node-chain-without-pc.md`.
16. **`start.sh` dijalankan tanpa env workflow.** Ia mesti `set -a; . ./.env` sendiri, jika
    tidak kunci provider tiada dan config agen tidak dijana. Sumber kunci yang datang dari
    fail (cth DB 9router) pula mesti ditulis ke `.env` SEBELUM bot dihidupkan — `load_config()`
    menyelesaikan kunci sekali sahaja semasa mula, jadi bot yang hidup dahulu akan terkunci
    pada provider sandaran sampai ia dimulakan semula.

## Bot Telegram pada nod

```bash
bash set-bot.sh "<token>"     # sahkan getMe → tolak jika 409 → tulis ~/persist/.env → start
```

Token dihantar melalui **stdin SSH**, bukan argumen arahan, supaya ia tidak muncul dalam
senarai proses nod.

**Turutan wajib dalam workflow:** `node.sh install --port N` (BLOK sampai tunnel memegang
port) → `state.sh restore` → jalankan `~/persist/start.sh` → lapor issue → tahan hidup.
Menjalankan bot sebelum tunnel dipegang bermakna bot hidup pada nod yang belum jadi nod
sebenar, dan dua instance bertindih semasa pertukaran.

**Satu token = satu poller.** Telegram menolak poller kedua dengan `409 Conflict` **dan**
memutuskan long-poll yang sedang berjalan pada poller pertama. Dua pilihan, pilih ikut kos
kepada BOZ:

- **Bot berasingan untuk nod** (token baharu) — paling selamat, tiada percabangan data, tapi
  BOZ kena cipta bot sekali (BotFather; tak boleh diotomasikan, perlukan akaun Telegram dia).
- **Penunggu atas token yang sama, berpagar nadi** — kosong untuk BOZ, tiada token baharu.
  Hos utama tulis nadi setiap minit; nod hanya poll bila nadi basi > 3 min dan lepas balik
  bila nadi pulih. Resipi penuh + tiga laluan ujian: `references/single-consumer-standby.md`.
  Had: `keys.db` tetap bercabang, dan pengambilalihan sebenar hanya terbukti bila hos utama
  betul-betul mati — jangan dakwa ia berfungsi sebelum itu.

**Jangan guna `getUpdates` sebagai ujian kesihatan.** Panggilan manual dari PC merampas poll,
memutuskan bot, dan mencetuskan 409 dalam lognya — gejala yang kau lihat ialah kerosakan yang
kau sendiri buat. Uji dengan `/health`, log bot, atau hantar mesej sebenar ke bot.

## Agen sebenar di nod

Nod bukan sekadar hos SSH: ia boleh menjalankan **Hermes Agent penuh** (tools + skills) supaya
`/agent` dalam Telegram berfungsi walaupun laptop mati. Pasang `pip install hermes-agent` ke
venv di `~/persist`, paut ke `<HERMES_HOME>/bin/hermes`, jana `config.yaml` dari `.env`, dan
bawa skills dari repo. Resipi penuh + perangkap config (bentuk `providers:` MESTI peta, bukan
senarai) + harness ujian: `references/hermes-agent-on-node.md`.

## Batas sebenar

- GitHub Actions: satu job maks **350 minit**, mesin dimusnahkan selepas itu, tiada data kekal.
- bore.pub tanpa akaun: port bertukar setiap restart. `--port N` untuk cuba port tetap.
- Bukan hos 24/7 — kerja berterusan/proxy/mining langgar ToS Actions. Untuk kekal, Oracle
  Always Free (`VM.Standard.E2.1.Micro` sentiasa ada stok; A1.Flex sering habis).

## Bukti sebelum lapor selesai

`ssh -i <key> -p <port> user@bore.pub 'whoami; hostname'` mesti pulangkan output sebenar,
dan `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ...` mesti pulangkan
`Permission denied (publickey)` — bukan `(publickey,password)`.
