#!/usr/bin/env bash
# =============================================================================
#  state.sh — simpan & pulihkan ~/persist melalui branch `state` (disulitkan).
#
#  Nod GitHub Actions dibuang setiap kali tamat. Skrip ini yang buat kerja kau
#  kekal: tiap 2 minit ia bungkus ~/persist, sulitkan, dan push ke branch state.
#  Nod baru pula tarik balik masa mula.
#
#     PERSIST_PASS=... GH_TOKEN=... bash state.sh restore
#     PERSIST_PASS=... GH_TOKEN=... bash state.sh save
#     PERSIST_PASS=... GH_TOKEN=... bash state.sh watch
# =============================================================================
set -uo pipefail

SRC="${SRC:-$HOME/persist}"
PASS="${PERSIST_PASS:-}"
export PASS          # openssl -pass env:PASS membaca persekitaran proses
REPO_SLUG="${REPO_SLUG:-Solelyy4/boz-lab-node}"
BRANCH="${BRANCH:-state}"
WORK="${WORK:-/tmp/.state-work}"
INTERVAL="${INTERVAL:-120}"

die() { echo "state: $*" >&2; exit 1; }

save() {
  [ -n "$PASS" ] || die "PERSIST_PASS kosong"
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN kosong"
  mkdir -p "$SRC"
  rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK" || die "cd gagal"
  # Rahsia TIDAK masuk blob: .env, secrets/, log, pid. Ia datang dari GitHub
  # Actions secrets pada setiap boot, jadi ia tidak pernah tersimpan di repo.
  tar czf - -C "$SRC" \
    --exclude='./.env' --exclude='./secrets' --exclude='*.log' --exclude='*.pid' \
    --exclude='./hvenv' --exclude='./bin' . \
    | openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:PASS -out state.tar.enc \
    || die "sulitkan gagal"
  git init -q
  git config user.email node@local; git config user.name node
  git add state.tar.enc
  git commit -qm "state $(date -u '+%FT%TZ')" --allow-empty
  git push -q --force "https://x-access-token:${GH_TOKEN}@github.com/${REPO_SLUG}.git" \
    HEAD:refs/heads/"$BRANCH" || die "push gagal"
  # Penanda kejayaan: tanpa ini kegagalan push senyap (blob terlalu besar) tidak
  # kelihatan langsung, dan kerja selepasnya hilang bila nod berganti.
  date -u +%s > /tmp/.state-last-ok
  echo "disimpan: $(find "$SRC" -type f | wc -l) fail, $(stat -c %s state.tar.enc 2>/dev/null || echo '?') bait"
}

restore() {
  [ -n "$PASS" ] || die "PERSIST_PASS kosong"
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN kosong"
  mkdir -p "$SRC"
  rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK" || die "cd gagal"
  git init -q
  git config user.email node@local; git config user.name node
  git remote add origin "https://x-access-token:${GH_TOKEN}@github.com/${REPO_SLUG}.git"
  if ! git fetch -q --depth 1 origin "$BRANCH" 2>/dev/null; then
    echo "tiada simpanan lagi (branch $BRANCH kosong) — mula bersih"
    return 0
  fi
  git checkout -q FETCH_HEAD -- state.tar.enc 2>/dev/null || { echo "tiada state.tar.enc"; return 0; }
  openssl enc -d -aes-256-cbc -pbkdf2 -in state.tar.enc -out state.tar -pass env:PASS \
    || die "nyahsulit gagal (passphrase salah?)"
  tar xzf state.tar -C "$SRC" || die "ekstrak gagal"
  echo "dipulihkan: $(find "$SRC" -type f | wc -l) fail"
}

watch() {
  while :; do
    sleep "$INTERVAL"
    save >> /tmp/state-sync.log 2>&1 || true
  done
}

case "${1:-}" in
  save)    save ;;
  restore) restore ;;
  watch)   watch ;;
  *) echo "penggunaan: bash state.sh {restore|save|watch}"; exit 1 ;;
esac
