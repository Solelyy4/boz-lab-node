---
name: windows-bash-ops
description: "Use when Windows shell work breaks: paths, venv, pipes."
version: 1.1.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [windows, msys, git-bash, paths, python, venv, uv, ffmpeg]
    related_skills: [hermes-agent]
---

# Windows / MSYS Bash Ops

## When to Use

A command fails for a reason that looks unrelated to the command: file not found for a file that
exists, a pip install that cannot find pip, a hanging process, a prompt that never returns, or a
path that works in bash but not in the native tool.

## Context

`terminal` runs **git-bash (MSYS)**, not PowerShell and not cmd. Nearly every confusing failure
on this host is one of six traps. Check this list before debugging anything else.

## The six traps

| Trap | Symptom | Fix |
|---|---|---|
| **No MSYS path translation for native binaries** | `git -C /c/Users/x` → `cannot change to`; `node /tmp/a.js` → `not found` | pass `C:/Users/x` forward-slash **native** paths to native tools |
| **bash variable expanded into a native argument** | `python "$HOME/x.py"` → `can't open file 'C:\c\Users\...'` — bash expands to `/c/...` and the native binary prepends the drive letter | never interpolate `$HOME`/`$PWD` into a native tool's argument; write `C:/Users/<user>/...` literally, or derive it (`python -c "import sys;print(sys.executable)"`). Bash builtins (`cd`, `mkdir`, `cp`, `ls`, `rm`) still take `$HOME` — mixing the two shapes in one command is the trap |
| **`/tmp` is not the scratch dir — and `$TMPDIR` can be `/tmp` too** | a native tool (python, node) cannot read what bash wrote there; the read fails **silently** and looks like the API returned an empty body | write to a **literal native path** (`C:/Users/<user>/AppData/Local/hermes/cache/scratch/x.json`) and confirm with `ls -l` before parsing. `echo $TMPDIR` first: on git-bash it may resolve to `/tmp` itself, so "use $TMPDIR" is not a fix on its own |
| **PowerShell-isms** | `Get-ChildItem`, `$env:FOO` → command not found | POSIX only: `ls`, `$FOO`, `grep`, `export` |
| **PTY Enter** | child prompt never returns | send a carriage return via `process(submit)`, never `process(write)` with `\n` |
| **Piping native stderr** | ffmpeg/node hang forever with `| head` | redirect to a file, read it after exit |
| **OneDrive Desktop** | `~/Desktop` is the wrong folder | real path is `$HOME/OneDrive/Desktop` |

## Python: resolve it, never assume

```bash
which python                 # → installs/*/environments/*/venv/Scripts/python
python -c "import sys;print(sys.executable)"
```

- This venv has **no `pip`**: `python -m pip install` fails with `No module named pip`.
- Install through the bundled uv, with a **native Windows path**:

```bash
UV="C:/Users/<user>/AppData/Local/hermes/tools/uv-0.13.5-win32-x64/uv.exe"
PY=$(python -c "import sys;print(sys.executable.replace(chr(92),'/'))")
"$UV" pip install --python "$PY" <packages>
```

A POSIX-shaped `--python /c/Users/...` fails with
`No virtual environment or system Python installation found` — that error means "wrong path
shape", not "missing environment".

### What is actually installed here (verified, uv-installed on 27 Oct 2026 WIB)

| Package | Version | Package | Version |
|---|---|---|---|
| `httpx` | 0.28.1 | `pandas` | 3.1.0 |
| `requests` | 2.33.0 | `numpy` | 2.5.4 |
| `curl_cffi` | 0.17.0 | `openpyxl` | 3.1.5 |
| `beautifulsoup4` | 4.15.0 | `xlsxwriter` | 3.3.0 |
| `lxml` | 6.1.3 | `python-docx` | 1.2.0 |
| `pillow` | 11.3.0 (moviepy pins <13) | `python-pptx` | 1.0.2 |
| `pyyaml` | 6.0.3 | `pypdf` | 6.21.3 |
| `jinja2` | 3.1.6 | `pdfplumber` | 0.11.10 |
| `duckdb` | 2.0.0 | `reportlab` | 5.1.0 |
| `web3` | 8.0.0 | `matplotlib` | 3.11.2 |
| `eth-account` | 0.14.0 | `qrcode` | 8.2 |
| `py-solc-x` | 2.0.5 (solc 0.8.26 installed) | `yt-dlp` | 2026.10.26 |
| `edge-tts` | 7.3.1 | `python-barcode` | 0.16.1 |
| `moviepy` | 2.2.1 | | |

