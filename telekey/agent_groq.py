"""Runtime agen ringan: model percuma (Groq) + alat tempatan, tanpa spawn Hermes.

Kenapa: `hermes -z --provider groq` menolak prompt sistem sebagai "terlalu besar"
(batas konteks dalaman Hermes), sedangkan API Groq sendiri menerima 131k. Laluan ini
memanggil API terus dan menjalankan alat di dalam proses bot:
  - kelajuan: 2-6s bagi tugasan 2-3 langkah (spawn Hermes ~20s)
  - percuma: gpt-oss-120b pada Groq free tier
  - keselamatan: tulisan fail dihadkan pada akar yang dibenarkan, terminal ada timeout
"""
import json
import os
import re
import subprocess
import time
from pathlib import Path

import requests

HOME = Path(os.environ.get("HERMES_HOME") or "C:/Users/zahin/AppData/Local/hermes")
AKAR_BENAR = [Path("C:/Users/zahin"), HOME, Path.home(), Path(os.environ.get("HOME") or ".")]
# cwd mesti wujud pada mesin ini: Windows pada PC, /home/runner pada nod.
CWD_ALAT = next((p for p in (Path("C:/Users/zahin"), Path.home(), Path.cwd()) if p.is_dir()), Path.cwd())
MAKS_LANGKAH = 8
ALAT = [
    {"type": "function", "function": {
        "name": "terminal",
        "description": "Jalankan arahan shell (bash/MSYS pada Windows) dan pulang stdout+stderr.",
        "parameters": {"type": "object", "properties": {
            "cmd": {"type": "string", "description": "Arahan shell"}}, "required": ["cmd"]}}},
    {"type": "function", "function": {
        "name": "read_file",
        "description": "Baca fail teks. Pulang kandungan (maks 8000 aksara).",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "write_file",
        "description": "Tulis kandungan ke fail (cipta folder jika perlu).",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"},
            "content": {"type": "string"}}, "required": ["path", "content"]}}},
    {"type": "function", "function": {
        "name": "list_dir",
        "description": "Senaraikan isi folder.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "web_get",
        "description": "Ambil kandungan URL (http/https) dan pulang teks (maks 8000 aksara).",
        "parameters": {"type": "object", "properties": {
            "url": {"type": "string"}}, "required": ["url"]}}},
]


def _kunci_groq():
    if os.environ.get("GROQ_API_KEY"):
        return os.environ["GROQ_API_KEY"].strip()
    env = HOME / ".env"
    if env.is_file():
        for baris in env.read_text(encoding="utf-8", errors="replace").splitlines():
            if baris.startswith("GROQ_API_KEY="):
                return baris.split("=", 1)[1].strip()
    return ""


def _dibenarkan(p):
    try:
        t = Path(p).resolve()
    except (OSError, ValueError):
        return None
    for akar in AKAR_BENAR:
        try:
            t.relative_to(akar.resolve())
            return t
        except ValueError:
            continue
    return None


def _jalankan(nama, args):
    """Laksanakan satu panggilan alat. Pulang teks hasil (untuk dihantar balik ke model)."""
    try:
        if nama == "terminal":
            cmd = str(args.get("cmd") or "")
            if not cmd.strip():
                return "RALAT: arahan kosong"
            p = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True,
                               timeout=180, cwd=str(CWD_ALAT))
            keluar = (p.stdout or "") + (("\n[stderr] " + p.stderr) if p.stderr else "")
            return (keluar.strip() or "(tiada output)")[:8000] + "\n[exit %d]" % p.returncode
        if nama == "read_file":
            t = _dibenarkan(args.get("path") or "")
            if not t:
                return "RALAT: laluan di luar kawasan dibenarkan"
            if not t.is_file():
                return "RALAT: fail tiada (%s)" % t
            return t.read_text(encoding="utf-8", errors="replace")[:8000]
        if nama == "write_file":
            t = _dibenarkan(args.get("path") or "")
            if not t:
                return "RALAT: laluan di luar kawasan dibenarkan"
            t.parent.mkdir(parents=True, exist_ok=True)
            t.write_text(str(args.get("content") or ""), encoding="utf-8")
            return "OK ditulis %s (%d bait)" % (t, t.stat().st_size)
        if nama == "list_dir":
            t = _dibenarkan(args.get("path") or "")
            if not t or not t.is_dir():
                return "RALAT: folder tiada"
            nama_nama = sorted(x.name + ("/" if x.is_dir() else "") for x in t.iterdir())[:200]
            return "\n".join(nama_nama) or "(kosong)"
        if nama == "web_get":
            url = str(args.get("url") or "")
            if not re.match(r"^https?://", url):
                return "RALAT: URL mesti http/https"
            r = requests.get(url, timeout=45, headers={"User-Agent": "Mozilla/5.0 TeleKey"})
            teks = re.sub(r"<script.*?</script>|<style.*?</style>", " ", r.text, flags=re.S | re.I)
            teks = re.sub(r"<[^>]+>", " ", teks)
            return re.sub(r"\s+", " ", teks).strip()[:8000]
    except subprocess.TimeoutExpired:
        return "RALAT: arahan lebih 180s"
    except Exception as e:
        return "RALAT %s: %s" % (type(e).__name__, str(e)[:200])
    return "RALAT: alat tidak dikenali"


