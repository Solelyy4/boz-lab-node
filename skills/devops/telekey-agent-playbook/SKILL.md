---
name: telekey-agent-playbook
description: "Use when the TeleKey bot agent installs or fetches anything."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [telekey, agent, install, github, verification]
---

# TeleKey Agent Playbook

Resepi terbukti (diuji 1 Nov 2026 pada mistral-large-4, codestral, ministral-8b melalui 9Router).
Guna skill ini bila tugasan melibatkan fail, GitHub, pakej, atau data luar.

## 1. Path dan fail

- Sentiasa path penuh dengan garis condong: `C:/Users/zahin/Downloads/x.txt`.
- `read_file` gagal **bukan** bukti fail tiada. Semak dulu: `ls -la "C:/..."` atau
  `python -c "import os;print(os.path.exists(r'C:/...'))"`.
- Lepas tulis fail, baca semula dan bandingkan isi dengan apa yang diminta (read-after-write).

## 2. Install dari GitHub (yang benar-benar jalan pada host ini)

| Sasaran | Arahan betul | Jangan guna |
|---|---|---|
| Clone repo | `git clone https://github.com/USER/REPO.git` | `git@github.com:...` (SSH, publickey ditolak) |
| Pakej npm dari GitHub | `npm install https://github.com/USER/REPO/tarball/BRANCH` | `npm install github:user/repo` (npm gagal pada host ini) |
| Pakej python dari GitHub | `python -m ensurepip` dulu, kemudian `python -m pip install git+https://github.com/USER/REPO.git` | `python -m pip` tanpa ensurepip |
| Fail tunggal dari repo | `curl -L https://raw.githubusercontent.com/USER/REPO/BRANCH/path -o out.txt` | meneka isi fail |

Selepas install, **uji** dengan arahan sebenar (`node -e`, `python -c "import x"`) dan sebut output ujian itu.

## 3. Ambil data luar (jujur, bukan halusinasi)

1. Simpan respons mentah dulu: `curl -s URL -o fail.json`.
2. Baca fail itu, sebut nilai dari fail — bukan dari ingatan.
3. Kalau angka berubah antara dua panggilan, itu cache/edge GitHub; sebut nilai yang ada dalam fail
   yang kamu tulis dan jangan bulatkan/karang.

## 4. Verifikasi sebelum lapor siap

- Fail wujud? `ls` sahkan. Skrip jalan? jalankan. Angka betul? bandingkan dengan sumber.
- Jangan lapor "berjaya" tanpa satu pun bukti di atas.
- Kalau satu langkah gagal dua kali, tukar pendekatan (HTTPS tarball, curl, gh CLI), jangan ulang sama.

## 5. Gaya jawapan

Bahasa Melayu padat, tanpa markdown (tiada `*`, `#`, backtick, jadual paip). Senarai guna `•` atau nombor.
Sebut apa yang dibuat, bukti ringkas, dan path fail yang dihasilkan supaya bot boleh hantar fail itu.
