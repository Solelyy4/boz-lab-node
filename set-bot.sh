#!/usr/bin/env bash
# =============================================================================
#  set-bot.sh — pasang token bot pada nod, hidupkan, dan sahkan.
#
#     bash set-bot.sh <TOKEN>
#
#  Token dihantar melalui saluran SSH (stdin), bukan argumen arahan, jadi ia
#  tidak muncul dalam senarai proses pada nod.
#
#  PENTING: token mesti token bot BERASINGAN. Jangan guna token TeleKey —
#  Telegram hanya benarkan satu poller per token; dua akan berkelahi (409).
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
  cat <<'EOF'
Penggunaan: bash set-bot.sh <TOKEN>

Cara dapat token (2 minit):
  1. Buka Telegram, cari @BotFather
  2. Hantar /newbot, ikut langkah, pilih nama
  3. BotFather balas token: 1234567890:AAF...
  4. Jalankan: bash set-bot.sh "1234567890:AAF..."

JANGAN guna token TeleKey — ia sudah berjalan di PC dan akan berkelahi (409).
EOF
  exit 1
fi

case "$TOKEN" in
  *:*[0-9A-Za-z_-]*) : ;;
  *) echo "Format token tidak sah (patut <angka>:<rentetan>)." >&2; exit 1 ;;
esac

echo "  · sahkan token dengan getMe"
ME=$(curl -sS -m 20 "https://api.telegram.org/bot${TOKEN}/getMe" 2>/dev/null)
echo "$ME" | grep -q '"ok":true' || { echo "  ✗ token ditolak Telegram: $ME" >&2; exit 1; }
BOT=$(echo "$ME" | python -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['username'])")
echo "  ✓ token sah: @$BOT"

echo "  · semak tiada poller lain pada token ini"
CONF=$(curl -sS -m 20 "https://api.telegram.org/bot${TOKEN}/getUpdates?timeout=0&limit=1" 2>/dev/null)
if echo "$CONF" | grep -q '"error_code":409'; then
  echo "  ✗ token ini sudah dipoll di tempat lain (409). Guna token bot baharu." >&2
  exit 1
fi

echo "  · hantar token ke nod melalui SSH (stdin)"
printf 'TG_TOKEN=%s\n' "$TOKEN" | bash "$HERE/boz-ssh.sh" \
  'cat > ~/persist/.env && chmod 600 ~/persist/.env && echo "  ✓ .env ditulis"' 2>&1 || exit 1

echo "  · hidupkan bot melalui start.sh"
bash "$HERE/boz-ssh.sh" '
  kill "$(cat ~/persist/bot.pid 2>/dev/null)" 2>/dev/null; sleep 1
  rm -f ~/persist/bot.pid ~/persist/bot.log
  bash ~/persist/start.sh
  sleep 5
  echo "  pid: $(cat ~/persist/bot.pid 2>/dev/null)"
  tail -3 ~/persist/bot.log 2>/dev/null' 2>&1

echo
echo "  ✓ Siap. Buka Telegram, hantar /start kepada @$BOT"
echo "    Bot ini akan hidup semula sendiri setiap kali nod berganti."
