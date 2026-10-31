#!/usr/bin/env bash
# =============================================================================
#  spin-up.sh — hidupkan hos Linux percuma, cetak arahan SSH. (jalankan di PC)
#
#     bash spin-up.sh            # nod 120 minit
#     bash spin-up.sh 300        # nod 300 minit (maks 350)
#     bash spin-up.sh 120 --test # hidupkan + uji SSH terus
#
#  Guna GitHub Actions sebagai hos. Tiada kad, tiada akaun baharu — guna
#  akaun GitHub BOZ yang sudah login dalam gh.
# =============================================================================
set -euo pipefail

MIN="${1:-120}"
case "$MIN" in ''|*[!0-9]*) echo "minit mesti nombor"; exit 1 ;; esac
[ "$MIN" -le 350 ] || { echo "maksimum 350 minit"; exit 1; }
DO_TEST=0
[ "${2:-}" = "--test" ] && DO_TEST=1

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-Solelyy4/boz-lab-node}"
KEY="${KEY:-$HERE/keys/boz_lab}"

if command -v gh >/dev/null 2>&1; then GH="gh"
elif [ -x "${LOCALAPPDATA:-}/hermes/bin/gh.exe" ]; then GH="$LOCALAPPDATA/hermes/bin/gh.exe"
else echo "  ✗ gh tidak dijumpai"; exit 1; fi

[ -f "$KEY" ] || { echo "  ✗ private key tidak dijumpai: $KEY"; exit 1; }

echo "  · menghidupkan nod ($MIN minit) di $REPO"
PREV="$("$GH" issue list --repo "$REPO" --search 'node-status in:title' --state open --json number --jq '.[0].number // 0' 2>/dev/null || echo 0)"
"$GH" workflow run ephemeral-node.yml --repo "$REPO" -f minutes="$MIN" >/dev/null

echo "  · menunggu nod siap (biasanya 60-90 saat)"
SSH_CMD=""
for i in $(seq 1 50); do
  sleep 6
  NUM="$("$GH" issue list --repo "$REPO" --search 'node-status in:title' --state open --json number --jq '.[0].number // 0' 2>/dev/null || echo 0)"
  if [ -n "$NUM" ] && [ "$NUM" != "0" ] && [ "$NUM" != "${PREV:-0}" ]; then
    BODY="$("$GH" issue view "$NUM" --repo "$REPO" --json body --jq '.body' 2>/dev/null || true)"
    SSH_CMD="$(printf '%s\n' "$BODY" | grep -m1 '^ssh -p')"
    [ -n "$SSH_CMD" ] && break
  fi
done

[ -n "$SSH_CMD" ] || { echo "  ✗ nod tidak melapor alamat — semak: $GH run list --repo $REPO"; exit 1; }

PORT="${SSH_CMD#ssh -p }"; PORT="${PORT%% *}"
HOSTUSER="${SSH_CMD##* }"
HOST="${HOSTUSER#*@}"; USER_="${HOSTUSER%@*}"

echo
echo "  ✓ nod hidup"
echo
echo "     $SSH_CMD"
echo
echo "     arahan penuh:"
echo "     ssh -i \"$KEY\" -p $PORT -o StrictHostKeyChecking=no $USER_@$HOST"
echo

if [ "$DO_TEST" = "1" ]; then
  echo "  · ujian sambungan"
  for i in 1 2 3 4 5; do
    if OUT="$(timeout 30 ssh -i "$KEY" -p "$PORT" -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=12 \
        "$USER_@$HOST" 'echo "$(whoami)@$(hostname)"; . /etc/os-release; echo "$PRETTY_NAME"; nproc; free -m | sed -n 2p' 2>&1 | grep -v '^Warning: Permanently')"; then
      echo "  ✓ SSH BERJAYA"; echo "$OUT" | sed 's/^/     /'; break
    fi
    echo "     cubaan $i gagal, ulang..."; sleep 12
  done
fi
