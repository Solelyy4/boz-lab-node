---
name: tool-discipline
description: "Use every session: tool habits that prevent false failures."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [tools, windows, paths, verification, agentic]
    auto_load: true
---

# TOOL DISCIPLINE — disiplin tool yang wajib dalam setiap sesi

## When to Use

Setiap sesi, tanpa perlu dipanggil: sebelum menulis fail, menjalankan arahan shell,
melaporkan "berjaya", atau menolak kerja kerana "tiada tool".

Di-auto-load supaya model apa pun (termasuk model kecil) tidak gagal kerja hanya kerana
kesilapan tool yang boleh dielak.

## 1. Windows: path dalam tool call

- Guna **forward slash**: `C:/Users/zahin/Downloads/fail.py`. Jangan hantar `C:\\Users\\...`
  ke shell — bash memakan backslash dan path jadi `C:UserszahinDownloads...`.
- Dalam tool call JSON, **jangan escape backslash** — tulis path sekali sahaja, dengan `/`.
- Quote path yang ada ruang: `python "C:/Users/zahin/Downloads/f.py"`.
- Kalau path gagal: cuba sekali lagi dengan forward slash + quote, baru lapor gagal — dan
  sebut path tepat yang dicuba.

## 2. Jangan tulis placeholder ke dalam fail

`<nombor>`, `TODO`, `[X]`, `...` dalam fail hasil = kerja belum siap. Kira dulu dengan tool,
kemudian tulis **nilai sebenar**. Kalau tak dapat diperoleh, tulis `TIDAK ADA` + sebabnya.

## 3. Sahkan sebelum lapor

Selepas `write_file`: **wajib** `read_file` semula dan bandingkan aksara demi aksara dengan
nilai yang diminta. Tak sepadan → tulis semula sebelum balas. Melapor "berjaya ditulis" tanpa
baca balik = klaim palsu (kes sebenar: nilai 128 ditulis sebagai 100).

## 3b. NIlai tidak boleh melintasi giliran dari ingatan

Nombor/hash/hasil tool **jangan ditaip semula dari ingatan** pada langkah berikut. Dua cara sah:

1. Salin verbatim dari output tool **pada giliran yang sama** (bukan dari mesej lama).
2. Lebih selamat: **gabungkan dalam satu arahan** — satu skrip/`python -c` yang kira DAN tulis
   fail sekaligus, supaya nilai tidak menyeberang sempadan giliran.

Sebab: model kecil betul semasa satu langkah, tetapi mengubah nombor bila berantai
(128 → 100, 123, 1234 dalam ujian sebenar).

## 4. Aritmetik, tarikh, hash, saiz fail → tool

Jangan kira dalam kepala. `python -c "print(...)"`, `date`, `sha256sum`, `wc -c`.
Model kecil kerap salah tambah; tool tidak.

## 5. Kerja berbilang langkah

Siapkan **semua** langkah sebelum membalas; jangan berhenti separuh dan laporkan langkah 1
sebagai keputusan akhir. Setiap langkah mesti ada bukti (output tool).

## 6. Skill

Kalau ada skill yang padan, panggil `skill_view` **dahulu**, ikut langkahnya, baru kerja.
Jangan kata "tiada skill/tool" sebelum semak senarai.

## 7. Kegagalan

Satu kegagalan tool = diagnosis + langkah alternatif dalam balasan yang sama. Bukan
penolakan, bukan berhenti.

## 8. Hook untuk `write_file`

Sekat penulisan fail yang masih mengandungi placeholder (`<nombor>`, `TODO`, `[X]`, `<isi>`),
supaya model terpaksa mengira/mengambil nilai sebenar dahulu. Model kecil kerap tulis
`BARIS=<nombor>` dan lapor "siap"; blok ini memaksa satu pusingan pembetulan.

Protokol: stdin JSON hook_event -> stdout {"action":"block","message":...} atau tiada output.

