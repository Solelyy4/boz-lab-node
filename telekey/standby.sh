#!/usr/bin/env bash
# =============================================================================
#  standby.sh — jalankan TeleKey HANYA bila PC senyap.
#
#  Telegram hanya benarkan SATU poller per token. TeleKey kau sudah poll di PC.
#  Jadi nod ini bukan pengganti — ia PENUNGGU: ia memerhati nadi PC (gist) dan
#  hanya mengambil alih poll bila nadi berhenti lebih 3 minit.
#
#    PC hidup  -> nod senyap, TeleKey di PC yang layan pengguna
#    PC mati   -> nod ambil alih dalam ~3-4 minit
#    PC hidup semula -> nod lepas poll dalam ~45 saat, PC ambil balik
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HERMES_HOME="$(cd "$HERE/.." && pwd)"   # .env + secrets/ ada di sini

HB_URL="${HB_URL:-https://gist.githubusercontent.com/Solelyy4/d5cdf07feb91d5d89337476d2f9db7ae/raw/alive}"
FRESH="${FRESH:-180}"     # nadi lebih muda dari ini = PC hidup
CHECK="${CHECK:-45}"      # selang pemeriksaan
BOT_CMD="${BOT_CMD:-python3 $HERE/telekey.py}"   # boleh diganti untuk ujian/logik sahaja
LOG="$HERE/standby.log"
PIDF="$HERE/telekey.pid"

say() { echo "[$(date -u '+%F %T')] $*" >> "$LOG"; }

hb_age() {
  local f now
  now="$(date -u +%s)"
  # ?cb= WAJIB: gist.githubusercontent.com di-cache CDN ~5 minit. Tanpa ini
  # nod melihat nadi basi walaupun PC sihat, lalu merampas poll.
  f="$(curl -sS -m 10 "$HB_URL?cb=$now" 2>/dev/null | tr -dc '0-9')"
  [ -n "$f" ] || { echo 999999; return; }
  echo $(( now - f ))
}

running() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

say "penunggu bermula (fresh=${FRESH}s, semak tiap ${CHECK}s)"
while :; do
  age="$(hb_age)"
  if [ "$age" -lt "$FRESH" ]; then
    if running; then
      kill "$(cat "$PIDF")" 2>/dev/null
      sleep 1
      rm -f "$PIDF"
      say "PC hidup semula (nadi ${age}s) — bot dilepas, PC ambil alih"
    fi
  else
    if ! running; then
      nohup $BOT_CMD >> "$HERE/telekey.log" 2>&1 &
      echo $! > "$PIDF"
      say "PC senyap (nadi ${age}s) — bot DIAMBIL ALIH, pid $!"
    fi
  fi
  sleep "$CHECK"
done
