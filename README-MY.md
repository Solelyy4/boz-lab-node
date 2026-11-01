# NOD KAU — SSH ke mesin yang tak pernah mati

Kau tak perlu buat apa-apa. Satu arahan, dan ia berfungsi hari ini, esok, minggu depan.

```bash
bash ~/Downloads/tunnel-kit/boz-ssh.sh
```

Atau jalankan satu arahan terus:

```bash
bash ~/Downloads/tunnel-kit/boz-ssh.sh 'ls ~/persist'
```

**Alamatnya tak berubah.** Mesin di belakangnya berganti sendiri setiap ~5 jam 50 minit.
Kau takkan nampak apa-apa kecuali satu jeda ~40 saat.

---

## Apa yang berjalan sendiri

| Benda | Siapa uruskan | Kekerapan |
|---|---|---|
| Nod tamat → pengganti dihantar | `keeper.sh` (cron Hermes) | setiap 10 minit |
| Alamat kekal `bore.pub:45001` | `node.sh install --port` | setiap nod baru |
| Fail kau disimpan & dipulih | `state.sh` | simpan tiap 2 min, pulih masa boot |
| Laporan alamat | issue `node-status` di GitHub | setiap pertukaran |

Nod sekarang: Ubuntu 24.04 · **4 core · 16 GB RAM · 72 GB disk**.

---

## Fail kau — letak dalam `~/persist`

Hanya `~/persist` yang kekal. Di luar itu hilang bila mesin berganti.

```bash
bash boz-ssh.sh 'mkdir -p ~/persist/projek && echo hello > ~/persist/projek/a.txt'
```

Simpanan disulitkan (AES-256) sebelum keluar, disimpan di branch `state` repo
`Solelyy4/boz-lab-node`. Nod baru tarik balik dan nyahsulit masa mula. Tanpa passphrase
(`~/.boz-node/pass`), blob itu tidak berguna.

---

## Bila sesuatu rosak

```bash
bash ~/Downloads/tunnel-kit/keeper.sh        # paksa semak + hantar pengganti kalau perlu
bash ~/Downloads/tunnel-kit/keeper.sh --force # paksa nod baru sekarang
tail -20 ~/.boz-node/keeper.log              # apa penjaga dah buat
```

Kalau SSH tersangkut: tunggu 2 minit dan cuba lagi. Penjaga akan pulihkan sendiri.

---

## Bot Telegram — TeleKey kau sebagai penunggu

Telegram hanya benarkan **satu poller bagi setiap token**. TeleKey kau sudah poll di PC, jadi
nod ini bukan pengganti — ia **penunggu**:

| Keadaan | Siapa layan pengguna |
|---|---|
| PC hidup (nadi < 3 min) | TeleKey di PC. Nod senyap sepenuhnya |
| Laptop tutup > 3 min | Nod ambil alih poll |
| Laptop hidup semula | Nod lepas poll dalam ~45 saat, PC ambil balik |

Nadi ditulis oleh cron `boz-node-heartbeat` (tiap minit) ke gist, dan dibaca nod dengan
cache-buster (`?cb=<epoch>`) kerana `gist.githubusercontent.com` di-cache CDN ~5 minit.

Kunci provider **tidak** disimpan dalam blob simpanan — ia datang dari GitHub Actions secrets
pada setiap boot (`TELEGRAM_BOT_TOKEN`, `GEMINI_API_KEY`, `GROQ_API_KEY`, `TOKENOMIX_API_KEY`,
`TOKENHARBOR_KEY`).

## Agen Hermes di nod — bukan sekadar chatbot

`/agent` dan setiap tugasan aksi dalam Telegram dijalankan oleh **Hermes Agent v0.19.0
sebenar** di nod, bukan di PC kau. Ia dipasang semula oleh `start.sh` pada setiap boot
(venv sengaja tidak masuk blob simpanan supaya push 2-minit kekal kecil).

Apa yang terbukti pada nod (ujian sebenar, bukan andaian):

| Keupayaan | Bukti |
|---|---|
| Alat terminal | `uname -s` → `Linux`, `hostname` → `runnervm48cm3` |
| Alat fail | tulis + baca semula `/tmp/boz-agent.txt` → `AGENT-OK-NOD` |
| Alat carian web | carian + URL sumber dikembalikan |
| Skills | 9 skill dibawa dari repo; `skill_view` membaca teks sebenar |
| auto_load | `tool-discipline` + `elyy-ops-atlas` disuntik setiap panggilan |