```python
import json
import re
import sys

PLACEHOLDER = re.compile(
    r"<\s*(nombor|angka|nilai|n|isi|bilangan|x)\s*>|\[X\]|<TODO>|\bTODO:|\bFIXME\b|\.\.\.\s*$",
    re.IGNORECASE | re.MULTILINE,
)
MESSAGE = ("Placeholder dikesan dalam kandungan fail (<nombor>/TODO/[X]/...). "
           "Kira atau baca nilai sebenar dengan tool (terminal / read_file), kemudian "
           "tulis semula fail dengan nilai itu — tiada placeholder.")

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if (data.get("tool_name") or "") != "write_file":
        return 0
    ti = data.get("tool_input")
    if not isinstance(ti, dict):
        return 0
    content = ti.get("content")
    if not isinstance(content, str) or not content:
        return 0
    m = PLACEHOLDER.search(content)
    if not m:
        return 0
    json.dump({"action": "block", "message": f"{MESSAGE} (ditemui: {m.group(0)!r})"}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## 9. Hook untuk `terminal`

Normalisasi path Windows dalam `terminal`.

Masalah sebenar: model menghantar `C:\\Users\\zahin\\...` dalam JSON tool call, bash MSYS
memakan backslash, arahan jadi `C:UserszahinDownloads...` → `No such file`. Hook ini tukar
drive-path kepada forward slash sebelum arahan dijalankan, tanpa menyentuh escape lain
(`\\n`, regex, dsb) kerana hanya token yang bermula dengan huruf drive disentuh.

Protokol: stdin JSON {"hook_event_name","tool_name","tool_input",...}
           stdout JSON {"action":"modify","args":{...}} bila diubah.
Exit 0 tanpa output = biar lalu seperti asal.

```python
import json
import re
import sys

