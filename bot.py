#!/usr/bin/env python3
"""Bot Telegram NEXORA — tanpa pakej luar (stdlib sahaja).

Sengaja tidak guna pustaka pihak ketiga: mesin GitHub Actions dibuang setiap
~6 jam, dan setiap `pip install` adalah satu lagi benda yang boleh gagal.
Stdlib sentiasa ada.

Token dibaca dari ~/persist/.env  (TG_TOKEN=...). Fail itu disulitkan semasa
disegerakkan, jadi ia tidak terdedah di GitHub.

Jalankan:  python3 bot.py            (polling berterusan)
Uji:       python3 bot.py --self-test
"""
import json
import os
import platform
import shutil
import sys
import time
import urllib.error
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(BASE, "bot.log")
API = "https://api.telegram.org/bot{token}/{method}"


def load_env():
    p = os.path.join(BASE, ".env")
    if not os.path.exists(p):
        return
    with open(p, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def log(msg):
    """Tulis ke stdout sahaja — pemanggil mengalihkan ke bot.log.
    (Menulis ke fail sekali lagi akan menyebabkan setiap baris berganda.)"""
    print("[%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()), msg), flush=True)


def call(method, token, _http=70, **params):
    """Panggil API Telegram. _http = had masa rangkaian; timeout diteruskan ke API."""
    url = API.format(token=token, method=method)
    data = json.dumps(params).encode() if params else None
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=_http) as resp:
        return json.loads(resp.read().decode())


def human(seconds):
    seconds = int(seconds)
    d, r = divmod(seconds, 86400)
    h, r = divmod(r, 3600)
    m, s = divmod(r, 60)
    parts = []
    if d:
        parts.append("%dh" % d)
    if d or h:
        parts.append("%dj" % h)
    parts.append("%dm" % m)
    return " ".join(parts)


def cmd_status():
    up = "?"
    try:
        with open("/proc/uptime") as fh:
            up = human(float(fh.read().split()[0]))
    except OSError:
        pass
    mem = "?"
    try:
        info = {}
        with open("/proc/meminfo") as fh:
            for line in fh:
                k, v = line.split(":", 1)
                info[k] = int(v.split()[0])
        mem = "%.1f / %.1f GB" % (info["MemTotal"] / 1048576,
                                  info["MemAvailable"] / 1048576)
    except (OSError, KeyError, ValueError):
        pass
    disk = "?"
    try:
        du = shutil.disk_usage("/")
        disk = "%.0f / %.0f GB" % (du.free / 1073741824, du.total / 1073741824)
    except OSError:
        pass
    started = "?"
    try:
        with open(os.path.join(BASE, "start-result.txt"), encoding="utf-8") as fh:
            started = fh.read().strip().split(" di ")[0]
    except (OSError, IndexError):
        pass
    return (
        "*NEXORA — status nod*\n"
        "hos: `%s`\n"
        "hidup: %s\n"
        "cpu: %s teras\n"
        "ram: %s (bebas/penuh)\n"
        "disk: %s (bebas/penuh)\n"
        "nod mula: %s\n"
    ) % (platform.node(), up, os.cpu_count(), mem, disk, started)


HELP = (
    "*NEXORA AI* — bot pada nod GitHub\n\n"
    "/status — keadaan mesin\n"
    "/ping — uji hidup\n"
    "/id — id chat kau\n"
    "/help — senarai ini\n\n"
    "Fail kau kekal dalam `~/persist` walaupun mesin berganti."
)


def handle(token, msg):
    chat_id = msg.get("chat", {}).get("id")
    text = (msg.get("text") or "").strip()
    if not chat_id:
        return
    cmd = text.split()[0].lower().split("@")[0] if text else ""
    if cmd in ("/start", "/help"):
        reply = HELP
    elif cmd == "/ping":
        reply = "pong — %s" % time.strftime("%H:%M:%S UTC", time.gmtime())
    elif cmd == "/status":
        reply = cmd_status()
    elif cmd == "/id":
        reply = "chat id: `%s`" % chat_id
    elif text:
        reply = "Terima. Hantar /help untuk senarai arahan."
    else:
        return
    call("sendMessage", token, chat_id=chat_id, text=reply, parse_mode="Markdown")


def self_test(token):
    me = call("getMe", token, _http=20)
    log("getMe: ok=%s username=%s" % (me.get("ok"), me.get("result", {}).get("username")))
    log("status:\n" + cmd_status())
    return 0 if me.get("ok") else 1


def main():
    load_env()
    token = os.environ.get("TG_TOKEN", "").strip()
    if not token:
        log("TG_TOKEN tiada — letak dalam %s/.env" % BASE)
        return 2
    if "--self-test" in sys.argv:
        return self_test(token)

    log("polling bermula (pid %d)" % os.getpid())
    offset = 0
    backoff = 3
    while True:
        try:
            # timeout=50 dihantar ke API: sambungan digantung sampai ada mesej.
            # Tanpa ini bot akan hammer Telegram ~1 permintaan sesaat.
            resp = call("getUpdates", token, _http=70, offset=offset, timeout=50,
                        allowed_updates=["message", "edited_message"])
            for upd in resp.get("result", []):
                offset = max(offset, upd["update_id"] + 1)
                msg = upd.get("message") or upd.get("edited_message")
                if msg:
                    try:
                        handle(token, msg)
                    except Exception as exc:            # satu mesej rosak tak bunuh bot
                        log("ralat mengendali mesej: %r" % exc)
            backoff = 3
        except urllib.error.HTTPError as exc:
            body = ""
            try:
                body = exc.read().decode()[:200]
            except Exception:
                pass
            if exc.code == 409:
                # ada instance lain sedang poll — tunggu ia mati
                log("409 conflict — tunggu instance lain mati")
                time.sleep(30)
                continue
            log("HTTP %s: %s" % (exc.code, body))
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)
        except Exception as exc:
            log("ralat rangkaian: %r — cuba lagi dalam %ds" % (exc, backoff))
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)


if __name__ == "__main__":
    sys.exit(main())
