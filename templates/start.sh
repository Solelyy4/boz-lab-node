#!/usr/bin/env bash
# =============================================================================
#  ~/persist/start.sh — dipanggil AUTOMATIK setiap kali nod baharu hidup.
#
#  Guna fail ini untuk: pasang semula pakej (mesin baru = mesin kosong) dan
#  hidupkan proses kau (bot, server, cron) tanpa kau sentuh apa-apa.
#
#  Ia berjalan SELEPAS fail ~/persist dipulihkan, jadi fail kau sudah ada.
# =============================================================================
set -u
cd "$(dirname "$0")" || exit 1
exec >> "$HOME/persist/start.log" 2>&1
echo "===== mula $(date -u '+%F %T') UTC ====="

# --- 1. Pakej yang hilang (mesin baru tiada apa-apa) -------------------------
command -v python3 >/dev/null || sudo apt-get install -y -qq python3 python3-pip
command -v git     >/dev/null || sudo apt-get install -y -qq git

# Contoh: pakej python yang bot kau perlukan
python3 -c "import telegram" 2>/dev/null || pip install -q --break-system-packages python-telegram-bot

# --- 2. Hidupkan proses kau (jangan mula dua kali) ---------------------------
if ! pgrep -f "bot.py" >/dev/null 2>&1; then
  nohup python3 "$HOME/persist/bot.py" >> "$HOME/persist/bot.log" 2>&1 &
  echo "bot dihidupkan pid $!"
else
  echo "bot sudah berjalan — langkau"
fi

echo "===== selesai ====="