# C:\... | C:\\... | C:/... diikuti aksara bukan-ruang
DRIVE_PATH = re.compile(r'(?<![\w/])([A-Za-z]):((?:\\{1,4}|/)+)([^\s"\'`;|&<>)]*)

def _fix_token(m):
    drive, sep, rest = m.group(1), m.group(2), m.group(3)
    rest = rest.replace("\\\\", "/").replace("\\", "/")
    return f"{drive}:/{rest}"

def fix_command(cmd: str) -> str:
    if "\\" not in cmd:
        return cmd
    return DRIVE_PATH.sub(_fix_token, cmd)

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if (data.get("tool_name") or "") != "terminal":
        return 0
    ti = data.get("tool_input")
    if not isinstance(ti, dict):
        return 0
    cmd = ti.get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        return 0
    new = fix_command(cmd)
    if new == cmd:
        return 0
    out = dict(ti)
    out["command"] = new
    json.dump({"action": "modify", "args": out}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## 10. Konfigurasi hook

Tambahkan dua hook ini ke `config.yaml`:

```yaml
hooks_auto_accept: true
hooks:
  pre_tool_call:
    - matcher: terminal
      command: python "C:/Users/zahin/AppData/Local/hermes/scripts/path_fix_hook.py"
      timeout: 15
    - matcher: write_file
      command: python "C:/Users/zahin/AppData/Local/hermes/scripts/placeholder_guard.py"
      timeout: 15
```

## 11. Ujian hook

Uji hook dengan arahan berikut:

```bash
cd /c/Users/zahin/AppData/Local/hermes && echo '{"hook_event_name":"pre_tool_call","tool_name":"terminal","tool_input":{"command":"python C:\\\\Users\\\\zahin\\\\Downloads\\\\parity\\\\fact.py"}}' | python scripts/path_fix_hook.py; echo; echo '{"hook_event_name":"pre_tool_call","tool_name":"terminal","tool_input":{"command":"printf \"a\\nb\" > /tmp/x && echo done"}}' | python scripts/path_fix_hook.py; echo "(kosong = tiada perubahan, betul)"; echo '{"hook_event_name":"pre_tool_call","tool_name":"read_file","tool_input":{"path":"C:\\\\Users\\\\x"}}' | python scripts/path_fix_hook.py; echo "(kosong = tool lain tak disentuh)"
```

```bash
cd /c/Users/zahin/AppData/Local/hermes && echo '{"tool_name":"write_file","tool_input":{"content":"BARIS=<nombor>"}}' | python scripts/placeholder_guard.py; echo; echo '{"tool_name":"write_file","tool_input":{"content":"BARIS=128"}}' | python scripts/placeholder_guard.py; echo "(kosong = lolos)"; echo '{"tool_name":"write_file","tool_input":{"content":"# TODO: tambah fungsi"}}' | python scripts/placeholder_guard.py
```

## 12. Ujian konfigurasi hook

Uji konfigurasi hook dengan arahan berikut:

```bash
cd /c/Users/zahin && hermes config set hooks_auto_accept true 2>&1 | tail -1; hermes config set hooks '{"pre_tool_call":[{"matcher":"terminal","command":"python \"C:/Users/zahin/AppData/Local/hermes/scripts/path_fix_hook.py\"","timeout":15},{"matcher":"write_file","command":"python \"C:/Users/zahin/AppData/Local/hermes/scripts/placeholder_guard.py\"","timeout":15}]}' 2>&1 | tail -2; echo "=== sahkan ==="; hermes config get hooks 2>&1 | head -10; echo "=== hooks list ==="; hermes hooks list 2>&1 | head -12
```

## 13. Ujian keseluruhan

Uji keseluruhan dengan arahan berikut:

```bash
cd /c/Users/zahin && timeout 240 hermes -z 'Jalankan arahan terminal PERSIS ini dan laporkan output sebenar: python C:\Users\zahin\Downloads\parity\fact4_codestral.py' --provider 9router -m mistral/codestral-latest 2>&1 | tail -6
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -like '*parity4*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }" >/dev/null 2>&1; sleep 2; rm -f parity4_results.json; echo "dibersihkan"; powershell.exe -NoProfile -Command "(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -like '*parity4*' } | Measure-Object).Count" 2>&1 | tail -1
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ./.venv/Scripts/python.exe -u parity4.py > parity4_run.log 2>&1
```

```bash
sleep 300; cd /c/Users/zahin/Downloads/Mistral-farm && tail -8 parity4_run.log; ls -la /c/Users/zahin/Downloads/parity/fact4_*.py 2>/dev/null
```

```bash
sleep 360; cd /c/Users/zahin/Downloads/Mistral-farm && tail -14 parity4_run.log
```

```bash
cd /c/Users/zahin/Downloads/parity && echo "=== codestral chat_hard ==="; cat raw/codestral_hard4.txt; echo; echo "=== ministral chat_hard ==="; cat raw/ministral_hard4.txt; echo; echo "=== ministral heavy_single file ==="; cat h4s_ministral.txt 2>/dev/null; echo; echo "=== codestral heavy_single file ==="; cat h4s_codestral.txt 2>/dev/null
```

```bash
sleep 330; cd /c/Users/zahin/Downloads/Mistral-farm && tail -5 parity4_run.log; echo "=== rekod ==="; wc -l parity4_results.json
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ./.venv/Scripts/python.exe -u parity5.py large4 2>&1 | tail -3
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ls -la parity6_run.log parity6_results.json 2>/dev/null; powershell.exe -NoProfile -Command "(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -like '*parity6*' } | Measure-Object).Count" 2>&1 | tail -1
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ./.venv/Scripts/python.exe -u report.py 2>&1 | tail -10
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ./.venv/Scripts/python.exe - <<'PY'
import json, time
notes = [
 {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "model": "mistral/ministral-8b-latest",
  "test": "heavy_single", "verdict": "PARTIAL",
  "detail": "fail='128 BOZ-README.md' - nombor BETUL (128), format BARIS= terlepas", "secs": 18.9},
]
with open("parity_notes.json", "a", encoding="utf-8") as fh:
    for n in notes:
        fh.write(json.dumps(n, ensure_ascii=False) + "\n")
print("nota ditulis")
PY
tail -3 parity6_run.log 2>/dev/null
```

```bash
sleep 300; cd /c/Users/zahin/Downloads/Mistral-farm && cat parity6_run.log 2>/dev/null; echo "=== raw monyet ==="; tail -4 parity/raw/codestral_chain6.txt 2>/dev/null
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ls -la parity6_run.log parity6_results.json 2>/dev/null; powershell.exe -NoProfile -Command "(Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -like '*parity6*' } | Measure-Object).Count" 2>&1 | tail -1
```

```bash
cd /c/Users/zahin/Downloads/Mistral-farm && ./.venv/Scripts/python.exe -u report.py 2>&1 | tail -10
```


`<nombor>`, `TODO`, `[X]`, `...` dalam fail hasil = kerja belum siap. Kira dulu dengan tool,
kemudian tulis **nilai sebenar**. Kalau tak dapat diperoleh, tulis `TIDAK ADA` + sebabnya.
