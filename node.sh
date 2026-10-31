#!/usr/bin/env bash
# =============================================================================
#  node.sh — jadikan mesin ini boleh di-SSH dari mana-mana, tanpa router/NAT.
#  Diuji pada Ubuntu 24.04 (Debian-family). Juga jalan pada container tanpa
#  systemd dan mesin tanpa cron.
#
#  Cara pakai (1 arahan):
#     sudo bash node.sh install --key "ssh-ed25519 AAAA... kamu@pc"
#     sudo bash node.sh url
#     sudo bash node.sh status
#     sudo bash node.sh stop
#
#  Aliran: sshd dipasang/dikunci ke kunci awam -> tunnel awam (bore.pub)
#  dibuka -> alamat SSH dicetak. Tiada akaun, tiada token, tiada bayaran.
# =============================================================================
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:-bore.pub}"
BORE_VERSION="${BORE_VERSION:-0.6.0}"
STATE_DIR="${STATE_DIR:-/var/lib/boz-node}"
KEY_SRC="${KEY_SRC:-}"
REQ_PORT="${REQ_PORT:-0}"
SSH_PORT_TARGET="${SSH_PORT_TARGET:-22}"

C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'; C_ERR=$'\033[1;31m'; C_OFF=$'\033[0m'
[ -t 1 ] || { C_OK=""; C_WARN=""; C_ERR=""; C_OFF=""; }
ok()  { echo "${C_OK}  ✓ $*${C_OFF}"; }
warn(){ echo "${C_WARN}  ! $*${C_OFF}"; }
die() { echo "${C_ERR}  ✗ $*${C_OFF}" >&2; exit 1; }

say() { echo "  · $*"; }

# --- siapa pengguna sebenar (bila dijalankan melalui sudo) -------------------
real_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then echo "$SUDO_USER"
  else id -un; fi
}
user_home() { getent passwd "$1" | cut -d: -f6; }

need_root() { [ "$(id -u)" = "0" ] || die "perlu root — jalankan: sudo bash $0 $*"; }

pkg_install() {
  local pkgs=("$@") missing=()
  if command -v dpkg-query >/dev/null 2>&1; then
    for p in "${pkgs[@]}"; do
      dpkg-query -W -f '${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
    done
    [ ${#missing[@]} -eq 0 ] && return 0
    say "memasang: ${missing[*]}"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q openssh-server curl tar
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache openssh curl tar
  else
    warn "pengurus pakej tidak dikenali — pastikan openssh-server, curl, tar ada"
  fi
}

sshd_bin() {
  for b in /usr/sbin/sshd /usr/local/sbin/sshd /sbin/sshd; do
    [ -x "$b" ] && { echo "$b"; return 0; }
  done
  command -v sshd 2>/dev/null || return 1
}

listening() { (ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null) | grep -qE "[:.]${SSH_PORT_TARGET}[[:space:]]"; }

# --- 1. kunci awam ------------------------------------------------------------
resolve_key() {
  local k=""
  if [ -n "$KEY_SRC" ]; then
    [ -f "$KEY_SRC" ] && k="$(tr -d '\r' < "$KEY_SRC")" || k="$KEY_SRC"
  elif [ -f "./authorized_keys.pub" ]; then
    k="$(tr -d '\r' < ./authorized_keys.pub)"
  else
    local u; u="$(real_user)"
    [ -f "$(user_home "$u")/.ssh/authorized_keys" ] && k="$(tr -d '\r' < "$(user_home "$u")/.ssh/authorized_keys")"
  fi
  echo "$k" | grep -qE '^(ssh-|ecdsa-|sk-)' || die "tiada kunci awam. Beri: --key \"ssh-ed25519 AAAA... kamu@pc\""
  echo "$k"
}

install_key() {
  local u h k
  u="$(real_user)"; h="$(user_home "$u")"
  k="$(resolve_key)"
  install -d -m 700 -o "$u" -g "$(id -gn "$u")" "$h/.ssh"
  touch "$h/.ssh/authorized_keys"
  grep -qF -- "$k" "$h/.ssh/authorized_keys" || echo "$k" >> "$h/.ssh/authorized_keys"
  chown "$u":"$(id -gn "$u")" "$h/.ssh/authorized_keys"
  chmod 600 "$h/.ssh/authorized_keys"
  # sshd kadangkala membaca home root walaupun login sebagai user lain
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    local rh; rh="$(user_home root)"
    if [ -n "$rh" ] && [ "$rh" != "$h" ]; then
      install -d -m 700 "$rh/.ssh"
      touch "$rh/.ssh/authorized_keys"; chmod 600 "$rh/.ssh/authorized_keys"
      grep -qF -- "$k" "$rh/.ssh/authorized_keys" || echo "$k" >> "$rh/.ssh/authorized_keys"
    fi
  fi
  ok "kunci awam didaftarkan untuk user '$u'"
}

# --- 2. sshd ------------------------------------------------------------------
setup_sshd() {
  local sbin; sbin="$(sshd_bin)" || die "sshd tidak dijumpai selepas pemasangan"
  mkdir -p /run/sshd
  "$sbin" -A >/dev/null 2>&1 || true

  mkdir -p /etc/ssh/sshd_config.d
  if ! grep -qiE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config 2>/dev/null; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
  fi
  # Tiada AllowUsers — runner/ubuntu/root semua nama user berbeza antara hos.
  # Awalan 00- WAJIB: sshd guna nilai PERTAMA yang dijumpai, dan imej awan
  # meletakkan PasswordAuthentication yes dalam 50-cloud-init.conf.
  rm -f /etc/ssh/sshd_config.d/99-boz-node.conf
  printf '%s\n' \
    '# boz-node: kunci sahaja, tiada password' \
    'PasswordAuthentication no' \
    'KbdInteractiveAuthentication no' \
    'PermitEmptyPasswords no' \
    'PubkeyAuthentication yes' > /etc/ssh/sshd_config.d/00-boz-node.conf

  if ! "$sbin" -t 2>/tmp/boz-sshd-t.err; then
    rm -f /etc/ssh/sshd_config.d/00-boz-node.conf
    die "sshd menolak konfigurasi: $(tr '\n' ' ' < /tmp/boz-sshd-t.err)"
  fi

  if listening; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
    else
      pkill -HUP -f 'sshd.*-D' 2>/dev/null || true
    fi
  fi

  if ! listening; then
    if command -v systemctl >/dev/null 2>&1 && systemctl restart ssh 2>/dev/null; then :
    elif command -v systemctl >/dev/null 2>&1 && systemctl restart sshd 2>/dev/null; then :
    else
      "$sbin" || true
    fi
    for _ in 1 2 3 4 5 6 7 8; do listening && break; sleep 1; done
  fi
  listening || die "sshd tidak mendengar di port $SSH_PORT_TARGET"

  if "$sbin" -T 2>/dev/null | grep -qi '^passwordauthentication no'; then
    ok "sshd aktif di port $SSH_PORT_TARGET — login kunci sahaja"
  else
    warn "sshd aktif tetapi password masih dibenarkan — semak /etc/ssh/sshd_config"
  fi
}

# --- 3. tunnel awam (bore.pub) ------------------------------------------------
bore_target() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "x86_64-unknown-linux-musl" ;;
    aarch64|arm64) echo "aarch64-unknown-linux-musl" ;;
    armv7l)        echo "armv7-unknown-linux-musleabihf" ;;
    *) die "seni bina $(uname -m) tiada binari bore" ;;
  esac
}

