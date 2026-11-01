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
[ -f "$HERMES_HOME/.env" ] && { set -a; . "$HERMES_HOME/.env"; set +a; }
# Nod tiada 9router (ia hidup di PC). Rancangan model agen ditimpa di sini.
export TELEKEY_AGENT_PLAN="${TELEKEY_AGENT_PLAN:-deepseek-v4.1-flash|tokenomix,deepseek-v4-flash|tokenomix}"

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

# --- Pemilikan nod -----------------------------------------------------------
# Boleh ada lebih satu nod hidup serentak (pengganti bermula sebelum yang lama
# tamat). Telegram hanya benarkan SATU poller; kalau dua ambil alih, kedua-dua
# dapat 409. Nod terbaharu menulis OWNER=<run_id> ke issue node-status, jadi
# hanya pemilik dibenarkan poll. Fail-open bila issue tak terjangkau: lebih baik
# cuba (mungkin 409) daripada bot senyap sepenuhnya.
OWNER_URL="https://api.github.com/repos/Solelyy4/boz-lab-node/issues?state=open&per_page=10"
_owner_cache_ts=0
_owner_cache=""
am_owner() {
  local now run
  now=$(date -u +%s)
  run="${GITHUB_RUN_ID:-}"
  [ -z "$run" ] && return 0          # bukan dalam Actions: anggap pemilik
  if [ $(( now - _owner_cache_ts )) -gt 300 ]; then
    _owner_cache=$(curl -sS -m 10 -H "Accept: application/vnd.github+json" "$OWNER_URL" 2>/dev/null \
      | tr ',' '\n' | grep -o 'OWNER=[0-9]*' | tail -1 | cut -d= -f2)
    _owner_cache_ts=$now
  fi
  [ -z "$_owner_cache" ] && return 0  # tiada maklumat: fail-open
  [ "$_owner_cache" = "$run" ]
}

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
      if am_owner; then
        nohup $BOT_CMD >> "$HERE/telekey.log" 2>&1 &
        echo $! > "$PIDF"
        say "PC senyap (nadi ${age}s) — bot DIAMBIL ALIH, pid $!"
      else
        say "PC senyap (nadi ${age}s) tetapi nod lain (OWNER=${_owner_cache:-?}) pemilik — berdiam"
      fi
    elif ! am_owner; then
      # Nod lebih baru sudah mengambil alih: lepaskan poll supaya tiada 409.
      kill "$(cat "$PIDF")" 2>/dev/null
      sleep 1
      rm -f "$PIDF"
      say "nod lain jadi pemilik — bot dilepas"
    fi
  fi
  sleep "$CHECK"
done
