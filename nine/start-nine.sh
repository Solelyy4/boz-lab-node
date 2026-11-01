#!/usr/bin/env bash
# start-nine.sh — hidupkan 9router DI NOD supaya Mistral kekal ada walaupun
# laptop BOZ mati. Data (32 sambungan Mistral) tinggal dalam ~/persist/nine,
# jadi ia diwarisi setiap nod baru melalui blob simpanan yang tersulit.
#
#   bash start-nine.sh          # hidupkan (selamat dijalankan berulang)
#   bash start-nine.sh stop     # hentikan
#   bash start-nine.sh status
set -u
HOME_DIR="${HOME:-/home/runner}"
DATA="$HOME_DIR/persist/nine"
PIDF="$DATA/9router.pid"
LOG="$HOME_DIR/persist/9router.log"
PORT="${NINE_PORT:-20128}"
BIN="$HOME_DIR/persist/npm/bin/9router"

export PATH="$HOME_DIR/persist/npm/bin:$PATH"

alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
listening() { (ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null) | grep -q "[:.]$PORT "; }

# Kunci API 9router mesti ada dalam .env supaya upstream bot (yang membaca
# HERMES_CUSTOM_9ROUTER_API_KEY) boleh memanggil 9router di nod ini.
# Dijalankan walau 9router sudah hidup — kalau tidak, nod warisan tiada kunci.
sync_key() {
  local envf="$HOME_DIR/persist/.env" key
  [ -f "$envf" ] || return 0
  key=$(python3 - "$DATA/db/data.sqlite" <<'PY'
import sqlite3, sys
try:
    c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    row = c.execute("SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1").fetchone()
    print(row[0] if row else "")
except Exception:
    print("")
PY
)
  [ -n "$key" ] || return 0
  grep -q '^HERMES_CUSTOM_9ROUTER_API_KEY=' "$envf" \
    || printf 'HERMES_CUSTOM_9ROUTER_API_KEY=%s\n' "$key" >> "$envf"
  chmod 600 "$envf"
}

case "${1:-start}" in
  stop)
    if alive; then kill "$(cat "$PIDF")" 2>/dev/null; sleep 2; fi
    rm -f "$PIDF"; echo "dihentikan"; exit 0 ;;
  status)
    alive && echo "proses hidup pid $(cat "$PIDF")" || echo "proses mati"
    listening && echo "port $PORT mendengar" || echo "port $PORT tertutup"
    exit 0 ;;
esac

if alive && listening; then echo "sudah jalan pid $(cat "$PIDF")"; sync_key; exit 0; fi

# 1. Pasang jika belum ada (mesin baru = kosong; venv/node_modules tidak disimpan)
if [ ! -x "$BIN" ]; then
  echo "memasang 9router dari npm"
  mkdir -p "$HOME_DIR/persist/npm"
  npm install -g --prefix "$HOME_DIR/persist/npm" 9router@0.5.111 >/dev/null 2>&1 \
    || { echo "GAGAL memasang 9router"; exit 1; }
fi

# 2. Data dir: ~/.9router mesti menghala ke persist supaya DB disimpan
mkdir -p "$DATA/db"
if [ -e "$HOME_DIR/.9router" ] && [ ! -L "$HOME_DIR/.9router" ]; then
  cp -n "$HOME_DIR/.9router/db/data.sqlite" "$DATA/db/data.sqlite" 2>/dev/null
  cp -n "$HOME_DIR/.9router/jwt-secret" "$DATA/jwt-secret" 2>/dev/null
  cp -n "$HOME_DIR/.9router/machine-id" "$DATA/machine-id" 2>/dev/null
  rm -rf "$HOME_DIR/.9router"
fi
ln -sfn "$DATA" "$HOME_DIR/.9router"
chmod 600 "$DATA/db/data.sqlite" "$DATA/jwt-secret" "$DATA/machine-id" 2>/dev/null

# 3. Mula
: > "$LOG"
nohup "$BIN" --port "$PORT" --no-browser --skip-update >> "$LOG" 2>&1 &
echo $! > "$PIDF"
for _ in $(seq 1 20); do
  sleep 1
  listening && break
  alive || break
done

if listening; then
  # Kunci API 9router mesti masuk .env supaya upstream bot (yang membaca
  # HERMES_CUSTOM_9ROUTER_API_KEY) boleh memanggil 9router di nod ini.
  ENVF="$HOME_DIR/persist/.env"
  KEY=$(python3 - "$DATA/db/data.sqlite" <<'PY'
import sqlite3, sys
try:
    c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    row = c.execute("SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1").fetchone()
    print(row[0] if row else "")
except Exception:
    print("")
PY
)
  if [ -n "$KEY" ] && [ -f "$ENVF" ]; then
    grep -q '^HERMES_CUSTOM_9ROUTER_API_KEY=' "$ENVF" \
      || printf 'HERMES_CUSTOM_9ROUTER_API_KEY=%s\n' "$KEY" >> "$ENVF"
    chmod 600 "$ENVF"
  fi
  echo "9router hidup pid $(cat "$PIDF") pada $PORT"
  exit 0
fi
echo "GAGAL menghidupkan 9router — log:"; tail -6 "$LOG"; exit 1
