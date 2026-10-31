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