**Model:** `9router` hanya hidup di PC (`127.0.0.1:20128`), jadi ia tidak wujud di nod.
`TELEKEY_AGENT_PLAN` (lalai `deepseek-v4.1-flash|tokenomix`) menukar model agen tanpa
mengubah kod. Provider disediakan `make-config.py` daripada `.env`.

**Had sebenar:** alat `browser` kini berfungsi (Playwright + Chromium dipasang `start.sh`,
~120MB setiap boot). `keys.db` tidak lagi bercabang — `pull-keys.py` + cron 10 minit menggabung
DB nod ke DB PC secara idempotent (`MAX`, bukan tambah, kerana gerbang menjamin hanya satu bot
aktif pada satu masa).

### 9Router Mistral di Hermes — status diukur (bateri 3 saiz tugasan)

| Model | Chat (soalan/kerja) | Tugasan agen | Sesi lama | Nota |
|---|---|---|---|---|
| `mistral/codestral-latest` | lulus | **3/3 lulus** | lulus (ingat konteks) | paling seimbang |
| `mistral/mistral-large-4` | lulus | **3/3 lulus** | belum | paling teliti |
| `mistral/ministral-8b-latest` | lulus | **3/3 lulus bila diulang**, 2/3 dalam larian berturut | belum | kadang tukar aksara literal (`-` → `=`) |
| `mistral/mistral-large-latest` | **dibuang** | — | — | 403 `tier_not_allowed` pada semua 32 akaun |

Bateri mengesahkan kerja dari **kesan fizikal di disk** (fail benar-benar ditulis dan dibaca
semula), bukan dari kata-kata model. Tiada model yang menjawab dengan "ini langkah-langkahnya".
Tugasan yang diuji: kiraan (senang), tulis+baca fail dengan kandungan tepat (sederhana), kira
bilangan fail melalui alat lalu tulis hasil (berat).

Dua peraturan keras dimasukkan ke prompt setiap panggilan agen dan ke `AGENTS.md`:

1. **Kiraan wajib guna alat.** Sebelum ini codestral menjawab `4273` dan ministral `4223` untuk
   47×89 (dua-dua salah). Selepas peraturan: `4183`, dikira dengan `python3`.
2. **Salin literal aksara demi aksara**, kemudian baca semula dan bandingkan.

**Peraturan sesi:** model dikunci semasa sesi dicipta. `--resume` dengan `-m` berbeza akan
ditolak secara reka bentuk; tukar model dari dalam sesi dengan `/model`.

**Pemilihan model automatik:** port `127.0.0.1:20128` tertutup = bukan PC. Bot pilih 9router
bila PC hidup, dan `TELEKEY_AGENT_PLAN` (awan) bila di nod.

---

## Isi kit

| Fail | Fungsi |
|---|---|
| `boz-ssh.sh` | Masuk ke nod (pembungkus, alamat tetap) |
| `keeper.sh` | Penjaga — hantar pengganti sebelum nod tamat |
| `node.sh` | Sediakan sshd + tunnel pada mana-mana Linux |
| `state.sh` | Simpan/pulih `~/persist` (tersulit) |
| `spin-up.sh` | Hidupkan nod manual (jarang perlu) |
| `muse_tunnel.sh` | Script asal kau — untuk kes sandbox yang reset `/etc` |

---

## Batas jujur

- **Bukan VPS kekal.** GitHub Actions hadkan satu job 350 minit. Sistem ini menyelesaikannya
  dengan berganti nod tanpa menukar alamat — bukan dengan mengekalkan satu mesin.
- **Jeda ~40 saat** setiap pertukaran (diukur, bukan dianggarkan).
- **Proses panjang mati** bila nod berganti. Kalau kau jalankan bot berterusan, ia perlu
  auto-mula semula — letak dalam `~/persist/start.sh` dan panggil dari situ.
- **Repo awam.** Hanya kunci *awam* dan blob tersulit ada di sana. Kunci peribadi kekal di PC.
- **GitHub Actions bukan untuk mining/proxy berterusan.** Untuk kerja 24/7 sebenar yang serius,
  VPS berbayar murah (Hetzner €3.79) atau Oracle Always Free masih jawapan yang betul —
  dan `node.sh` yang sama boleh dipakai di sana tanpa ubah satu baris.