bore_bin() {
  local b="$STATE_DIR/bore"
  if [ -x "$b" ]; then echo "$b"; return 0; fi
  mkdir -p "$STATE_DIR"
  local t url tmp; t="$(bore_target)"
  url="https://github.com/ekzhang/bore/releases/download/v${BORE_VERSION}/bore-v${BORE_VERSION}-${t}.tar.gz"
  say "memuat turun bore ($t)" >&2
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/bore.tar.gz" "$url" || die "gagal muat turun bore: $url"
  tar xzf "$tmp/bore.tar.gz" -C "$tmp"
  install -m 755 "$tmp/bore" "$b"
  rm -rf "$tmp"
  echo "$b"
}

bore_pid() {
  [ -f "$STATE_DIR/bore.pid" ] || return 1
  local p; p="$(cat "$STATE_DIR/bore.pid" 2>/dev/null || true)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo "$p"
}

start_tunnel() {
  local b; b="$(bore_bin)"
  stop_tunnel quiet
  local args=(local "$SSH_PORT_TARGET" --to "$PUBLIC_HOST")
  [ "$REQ_PORT" != "0" ] && args+=(--port "$REQ_PORT")

  # Port tetap: kalau nod lama belum lepas port, cuba semula sampai 12 minit.
  # Ini yang membolehkan alamat SSH kekal sama selepas pertukaran nod.
  local attempt max=36
  for attempt in $(seq 1 "$max"); do
    : > "$STATE_DIR/bore.log"
    nohup "$b" "${args[@]}" >> "$STATE_DIR/bore.log" 2>&1 &
    local p=$!
    echo "$p" > "$STATE_DIR/bore.pid"
    date +%s > "$STATE_DIR/started"
    local i ok=0
    for i in $(seq 1 10); do
      sleep 2
      grep -qiE 'listening at|remote_port' "$STATE_DIR/bore.log" && { ok=1; break; }
      kill -0 "$p" 2>/dev/null || break
    done
    [ "$ok" = "1" ] && break
    kill "$p" 2>/dev/null || true
    if [ "$REQ_PORT" = "0" ] || [ "$attempt" = "$max" ]; then
      die "bore gagal: $(tail -n 2 "$STATE_DIR/bore.log" | tr '\n' ' ')"
    fi
    say "port $REQ_PORT belum bebas (cubaan $attempt/$max) — tunggu 20s" >&2
    sleep 20
  done

  local addr
  addr="$(grep -oE 'listening at [^ ]+' "$STATE_DIR/bore.log" | tail -1 | awk '{print $3}')"
  [ -n "$addr" ] || die "bore tidak memberi alamat: $(tr '\n' ' ' < "$STATE_DIR/bore.log")"
  local host="${addr%:*}" port="${addr##*:}"
  printf 'ssh -p %s %s@%s\n' "$port" "$(real_user)" "$host" > "$STATE_DIR/url.txt"
  ok "tunnel awam: $(cat "$STATE_DIR/url.txt")"
}

