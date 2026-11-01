#!/usr/bin/env bash
# boz-ssh.sh — masuk ke nod kau. Alamat tak berubah walaupun mesin berganti.
#
#   bash boz-ssh.sh                       # shell interaktif
#   bash boz-ssh.sh 'ls ~/persist'        # jalankan satu arahan
#   bash boz-ssh.sh -L 8080:localhost:8080 # teruskan port
#
# Fail kau ada di ~/persist — kekal walaupun nod berganti.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="${KEY:-$HERE/keys/boz_lab}"
HOSTUSER="${HOSTUSER:-runner@bore.pub}"

# Port diambil dari issue node-status: nod boleh jatuh ke port rawak bila port
# tetap dipegang klien zombie, jadi 45001 bukan lagi jaminan.
if [ -z "${PORT:-}" ]; then
  if command -v gh >/dev/null 2>&1; then GHBIN="gh"
  elif [ -x "${LOCALAPPDATA:-}/hermes/bin/gh.exe" ]; then GHBIN="$LOCALAPPDATA/hermes/bin/gh.exe"
  else GHBIN=""; fi
  if [ -n "$GHBIN" ]; then
    PORT="$("$GHBIN" issue list --repo "${REPO_SLUG:-Solelyy4/boz-lab-node}" \
              --search 'node-status in:title' --json body --jq '.[0].body' 2>/dev/null \
            | sed -n 's/^PORT=\([0-9][0-9]*\).*/\1/p' | head -1)"
  fi
fi
PORT="${PORT:-45001}"

[ -f "$KEY" ] || { echo "kunci tidak dijumpai: $KEY" >&2; exit 1; }

# Host key berubah setiap pertukaran nod, jadi semakan host key dimatikan.
# Keselamatan tetap dari kunci peribadi: hanya pemegang $KEY boleh masuk.
OPTS=(-p "$PORT" -i "$KEY"
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
      -o ServerAliveInterval=30 -o ServerAliveCountMax=3)

# Argumen: kalau bermula dengan '-' ia opsyen ssh (-L, -v, ...), kalau tidak ia arahan jauh.
# Hos mesti disebut SEBELUM arahan jauh, kalau tidak ssh menyangka arahan itu hos.
if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
  exec ssh "${OPTS[@]}" "$HOSTUSER" "$@"
else
  exec ssh "${OPTS[@]}" "$@" "$HOSTUSER"
fi
