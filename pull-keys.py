#!/usr/bin/env python3
"""pull-keys.py — gabung keys.db dari nod ke DB PC.

Masalah yang diselesaikan: bot di nod dan bot di PC masing-masing pegang salinan
keys.db. Kunci API yang dicipta melalui Telegram semasa laptop mati hanya ada di
nod, lalu hilang bila laptop hidup semula dan PC ambil alih.

Penyelesaian: semasa nod masih hidup (ia hidup sampai ~6 jam walaupun PC sudah
kembali poll), cron PC menarik keys.db nod melalui SSH dan menggabung barisnya.
Tiada passphrase diperlukan — pengesahan guna kunci SSH sedia ada.

    python pull-keys.py            # tarik + gabung (senyap kalau tiada perubahan)
    python pull-keys.py --verbose  # cetak butiran
"""
from __future__ import annotations

import os
import pathlib
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time

LOCAL = pathlib.Path(os.environ.get("TELEKEY_DB") or
                     r"C:/Users/zahin/projects/telekey-bot/keys.db")
KIT = pathlib.Path(os.environ.get("TUNNEL_KIT") or
                   r"C:/Users/zahin/Downloads/tunnel-kit")
KEY = pathlib.Path(os.environ.get("SSH_KEY") or KIT / "keys" / "boz_lab")
REPO = os.environ.get("REPO_SLUG", "Solelyy4/boz-lab-node")
HOST = os.environ.get("NODE_HOST", "runner@bore.pub")
STAMP = pathlib.Path(os.environ.get("PULL_STAMP") or pathlib.Path.home() / ".boz-node" / "last_pull")
VERBOSE = "--verbose" in sys.argv

# Jadual dengan kunci utama komposit: tambah nilai, bukan ganti.
COUNTERS = {
    "usage_log": ("key, day", ["key", "day", "n", "tokens"]),
    "chat_usage": ("chat_id, day", ["chat_id", "day", "n", "tokens"]),
    "agent_usage": ("chat_id, day", ["chat_id", "day", "n"]),
}


def say(msg: str) -> None:
    if VERBOSE:
        print(msg)


def gh_bin() -> str | None:
    for cand in ("gh", str(pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "bin" / "gh.exe")):
        if cand and shutil.which(cand):
            return cand
    return None


def node_port() -> str | None:
    gh = gh_bin()
    if not gh:
        return None
    try:
        out = subprocess.run(
            [gh, "issue", "list", "--repo", REPO, "--search", "node-status in:title",
             "--json", "body", "--jq", ".[0].body"],
            capture_output=True, text=True, timeout=45).stdout
    except Exception:
        return None
    for line in out.splitlines():
        if line.startswith("PORT="):
            return line.split("=", 1)[1].strip()
    return None


