#!/usr/bin/env bash
# =============================================================================
#  ~/persist/start.sh — dipanggil AUTOMATIK setiap kali nod baharu hidup.
#
#  Ia berjalan SELEPAS fail ~/persist dipulihkan, jadi fail kau sudah ada.
#  Guna fail ini untuk pasang semula pakej (mesin baru = mesin kosong) dan
#  hidupkan proses kau tanpa kau sentuh apa-apa.
#
#  PENTING: pengawal guna pidfile, BUKAN `pgrep -f`. `pgrep -f` mudah
#  memadankan baris arahan shell yang memanggil skrip ini, jadi ia menyangka
#  proses sudah berjalan dan melangkaunya.
# =============================================================================
set -u
cd "$(dirname "$0")" || exit 1
STAMP=$(date -u '+%F %T')
echo "=== $STAMP pada $(hostname) ===" >> start.log
echo "start.sh jalan pada $STAMP di $(hostname)" > start-result.txt

# --- 1. Pakej yang hilang (mesin baru tiada apa-apa) -------------------------
command -v python3 >/dev/null || sudo apt-get install -y -qq python3

# --- 2. Hidupkan proses kau --------------------------------------------------
if [ -f bot.pid ] && kill -0 "$(cat bot.pid)" 2>/dev/null; then
  echo "bot sudah berjalan (pid $(cat bot.pid)) - langkau" >> start.log
else
  nohup python3 "$PWD/bot.py" >> "$PWD/bot.log" 2>&1 &
  echo $! > bot.pid
  echo "bot dihidupkan pid $!" >> start.log
fi

echo "=== selesai ===" >> start.log