Still missing: `playwright`, `camoufox`, `patchright`, `torch`, `faster-whisper`.
Not installable here: **Foundry** (`cast`/`forge`/`anvil`) — v1.8.6 ships no Windows asset, and this
host has no rust toolchain, WSL2 (virtualization disabled) or docker.

**uv resolver quirk:** the first install of a new package can spend ~3 minutes on index
resolution; re-installs hit cache in ~50ms. A 3-minute install is slow, not hung — do not kill it,
and do not retry a batch you just killed.

**Dependency pins can silently downgrade a working package.** Installing `moviepy` pulled
`pillow` from 13.0.0 down to 11.3.0. Re-run the smoke test after every install batch; a downgrade
that breaks an import shows up late, in an unrelated script.

Check before writing imports:

```bash
python -c "import importlib.util as u;[print(m, bool(u.find_spec(m))) for m in ['httpx','curl_cffi','numpy','yaml']]"
```

## Bundled tooling (use these, don't install rivals)

| Tool | Path |
|---|---|
| ffmpeg 9.0.1 (libx264+aac) | `$HERMES_HOME/tools/ffmpeg-9.0.1-win32-x64/bin` |
| node 24 / npm 11 | `C:/Program Files/nodejs` |
| uv 0.13.5 | `$HERMES_HOME/tools/uv-0.13.5-win32-x64/uv.exe` |
| gh 2.103.2 + wrapper | `$HERMES_HOME/bin/gh.exe`, `$HERMES_HOME/bin/ghget` |
| ripgrep 15 | `$HERMES_HOME/tools/ripgrep-15.2.0-win32-x64` |
| git 2.53 | `$HERMES_HOME/tools/git-2.53.0+3-win32-x64` |

### ffmpeg without the deadlock

```bash
FF="$HERMES_HOME/tools/ffmpeg-9.0.1-win32-x64/bin/ffmpeg.exe"
LOG="$TMPDIR/ff.log"
"$FF" -y -i in.mp4 -c:v libx264 -crf 23 -c:a aac out.mp4 > "$LOG" 2>&1
code=$?; tail -5 "$LOG"      # read after exit; never pipe stderr
```

## Background processes and servers

- Server/daemon: `background=True`, **no** notify (it never exits).
- Bounded job: `background=True, notify=True` so the result returns on exit.
- Health-check a server in a **separate** foreground call — never `sleep` inside a poll loop.
- Interactive CLI: `pty=True` + `process(submit)`.

```bash
curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://127.0.0.1:PORT/health
```

## Killing stuck processes

```bash
netstat -ano | grep ":20128" | head -3
taskkill //PID <pid> //F           # double slash: MSYS eats a single /
tasklist | grep -iE "chrom|node" | head -20
taskkill //IM chrome.exe //F
```

## Quoting

- Single quotes are literal in bash — safe for JSON: `-d '{"a":1}'`.
- Running `powershell.exe -Command` from this shell: wrap the script in **single quotes**.
  Inside double quotes bash expands `$_` and `${...}` before PowerShell sees them, so pipeline
  variables like `$_.CommandLine` arrive gutted — the error *"Missing expression after unary
  operator"* looks like a PowerShell syntax bug but is bash expansion. No single quotes possible?
  put the script in a `.ps1` file and call `powershell -File`.
- A JSON body with a shell variable needs close/reopen: `-d '{"to":"'"$ADDR"'"}'`.
- Backslashes inside double quotes need `\\`.
- Heredocs work and are the cleanest way to run multi-line python:
  `python - <<'EOF' ... EOF` (quoted delimiter = no expansion).

## Checklist before blaming the tool

1. Is the path shape native (`C:/...`) for a native binary?
2. Is the file at a literal native path a native tool can read — and is `$TMPDIR` actually native here (`echo $TMPDIR`)?
3. Is the interpreter the Hermes venv (`which python`)?
4. Is a missing module actually missing? (`find_spec`)
5. Did a pipe swallow stderr and hang the process?
6. Does the command need `pty` + carriage return?
