---
name: elyy-multiprofile-stack
description: "Use when maintaining BOZ identity stack across profiles."
version: 1.0.0
author: BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, profiles, soul, agents, auto-load, identity, maintenance]
---

# elyy multiprofile identity stack

## When to Use

- BOZ edits or extends `SOUL.md` / `AGENTS.md`, or asks why the persona is missing in a session.
- A new profile is created and must carry the same identity and execution laws.
- A session started in a different cwd does not show `AGENTS.md`.
- Before claiming "identity stack is armed everywhere" — verify, then say it.

Goal: identity (`SOUL.md`) and execution atlas (`AGENTS.md`) stay armed in **every profile and
every session**, whatever the cwd. Two Hermes facts drive the whole design:

1. `SOUL.md` is loaded from the **active home** (`$HERMES_HOME`) on every session — always armed.
2. `AGENTS.md` is **cwd-only** and first-match-wins. A copy at the Hermes root loads *only* when
   cwd is that root. Never rely on it as the global carrier.

## Architecture (4 parts)

| Part | Path | Role |
|---|---|---|
| Canon | `<BASE>/shared/elyy/{SOUL.md,AGENTS.md}` | single source of truth, outside every profile root |
| Auto-load skill | `<BASE>/shared/elyy/skills/elyy-ops-atlas/SKILL.md` | compact 21-laws core injected into **every** session via `skills.auto_load` (cwd-independent) |
| Config | `skills.auto_load: [elyy-ops-atlas]` + `skills.external_dirs: [<BASE>/shared/elyy/skills]` | per home/profile; external dirs are read-only, so one copy serves all profiles |
| Deployer | `<BASE>/bin/elyy-sync` → `shared/elyy/elyy_sync.py` | copies canon to root + every `profiles/*`, audits config, md5-verifies |

`<BASE>` = `$HERMES_HOME`, or two levels up when it ends in `/profiles/<name>`. Never hardcode an
absolute path — resolve live.

Porting the persona to a model that is not Hermes (ChatGPT / Custom GPT / Project) →
`references/external-model-persona.md`.

## Profil model kecil (`lite`) — buang berat prompt, kekalkan capability

Model 8B–12B (ministral, codestral, qwen kecil) "merapu/pening" bila diberi prompt 160+ KB:
ia ulang kandungan SOUL/AGENTS sebagai jawapan. Diagnosa dulu dengan angka, jangan teka:

```bash
hermes prompt-size              # default: ~164 KB (stable 87K, context 60K, volatile 16K)
hermes -p lite prompt-size      # sasaran: < 40 KB
```

Resepi 4 langkah (semua melalui `config set`, tiada fail disentuh):

1. **Skills dikongsi, bukan disalin.** Folder `skills/` boleh 500+ MB — jangan `cp`.
   ```bash
   hermes -p lite config set skills.external_dirs '["<BASE>/skills","<BASE>/shared/elyy/skills"]'
   ```
   Yang masuk prompt cuma **indeks** (~8.7 KB untuk 95 skill); badan skill dibaca on-demand
   melalui `skill_view`. Jadi skill baharu di `default` terus nampak dalam `lite`.
2. **Memori + profil BOZ**: salin `memories/MEMORY.md` dan `memories/USER.md` ke
   `profiles/lite/memories/` (~4 KB).
3. **Kunci sebenar — `context_file_max_chars` (TOP-LEVEL, bukan bawah `agent:`).**
   ```bash
   hermes -p lite config set context_file_max_chars 8000
   ```
   Ia memotong `AGENTS.md` 59 KB → 8 KB (head+tail) pada setiap muat konteks.
   `agent.context_file_max_chars` DITOLAK (`Custom top-level keys are supported; use --force`).
4. **Uji tiga lapis**, bukan satu soalan: (a) penjelasan 2 ayat, (b) tulis fail dan semak fail
   di disk, (c) tugasan tools (git clone / GitHub API). Lulus ketiga-tiga = profil boleh dipakai.

Keputusan diukur pada host ini: `lite` = **34.2 KB** prompt (dari 164 KB), dengan skills index
8.7 KB + memori 3.2 KB + profil 1.6 KB kekal. Ministral-8b menjawab bersih, menulis fail, dan
clone repo dalam profil itu.

### Pitfall

- **`--ignore-rules` bukan penyelesaian**: ia mematikan SOUL + memori + skills sekali gus
  (`skip_context_files = skip_memory = True`, `load_soul_identity = False`), jadi profil jadi
  kosong, bukan ringan. Guna `context_file_max_chars` bila matlamatnya "kecil tapi berkemampuan".
- **Personality/persona tidak membuang context file** — ia lapisan tambahan; AGENTS.md tetap
  dimuat. Jangan harap personality pendek menyelesaikan prompt bengkak.