stop_tunnel() {
  local p
  if p="$(bore_pid)"; then kill "$p" 2>/dev/null || true; sleep 1; kill -9 "$p" 2>/dev/null || true; fi
  rm -f "$STATE_DIR/bore.pid" "$STATE_DIR/url.txt"
  [ "${1:-}" = "quiet" ] || ok "tunnel dihentikan"
}

# --- 4. arahan ----------------------------------------------------------------
cmd_install() {
  need_root install
  echo; say "boz-node: menyediakan $(hostname) ($(uname -m))"
  mkdir -p "$STATE_DIR"; chmod 755 "$STATE_DIR"
  pkg_install openssh-server curl tar procps iproute2 || true
  install_key
  setup_sshd
  start_tunnel
  echo
  ok "selesai. Masuk dari PC:"
  echo
  echo "     $(cat "$STATE_DIR/url.txt")"
  echo
  say "port berubah setiap kali tunnel dimulakan semula (tanpa akaun)."
}

cmd_url() {
  [ -s "$STATE_DIR/url.txt" ] || die "belum ada tunnel — jalankan: sudo bash $0 install --key ..."
  cat "$STATE_DIR/url.txt"
}

cmd_status() {
  echo
  if listening; then ok "sshd: mendengar di port $SSH_PORT_TARGET"; else warn "sshd: tidak mendengar"; fi
  local sbin; sbin="$(sshd_bin || true)"
  if [ -n "$sbin" ] && "$sbin" -T 2>/dev/null | grep -qi '^passwordauthentication no'; then
    ok "login password: dimatikan"
  else warn "login password: masih aktif"; fi
  local u; u="$(real_user)"
  if [ -s "$(user_home "$u")/.ssh/authorized_keys" ]; then ok "kunci awam: terdaftar ($u)"; else warn "kunci awam: kosong"; fi
  if bore_pid >/dev/null; then
    local st age=0; st="$(cat "$STATE_DIR/started" 2>/dev/null || echo 0)"
    [ "$st" != "0" ] && age=$(( $(date +%s) - st ))
    ok "tunnel: hidup (${age}s) — $(cat "$STATE_DIR/url.txt" 2>/dev/null)"
  else
    warn "tunnel: mati — sudo bash $0 install"
  fi
  echo
}

case "${1:-install}" in
  install) shift || true
           while [ $# -gt 0 ]; do
             case "$1" in
               --key) KEY_SRC="${2:-}"; shift 2 ;;
               --port) REQ_PORT="${2:-0}"; shift 2 ;;
               --to) PUBLIC_HOST="${2:-bore.pub}"; shift 2 ;;
               *) die "argumen tidak dikenali: $1" ;;
             esac
           done
           cmd_install ;;
  url)    cmd_url ;;
  status) shift || true; cmd_status ;;
  stop)   need_root stop; stop_tunnel ;;
  restart) need_root restart; stop_tunnel quiet; start_tunnel ;;
  *) echo "penggunaan: sudo bash $0 {install [--key K|--port N|--to HOST]|url|status|stop|restart}"; exit 1 ;;
esac