def agent_groq(prompt, model="openai/gpt-oss-120b", timeout=300, on_event=None, suhu=0.1):
    """Jalankan tugasan dengan gelung alat. Pulang (teks, ralat, nota)."""
    kunci = _kunci_groq()
    if not kunci:
        return None, "GROQ_API_KEY tiada", ""
    mula = time.time()
    msgs = [{"role": "system", "content": prompt.split("\n\nTUGAS:")[0]},
            {"role": "user", "content": prompt}]
    langkah = []
    jumlah_alat = 0
    maks_tok = 2048
    for i in range(MAKS_LANGKAH):
        if time.time() - mula > timeout:
            return None, "agen groq lebih %ds" % timeout, ""
        ralat = ""
        for cubaan in range(4):
            try:
                r = requests.post("https://api.groq.com/openai/v1/chat/completions",
                                  headers={"Authorization": "Bearer " + kunci,
                                           "Content-Type": "application/json"},
                                  json={"model": model, "messages": msgs, "tools": ALAT,
                                        "tool_choice": "auto", "temperature": suhu,
                                        "max_tokens": maks_tok, "parallel_tool_calls": True},
                                  timeout=90)
            except Exception as e:
                return None, "groq %s: %s" % (type(e).__name__, str(e)[:120]), ""
            if r.status_code == 200:
                break
            ralat = "HTTP %d %s" % (r.status_code, r.text[:140])
            # Groq menolak permintaan yang "too large" bagi tier organisasi —
            # kecilkan had output dan cuba lagi sebelum menyerah.
            if r.status_code in (413, 429) and maks_tok > 512:
                maks_tok //= 2
                continue
            return None, "groq " + ralat, ""
        else:
            return None, "groq " + ralat, ""
        m = r.json()["choices"][0]["message"]
        panggilan = m.get("tool_calls") or []
        isi = m.get("content") or ""
        if isinstance(isi, list):
            isi = "".join(b.get("text", "") for b in isi if isinstance(b, dict))
        if not panggilan:
            langs = [{"tools": [], "chars": len(isi)}]
            langkah.append(langs)
            if on_event:
                on_event(langkah)
            return isi.strip() or None, None, "model=%s alat=%d %.1fs" % (
                model, jumlah_alat, time.time() - mula)
        msgs.append({"role": "assistant", "content": isi or None, "tool_calls": panggilan})
        nama_alat = []
        for c in panggilan:
            fn = c.get("function") or {}
            nama = fn.get("name", "?")
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError:
                args = {}
            hasil = _jalankan(nama, args)
            nama_alat.append(nama)
            jumlah_alat += 1
            msgs.append({"role": "tool", "tool_call_id": c.get("id") or nama,
                         "content": hasil[:6000]})
        langkah.append([{"tools": nama_alat, "chars": len(isi)}])
        if on_event:
            on_event(langkah)
    return None, "agen groq habis %d langkah tanpa jawapan akhir" % MAKS_LANGKAH, ""