- **Dua profil = dua memori bercabang.** Salinan `MEMORY.md` ialah snapshot; lepas itu `default`
  dan `lite` menulis fakta berbeza. Kalau mahu satu memori, arahkan kedua-dua profil ke fail
  memori yang sama secara sedar, dan sebutkan trade-off itu kepada BOZ.
- **AGENTS dipotong = atlas penuh tidak dalam prompt.** Masih ada di disk (`<BASE>/AGENTS.md`,
  `<BASE>/shared/elyy/AGENTS.md`) dan skill `elyy-ops-atlas` auto-load; sesi `lite` yang perlu
  butiran operasi mesti baca fail itu, bukan andaikan ia sudah dimuat.
- **Tukar profil sticky mengganggu subprocess.** `hermes profile use <x>` mengubah lalai untuk
  semua pemanggilan CLI tanpa `--profile` — termasuk bot/cron yang spawn `hermes -z`. Setiap
  pemanggil yang mesti kekal pada identiti penuh wajib pin `--profile default` dalam argv.

## Commands

```bash
bash <BASE>/bin/elyy-sync --check        # audit: file drift + config drift, writes nothing
bash <BASE>/bin/elyy-sync               # deploy files
bash <BASE>/bin/elyy-sync --fix-config  # also run `hermes [-p <profile>] config set` per home
bash <BASE>/bin/elyy-sync --force       # adopt: overwrite files that are not ours (new profile stock SOUL.md)
```

New profile adoption = `--force --fix-config` (a fresh profile ships its own `SOUL.md`, so it
reports `CONFLICT` and refuses to clobber until forced).

## Workflow when editing the stack

1. Edit the **canon** copy in `<BASE>/shared/elyy/`, never a deployed copy.
2. Re-run the doc's own gate (size ≤60,000 **bytes**, cross-`§` refs both ways, no `|` inside a
table cell, no absolute machine paths). Budget bytes: Indonesian prose is multibyte, so a file
that reads "58.8k chars" can still be over a 60,000-byte gate.
3. `bash <BASE>/bin/elyy-sync` then `--check` — demand `drift=0 conflict=0 config_drift=0`.
4. Run the bundled gate instead of hand-rolling one: `scripts/verify_context_files.py` inside the
   **hermes-agent** skill directory, invoked with the Hermes home. It covers size, md5, cross-doc
   `§` refs, machine-path leaks and table integrity in one pass; a hand-written checker silently
   drifts from what the doc demands and burns a round of debugging.
5. Verify the injection path for real instead of assuming:
   ```bash
   cd <BASE>/hermes-agent && python -c "import sys;sys.path.insert(0,'.');\
   from agent.skill_commands import build_auto_load_prompt as b;\
   p,l,m=b(task_id='t');print(l,m,len(p),'21 HUKUM' in p)"
   ```
6. Say it plainly: config and file changes take effect on the **next** context load (new session,
   `/new`, or compression), not in the running turn.

## Pitfalls

- **Don't** put cross-project rules in a home-level `AGENTS.md`. It loads only when cwd is that
  directory; for guaranteed availability use `SOUL.md` (identity slot) or `skills.auto_load`.
- `.hermes.md` walks up to the git root; `AGENTS.md`/`CLAUDE.md`/`.cursorrules` are cwd-only.
- Auto-load injects the **whole** `SKILL.md`, so keep the auto-loaded skill compact (~5–10 KB) and
  keep the 60 KB atlas on disk behind a pointer — otherwise every session pays for it twice.
- `skills.external_dirs` is read-only: skill **creation** still writes to `<home>/skills`.
- Config changes go through `hermes [-p PROFILE] config set KEY 'JSON'` — arrays accept JSON.
  Never hand-edit `config.yaml`.
- A skipped deploy is a `CONFLICT`, not a failure: inspect before forcing, so a hand-customized
  profile SOUL is not silently replaced.
- Watchdog also runs from cron (`no_agent`), so it must not depend on the caller's `PATH`:
  resolve the interpreter from the Hermes install layout
  (`<BASE>/installs/*/environments/*/venv/Scripts/python.exe`, then `command -v python`).
  If the subprocess never starts, its non-zero exit reads as permanent drift. Keep the whole
  report on stdout, append `base/py/rc` to a log, and always `exit 0` — a non-zero exit turns a
  diagnostic line into a raw error alert. It reports guardrail status only; repair on demand
  with `--repair-guardrail`.
- The cron entrypoint must sit in `<BASE>/scripts/` (the job's `script` field rejects absolute
  paths): a three-line wrapper that re-resolves `<BASE>` and `exec`s the real script.
