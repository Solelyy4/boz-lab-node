#!/usr/bin/env bash
# =============================================================================
#  keeper.sh — penjaga nod. Jalankan berkala (cron). Tiada output kalau sihat.
#
#  Tugasnya cuma satu: bila nod sekarang hampir tamat, hidupkan pengganti.
#  Port dikunci (45001) supaya alamat SSH tidak berubah selepas pertukaran.
#
#     bash keeper.sh          # pemeriksaan biasa
#     bash keeper.sh --force  # paksa nod baru (untuk ujian)
# =============================================================================
set -uo pipefail

REPO="${REPO:-Solelyy4/boz-lab-node}"
WF="${WF:-ephemeral-node.yml}"
PORT="${PORT:-45001}"
MINUTES="${MINUTES:-350}"
LEAD="${LEAD:-480}"          # saat sebelum tamat untuk mula hidupkan pengganti
LOG="${LOG:-$HOME/.boz-node/keeper.log}"

mkdir -p "$(dirname "$LOG")"
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

if command -v gh >/dev/null 2>&1; then GH="gh"
elif [ -x "${LOCALAPPDATA:-}/hermes/bin/gh.exe" ]; then GH="$LOCALAPPDATA/hermes/bin/gh.exe"
else log "gh tidak dijumpai"; exit 1; fi

now=$(date -u +%s)

# 1. Jangan hantar dua pengganti berturut-turut.
STAMP="$HOME/.boz-node/last_dispatch"
if [ -f "$STAMP" ] && [ "${1:-}" != "--force" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  if [ $(( now - last )) -lt 900 ]; then
    log "sihat: pengganti dihantar $(( now - last ))s lalu"
    exit 0
  fi
fi

# 2. Bila nod sekarang tamat?
body=$("$GH" issue list --repo "$REPO" --state open --search 'node-status in:title' \
  --json body --jq '.[0].body // ""' 2>/dev/null)
exp=$(printf '%s\n' "$body" | sed -n 's/^EXPIRES_UTC=\([0-9]*\).*/\1/p' | head -1)

if [ -n "$exp" ] && [ "${1:-}" != "--force" ]; then
  left=$(( exp - now ))
  if [ "$left" -gt "$LEAD" ]; then
    log "sihat: nod hidup lagi ${left}s"
    exit 0
  fi
  log "nod tamat dalam ${left}s — hidupkan pengganti"
else
  log "tiada nod sah — hidupkan baru"
fi

"$GH" workflow run "$WF" --repo "$REPO" -f minutes="$MINUTES" -f port="$PORT" >/dev/null 2>&1 \
  && { date -u +%s > "$STAMP"; log "pengganti dihantar (port $PORT, $MINUTES min)"; } \
  || log "GAGAL menghantar pengganti"
