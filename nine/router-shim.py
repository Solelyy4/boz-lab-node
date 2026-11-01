#!/usr/bin/env python3
"""router-shim.py — jambatan SSE yang sah di antara Hermes dan 9router.

Masalah yang diselesaikan: Hermes meminta `stream: true`, dan 9router di nod
menghantar tool-call separuh (stream tamat sebelum argumen lengkap), sehingga
Hermes melaporkan "Stream stalled mid tool-call" dan alat tidak dijalankan.

Penyelesaian: shim menerima permintaan, memaksa `stream: false` ke 9router,
menerima SATU jawapan JSON yang lengkap, kemudian membungkusnya semula sebagai
SSE yang sah (delta role, content, tool_calls, finish_reason, [DONE]).
Hermes mendapat aliran yang sempurna; 9router tidak perlu diubah.

    python3 router-shim.py [--port 20129] [--upstream http://127.0.0.1:20128]
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = "http://127.0.0.1:20128"
PORT = 20129


def _sse(payload: dict) -> bytes:
    return b"data: " + json.dumps(payload, ensure_ascii=False).encode() + b"\n\n"


def to_sse(obj: dict) -> bytes:
    """Tukar satu jawapan chat.completions kepada aliran SSE yang sah."""
    out = bytearray()
    choice = (obj.get("choices") or [{}])[0]
    msg = choice.get("message") or {}
    base = {"id": obj.get("id", "shim"), "object": "chat.completion.chunk",
            "created": obj.get("created", 0), "model": obj.get("model", "")}

    def chunk(delta: dict, finish=None):
        return _sse({**base, "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]})

    out += chunk({"role": "assistant", "content": ""})

    text = msg.get("content") or ""
    if isinstance(text, list):                       # blok kandungan
        text = "".join(b.get("text", "") for b in text if isinstance(b, dict))
    for i in range(0, len(text), 400):
        out += chunk({"content": text[i:i + 400]})

    calls = msg.get("tool_calls") or []
    for idx, call in enumerate(calls):
        fn = call.get("function") or {}
        out += chunk({"tool_calls": [{"index": idx, "id": call.get("id") or f"call_{idx}",
                                      "type": "function",
                                      "function": {"name": fn.get("name", ""),
                                                   "arguments": fn.get("arguments") or "{}"}}]})

    out += chunk({}, "tool_calls" if calls else "stop")
    out += b"data: [DONE]\n\n"
    return bytes(out)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _send(self, code: int, body: bytes, ctype: str):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") in ("/health", "/v1/health"):
            return self._send(200, b'{"ok":true,"shim":"router-shim"}', "application/json")
        # Laluan baca (models, dsb.) disalurkan terus — tanpa ini /models keluar 404
        # dan bot/klien menyangka provider tiada model.
        if self.path.startswith("/v1/"):
            try:
                rq = urllib.request.Request(
                    UPSTREAM.rstrip("/") + self.path,
                    headers={"Authorization": self.headers.get("Authorization", "")})
                with urllib.request.urlopen(rq, timeout=60) as rs:
                    return self._send(200, rs.read(), "application/json")
            except urllib.error.HTTPError as exc:
                return self._send(exc.code, exc.read() or b"{}", "application/json")
            except Exception as exc:
                return self._send(502, json.dumps(
                    {"error": {"message": "shim:%s" % type(exc).__name__}}).encode(),
                    "application/json")
        return self._send(404, b'{"error":{"message":"tiada"}}', "application/json")

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return self._send(400, b'{"error":{"message":"JSON tidak sah"}}', "application/json")

        # Jejak ringkas: berapa alat Hermes hantar dan sama ada ia minta stream.
        # Tanpa ini, mustahil untuk tahu sama ada masalah di Hermes atau di router.
        try:
            import os as _os
            _p = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "shim-req.log")
            with open(_p, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"model": payload.get("model"),
                                     "tools": len(payload.get("tools") or []),
                                     "stream": bool(payload.get("stream")),
                                     "msgs": len(payload.get("messages") or [])}) + "\n")
        except OSError:
            pass

        wants_stream = bool(payload.get("stream"))

        # Chat biasa (tiada alat): alirkan SSE 9router terus kepada klien, baris
        # demi baris — inilah yang menjadikan jawapan "menaip" di Telegram.
        # Bila ada alat, tool_calls 9router tidak lengkap, jadi kita paksa
        # non-stream dan bungkus semula (lihat di bawah).
        if wants_stream and not (payload.get("tools") or []):
            payload["stream"] = True
            try:
                resp = urllib.request.urlopen(urllib.request.Request(
                    UPSTREAM.rstrip("/") + "/v1/chat/completions",
                    data=json.dumps(payload).encode(),
                    headers={"Authorization": self.headers.get("Authorization", ""),
                             "Content-Type": "application/json"}), timeout=600)
            except urllib.error.HTTPError as exc:
                return self._send(exc.code, exc.read() or b"{}", "application/json")
            except Exception:
                return self._send(502, b'{"error":{"message":"shim: aliran gagal"}}',
                                  "application/json")
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            try:
                for raw_line in resp:
                    if not raw_line:
                        continue
                    self.wfile.write(b"%x\r\n" % len(raw_line) + raw_line + b"\r\n")
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                try:
                    self.wfile.write(b"0\r\n\r\n")
                    self.wfile.flush()
                except Exception:
                    pass
                resp.close()
            return

        payload["stream"] = False
        # Bila ada alat: pastikan had token cukup untuk argumen JSON yang panjang
        # (sebelum ini argumen terpotong separuh dan alat gagal), dan benarkan
        # model memilih alat sendiri.
        if payload.get("tools"):
            payload.setdefault("tool_choice", "auto")
            try:
                if int(payload.get("max_tokens") or 0) < 1024:
                    payload["max_tokens"] = 2048
            except (TypeError, ValueError):
                payload["max_tokens"] = 2048

        def _hantar(pl):
            rq = urllib.request.Request(
                UPSTREAM.rstrip("/") + "/v1/chat/completions",
                data=json.dumps(pl).encode(),
                headers={"Authorization": self.headers.get("Authorization", ""),
                         "Content-Type": "application/json"})
            with urllib.request.urlopen(rq, timeout=600) as rs:
                return rs.read()

        def _kosong(o):
            msg = ((o.get("choices") or [{}])[0].get("message") or {})
            txt = msg.get("content") or ""
            if isinstance(txt, list):
                txt = "".join(b.get("text", "") for b in txt if isinstance(b, dict))
            return not (txt or "").strip() and not (msg.get("tool_calls") or [])

        attempts = 2 if payload.get("tools") else 1
        raw, obj = b"", None
        for cubaan in range(attempts):
            try:
                raw = _hantar(payload)
            except urllib.error.HTTPError as exc:
                return self._send(exc.code, exc.read() or b"{}", "application/json")
            except Exception as exc:
                return self._send(502, json.dumps({"error": {"message": f"shim:{type(exc).__name__}"}}).encode(),
                                  "application/json")
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                return self._send(502, b'{"error":{"message":"hulu bukan JSON"}}', "application/json")
            if not _kosong(obj):
                break
            # Jawapan kosong = model tersekat; ulang sekali dengan suhu 0.
            payload["temperature"] = 0

        obj = obj or {}

        # Peristiwa langkah: bot tail fail ini untuk tunjuk "sedang buat kerja".
        # Nama alat diambil dari jawapan sebenar, bukan tekaan.
        try:
            import os as _os, time as _t
            _msg = (obj.get("choices") or [{}])[0].get("message") or {}
            _calls = _msg.get("tool_calls") or []
            _names = [(c.get("function") or {}).get("name", "?") for c in _calls]
            _txt = _msg.get("content") or ""
            if isinstance(_txt, list):
                _txt = "".join(b.get("text", "") for b in _txt if isinstance(b, dict))
            _ev = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "shim-events.log")
            with open(_ev, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"ts": round(_t.time(), 2), "model": obj.get("model"),
                                     "tools": _names, "chars": len(_txt),
                                     "msgs": len(payload.get("messages") or [])}) + "\n")
        except (OSError, AttributeError, TypeError):
            pass

        if wants_stream:
            return self._send(200, to_sse(obj), "text/event-stream")
        return self._send(200, raw, "application/json")


def main() -> int:
    global UPSTREAM, PORT
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--upstream", default=UPSTREAM)
    a = ap.parse_args()
    PORT, UPSTREAM = a.port, a.upstream
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"router-shim: 127.0.0.1:{PORT} -> {UPSTREAM}", flush=True)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
