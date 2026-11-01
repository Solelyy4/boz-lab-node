# Windows-Specific Quirks

Hermes runs natively on Windows (PowerShell, cmd, Windows Terminal, git-bash
mintty, VS Code integrated terminal). Most of it just works, but a handful
of differences between Win32 and POSIX have bitten us — document new ones
here as you hit them so the next person (or the next session) doesn't
rediscover them from scratch.

### Input / Keybindings

**Alt+Enter doesn't insert a newline** — Windows Terminal (and mintty) grab it
for fullscreen before prompt_toolkit sees it. Use **Ctrl+Enter** instead (the
CLI binds it to newline on Windows; raw Ctrl+J does the same, harmlessly).
To inspect how your terminal reports a keystroke, run
`python scripts/keystroke_diagnostic.py` from the repo root.

### Config / Files

**HTTP 400 "No models provided" on first run** — `config.yaml` was saved with
a UTF-8 BOM (Notepad does this). Re-save as UTF-8 without BOM;
`hermes config edit` writes correctly.

### `execute_code` / Sandbox

**WinError 10106** from the sandbox child process — it can't create an
`AF_INET` socket. Root cause is usually Hermes's env scrubber dropping
`SYSTEMROOT`/`WINDIR`/`COMSPEC` (Python's `socket` needs `SYSTEMROOT` to find
`mswsock.dll`), not a broken Winsock LSP. The `_WINDOWS_ESSENTIAL_ENV_VARS`
allowlist in `tools/code_execution_env.py` covers it; if you still hit it,
echo `os.environ` inside an `execute_code` block to confirm `SYSTEMROOT` is set.

### Testing on Windows

Prepare the checkout through PM first. With its Python 3.14, build an independent
test environment at a fresh path:

```powershell
python -m pm.build_env --source . --out .venv --group dev --group test
```

The output must not exist. Before regeneration, stop its processes and explicitly
remove only that disposable environment. Do not install into the application
payload or modify a selected dependency generation.

Run the canonical runner through Git Bash:

```bash
scripts/run_tests.sh tests/foo/test_bar.py -v --tb=short
```

The runner discovers `.venv/Scripts/python.exe`, clears credentials and
`PYTHONPATH`, and isolates each test file. For an external test environment,
set `HERMES_PYTHON` to its Python executable. PM shell activation alone does
not supply pytest after the runner clears `PYTHONPATH`.

### Path / Filesystem

**Line endings.** Git may warn `LF will be replaced by CRLF`. Cosmetic — the
repo's `.gitattributes` normalizes. Don't let editors auto-convert committed
POSIX-newline files to CRLF.

**Forward slashes work almost everywhere.** `C:/Users/...` is accepted by
every Hermes tool and most Windows APIs. Prefer forward slashes in code
and logs — avoids shell-escaping backslashes in bash.

### Smart App Control (SAC) blocks unsigned locally-compiled binaries

Windows 11 SAC in Enforcement mode validates every executable against cloud
reputation — not directory, not file extension. A binary you compiled locally
(Go, Rust, C) has no reputation and is blocked with "An Application Control
policy has blocked this file" even though the same directory holds trusted
binaries that run fine. Self-signed code-signing certificates do NOT help —
the root CA is untrusted, so `Set-AuthenticodeSignature` returns
`UnknownError`. Disabling SAC requires admin (the registry key
`HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy` is read-only for
non-admin) and is irreversible (once off, it cannot be re-enabled without a
Windows reset). Workarounds without admin: deploy the binary to a remote
VPS/Linux host, use WSL, or cross-compile for the target platform and run
elsewhere. To check SAC status:
```
powershell -Command "(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy').VerifiedAndReputablePolicyState"
```
`0` = off, `1` = enforced, `2` = evaluation mode.

### Go toolchain without admin

Install Go from the **zip distribution**, not the MSI — the MSI requires admin
and hangs in background mode (msiexec waits for an interactive prompt that
never arrives when piped). Download, extract, and set `GOROOT` to a **native
Windows path** (MSYS paths like `/c/Users/...` are rejected by Go):
```bash
curl -L -o /tmp/go.zip "https://go.dev/dl/go1.23.4.windows-amd64.zip"
mkdir -p ~/go-toolchain && cd ~/go-toolchain && unzip -o /tmp/go.zip
export GOROOT="C:/Users/$USER/go-toolchain/go"
export GOPATH="C:/Users/$USER/go"
export PATH="$GOROOT/bin:$PATH"
go version
```
`make` is not available in git-bash; run `go build` directly with the same
flags the Makefile uses: `CGO_ENABLED=0 go build -trimpath -ldflags "-s -w"
-o bin/app.exe ./cmd/app`. Cross-compile for Linux with `GOOS=linux GOARCH=amd64`.
