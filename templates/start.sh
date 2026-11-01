#!/usr/bin/env bash
# =============================================================================
#  ~/persist/start.sh — dipanggil AUTOMATIK setiap kali nod baharu hidup.
#
#  Ia berjalan SELEPAS fail ~/persist dipulihkan, jadi fail kau sudah ada.
#  Tugasnya: pasang semula kebergantungan (mesin baru = mesin kosong), kemudian
#  serahkan kepada penunggu yang memutuskan sama ada bot perlu diambil alih.
#
#  PENTING: pengawal guna pidfile, BUKAN `pgrep -f`. `pgrep -f` mudah
#  memadankan baris arahan shell yang memanggil skrip ini.
# =============================================================================
set -u
cd "$(dirname "$0")" || exit 1
# Kunci provider datang dari .env (ditulis workflow dari Actions secrets).
# Tanpanya make-config.py tidak dapat menjana config.yaml untuk agen.
[ -f ./.env ] && { set -a; . ./.env; set +a; }
STAMP=$(date -u '+%F %T')
echo "=== $STAMP pada $(hostname) ===" >> start.log
echo "start.sh jalan pada $STAMP di $(hostname)" > start-result.txt

# --- 1. Kebergantungan (mesin baru tiada apa-apa) ----------------------------
command -v python3 >/dev/null || sudo apt-get install -y -qq python3
if ! python3 -c "import telegram" >/dev/null 2>&1; then
  echo "memasang python-telegram-bot" >> start.log
  pip install -q --break-system-packages "python-telegram-bot==22.*" >> start.log 2>&1 \
    || pip3 install -q --break-system-packages "python-telegram-bot==22.*" >> start.log 2>&1 \
    || echo "GAGAL memasang PTB - bot mungkin tidak jalan" >> start.log
fi

# --- 1b. Agen Hermes (untuk /agent dan laluan agen) --------------------------
# venv SENGAJA tidak masuk blob simpanan (100MB, dipush tiap 2 minit). Pasang
# semula setiap boot; ~90 saat, dan start.sh berjalan di latar jadi bot tak tunggu.
if [ ! -x "$PWD/bin/hermes" ]; then
  echo "memasang hermes-agent" >> start.log
  python3 -m venv "$PWD/hvenv" >> start.log 2>&1
  "$PWD/hvenv/bin/pip" install -q --upgrade pip >> start.log 2>&1
  "$PWD/hvenv/bin/pip" install -q hermes-agent >> start.log 2>&1 \
    || echo "GAGAL memasang hermes-agent - /agent akan mati" >> start.log
  mkdir -p "$PWD/bin"
  ln -sf "$PWD/hvenv/bin/hermes" "$PWD/bin/hermes"
fi
if [ -x "$PWD/hvenv/bin/python" ] && [ -f "$PWD/make-config.py" ]; then
  "$PWD/hvenv/bin/python" "$PWD/make-config.py" >> start.log 2>&1 \
    && echo "config.yaml agen dijana" >> start.log
fi
# Pelayar: chromium ~120MB, cache di ~/.cache (bukan persist) jadi ia hilang
# setiap boot. Tanpa ini alat browser dalam /agent gagal.
if [ -x "$PWD/hvenv/bin/python" ] && [ ! -d "$HOME/.cache/ms-playwright" ]; then
  echo "memasang playwright + chromium" >> start.log
  "$PWD/hvenv/bin/pip" install -q playwright >> start.log 2>&1 \
    && "$PWD/hvenv/bin/playwright" install chromium >> start.log 2>&1 \
    && echo "chromium sedia" >> start.log \
    || echo "GAGAL playwright - alat browser tiada" >> start.log
fi

# --- 2. Hidupkan penunggu -----------------------------------------------------
if [ -f standby.pid ] && kill -0 "$(cat standby.pid)" 2>/dev/null; then
  echo "penunggu sudah berjalan (pid $(cat standby.pid)) - langkau" >> start.log
elif [ -f telekey/standby.sh ]; then
  nohup bash telekey/standby.sh >> standby.out 2>&1 &
  echo $! > standby.pid
  echo "penunggu dihidupkan pid $!" >> start.log
else
  echo "tiada telekey/standby.sh - tiada bot dihidupkan" >> start.log
fi

echo "=== selesai ===" >> start.log
