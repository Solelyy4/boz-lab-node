# Project Context Files

Hermes injects project-level instructions into the system prompt by reading context files from the working directory. The discovery order is **first match wins** — only one project context source is loaded per session.

| File (in priority order) | Discovery | Use when |
|---|---|---|
| `.hermes.md` / `HERMES.md` | Walks parents up to the git root, stops at git root | You want hierarchical project rules (root + per-package overrides) |
| `AGENTS.md` / `agents.md` | **Cwd only** — subdirectory and parent copies are ignored | You want portable agent instructions that work the same in Hermes, Claude Code, Codex, etc. |
| `CLAUDE.md` / `claude.md` | Cwd only | Same as AGENTS.md, Claude-flavored |
| `.cursorrules` / `.cursor/rules/*.mdc` | Cwd only | Migrating from Cursor |

`SOUL.md` (in `$HERMES_HOME`) is independent and always loaded when present — it sets the agent's identity, not project rules.

### Pick the right one

- **Use `.hermes.md`** when you want Hermes-specific behavior that lives above the cwd (root + subtree), or when you want rules to inherit from a parent directory. The parent walk stops at the git root, so a home-level `.hermes.md` won't leak into every project (a git repo's root is the boundary).
- **Use `AGENTS.md`** when the same project will also be worked on by other agents (Codex, Claude Code, OpenCode). Those tools all have their own conventions for `AGENTS.md`, and the "cwd only" contract keeps the file portable.
- **Don't put project rules in `~/.hermes/AGENTS.md`** (or any other home-level location). When Hermes runs with that directory as cwd, the file loads — but only for that one directory. For cross-project context, use `SOUL.md` (in `$HERMES_HOME`, identity-only) or install a skill via `hermes skills install`.

### Size and truncation

The cap is runtime-configurable, not a fixed constant — check `context_file_max_chars` in `$HERMES_HOME/config.yaml` and treat an absent key as "runtime default", never as a number to quote at the user. Measured in practice: a `SOUL.md` of ~59,000 characters is injected whole, so the practical ceiling is far above the older 20,000 figure. Above the cap a file gets **head + tail** truncated (middle dropped, `[...truncated...]` marker). Note the two units diverge — `wc -c` is **bytes**, the config key is **characters**, and non-ASCII prose spends more bytes than characters. Budget against the larger of the two numbers.

### Security

All context files pass through the threat-pattern scanner before reaching the system prompt. Patterns matching prompt injection or promptware are replaced with a `[BLOCKED: ...]` placeholder. This means an `AGENTS.md` containing obvious injection attempts won't reach the model — the scanner blocks the content, not the file, so the rest of the file still loads.

### Disable for one session

`hermes --ignore-rules` skips auto-injection of all project context files (`.hermes.md`, `AGENTS.md`, `CLAUDE.md`, `.cursorrules`) **and** `SOUL.md` identity, plus user config, plugins, and MCP servers. Use it to isolate whether a problem is your setup or Hermes itself.

### Example: a small `.hermes.md`

```markdown
# My Project

Hermes: when working in this repo, follow these rules.

## Build
- Always run `make test` before declaring a change done.
- Use `uv run` for Python, not `pip install`.

## Style
- Prefer `pathlib.Path` over `os.path`.
- No `print()` in production code — use the `logger`.
```

That file at `/home/me/projects/myrepo/.hermes.md` is auto-loaded when Hermes runs in any subdirectory of `/home/me/projects/myrepo`, but not when it runs in `/home/me/other-project`.

### Maintaining an existing context file (SOUL.md / AGENTS.md)

A large hand-maintained identity/ops stack is a different job from authoring a small `.hermes.md`: it sits near a hard size gate, cross-references itself, and carries host-specific claims that rot. Do it in this order.

1. **Resolve the real home before reading anything.** `$HERMES_HOME` if set; Windows `%LOCALAPPDATA%\hermes`; POSIX `~/.hermes`. A doc that names its own path may be wrong on the machine you are on — locate it, then patch only files you actually opened.
2. **Back up before the first write** into `$HERMES_HOME/backups/<label>-<timestamp>/`. That copy doubles as the baseline for step 5.
3. **Budget in bytes.** Print `len(text)` and `len(text.encode())` — the byte count is the strict reading, and a file that reports "59.9k chars" can already be over a 60,000-byte gate.
4. **Make the edit set exact and countable.** Build `(old, new)` pairs, replace, and print a hit count per pair; `MISS x0` means your assumption about the source text was wrong, so fix the string rather than writing a half-applied file. Run targeted replacements that need the original text **before** glob-style ones (`~/.hermes` → `<HERMES_HOME>`), otherwise the glob eats the anchor.
5. **On overshoot, re-apply from the baseline — do not shave the patched file.** Re-running the whole set against the backup with tighter wording is reproducible; line-by-line shaving drifts and hides what changed.
6. **Replace host-specific paths with placeholders.** `<HERMES_HOME>/...`, `<HOME>/...`; a hardcoded interpreter becomes "resolve live (`which python`)" with platform variants in parentheses. The file is re-injected on other machines, profiles and installs, where absolute paths are false claims.
7. **Audit inherited claims; never re-assert them.** Counts, md5s, hostnames, IPs, "N skills installed", "file exists at X", "script at Y" are all claims — verify on disk. If it is absent, rewrite the sentence as the rule that keeps it true ("count live", "md5 checked at use", "script optional if installed") instead of deleting its purpose. A context file asserting absent paths makes the next session fabricate evidence to match it.
8. **Keep cross-reference parity.** Adding or removing a section means updating every `§` reference pointing at it, in every file of the stack — the gate checks both directions.
9. **Never put a `|` inside a table cell**, not even inside backticks: GFM splits the cell there. Rephrase ("find … then count the lines") or escape as `\|`.
10. **Verify, then report read-after-write.** Run `scripts/verify_context_files.py <HERMES_HOME>` (size, md5, cross-doc `§` refs, machine-path leaks, table integrity), paste the changed lines as read back from disk, and state the remaining headroom.
11. **Say the edit is not live in this session.** The system prompt was assembled at session start, so the running turn still answers from the old copy until the next context load (new session, `/new`, or compression). Claiming it applies immediately is a false success report.

When the doc declares its own gate (a checklist with size, dead-ref, table and privacy rules), run that gate literally and report each line as pass/fail — do not substitute a looser reading of it, and never edit the gate rule to make a file fit.