def fetch(port: str, dest: pathlib.Path) -> bool:
    cmd = ["scp", "-P", port, "-i", str(KEY),
           "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
           "-o", "LogLevel=ERROR", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15",
           f"{HOST}:persist/telekey/keys.db", str(dest)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    except Exception as exc:
        say(f"scp gagal: {exc}")
        return False
    if r.returncode != 0:
        say(f"scp rc={r.returncode}: {(r.stderr or '').strip()[:200]}")
        return False
    return dest.exists() and dest.stat().st_size > 0


def merge(remote: pathlib.Path) -> dict:
    """Gabung baris remote ke DB tempatan. Pulang kiraan perubahan."""
    changes = {}
    con = sqlite3.connect(LOCAL, timeout=15)
    con.execute("PRAGMA busy_timeout=5000")
    con.execute("ATTACH DATABASE ? AS r", (str(remote),))

    # 1. Kunci API: kunci = PRIMARY KEY, jadi INSERT OR IGNORE sudah betul.
    before = con.execute("SELECT COUNT(*) FROM main.api_keys").fetchone()[0]
    con.execute("INSERT OR IGNORE INTO main.api_keys SELECT * FROM r.api_keys")
    changes["api_keys"] = con.execute("SELECT COUNT(*) FROM main.api_keys").fetchone()[0] - before

    # 2. Pembilang: MAX, bukan TAMBAH.
    #    Kedua-dua DB bermula daripada snapshot yang sama, dan gerbang penunggu
    #    menjamin hanya SATU bot aktif pada satu masa. Jadi nilai yang lebih
    #    besar sentiasa yang betul, dan merge kekal idempotent — cron 10-minit
    #    boleh berjalan berulang tanpa menggelembungkan kiraan.
    for table, (pk, cols) in COUNTERS.items():
        try:
            pkcols = [x.strip() for x in pk.split(",")]
            numcols = [c for c in cols if c not in pkcols]
            join_m = " AND ".join(f"ru.{x} = m.{x}" for x in pkcols)
            join_i = " AND ".join(f"m.{x} = ru.{x}" for x in pkcols)
            n_before = con.execute(f"SELECT COALESCE(SUM(n),0) FROM main.{table}").fetchone()[0]
            if numcols:
                sets = ", ".join(
                    f"{c} = MAX(m.{c}, (SELECT ru.{c} FROM r.{table} ru WHERE {join_m}))"
                    for c in numcols)
                con.execute(f"UPDATE main.{table} AS m SET {sets} "
                            f"WHERE EXISTS (SELECT 1 FROM r.{table} ru WHERE {join_m})")
            con.execute(
                f"INSERT INTO main.{table} ({', '.join(cols)}) "
                f"SELECT {', '.join('ru.' + c for c in cols)} FROM r.{table} ru "
                f"WHERE NOT EXISTS (SELECT 1 FROM main.{table} m WHERE {join_i})")
            n_after = con.execute(f"SELECT COALESCE(SUM(n),0) FROM main.{table}").fetchone()[0]
            changes[table] = n_after - n_before
        except sqlite3.Error as exc:
            changes[table] = f"ralat: {exc}"

    # 3. Sejarah chat: id autoincrement, jadi kunci semula jadi = (chat_id, role, ts, content).
    try:
        before = con.execute("SELECT COUNT(*) FROM main.chat_log").fetchone()[0]
        con.execute("""INSERT INTO main.chat_log (chat_id, role, content, ts)
                       SELECT chat_id, role, content, ts FROM r.chat_log
                       WHERE NOT EXISTS (SELECT 1 FROM main.chat_log m
                                         WHERE m.chat_id = r.chat_log.chat_id
                                           AND m.ts = r.chat_log.ts
                                           AND m.role = r.chat_log.role)""")
        changes["chat_log"] = con.execute("SELECT COUNT(*) FROM main.chat_log").fetchone()[0] - before
    except sqlite3.Error as exc:
        changes["chat_log"] = f"ralat: {exc}"

    con.commit()
    con.execute("DETACH DATABASE r")
    con.close()
    return changes


def main() -> int:
    if not LOCAL.exists():
        print(f"DB tempatan tiada: {LOCAL}", file=sys.stderr)
        return 1
    port = node_port()
    if not port:
        say("port nod tidak diketahui — langkau")
        return 0
    STAMP.parent.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="pullkeys-")) / "node.db"
    try:
        if not fetch(port, tmp):
            return 0                      # nod mungkin sudah mati — bukan ralat
        # Jangan gabung kalau fail bukan SQLite yang sah.
        head = tmp.read_bytes()[:16]
        if not head.startswith(b"SQLite format 3"):
            say("fail bukan SQLite — langkau")
            return 0
        changes = merge(tmp)
        total = sum(v for v in changes.values() if isinstance(v, int))
        STAMP.write_text(str(int(time.time())))
        real = {k: v for k, v in changes.items() if v}
        if real:
            print(f"gabung dari nod {port}: {real}")
        else:
            say(f"tiada perubahan ({changes})")
        return 0
    finally:
        shutil.rmtree(tmp.parent, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
