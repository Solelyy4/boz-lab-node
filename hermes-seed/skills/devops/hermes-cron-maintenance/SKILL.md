---
name: hermes-cron-maintenance
description: "Use when creating or debugging Hermes cron jobs."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [cron, scheduler, watchdog, automation, hermes]
    related_skills: [hermes-agent, windows-bash-ops]
---

# Hermes Cron Maintenance

## When to Use

Creating a scheduled job, a recurring monitor, or a watchdog — or when a job "didn't run", ran
late, delivered nothing, or spams the same alert every tick.

## Verified CLI surface (this host)

```bash
H="$HERMES_HOME/bin/hermes.exe"
"$H" cron status        # is the scheduler alive
"$H" cron list          # jobs, next run, last run, mode
"$H" cron runs <id>     # durable execution attempts
"$H" cron incidents     # failures needing acknowledgement
"$H" cron doctor        # common health issues
"$H" cron notepad <id>  # durable KV across runs
"$H" cron pause|resume|remove <id>
"$H" cron tick          # run due jobs once and exit (debugging)
```

Prefer the `cronjob_manage` tool for creation (`action='create'` requires `schedule` + `prompt`),
CLI for inspection and repair.

## Two job shapes

| Shape | Config | Use for |
|---|---|---|
| **Script-only** | `no_agent=True` + `script="x.sh"`; empty stdout = no delivery | watchdogs, health pings, cheap checks |
| **Agent** | prompt + optional `skills`, `workdir`, `enabled_toolsets` | anything needing reasoning |

A watchdog that speaks only when broken is the correct default: silence is the healthy signal.

## Schema facts that decide whether a job works

- **`workdir` must be absolute and existing**; it is what injects that directory's `AGENTS.md`.
  A job that needs project rules **must** set `workdir` (e.g. `C:/Users/<user>`), or it runs with
  no project context.
- **Prompts must be self-contained.** Fresh session, no chat history, no ability to ask.
- **`enabled_toolsets`** trims token cost — name only what the job needs (`["web","terminal"]`).
- **`deliver`**: omit for the origin chat, `local` to save without sending, explicit target
  otherwise. `failure_deliver='local'` silences failure notices in shared channels.
- **`continuity=True`** lets a job see its own previous output (dedupe, incremental digests).
- **`monitor`** gates the agent on changed output (deterministic output only — no timestamps).
- **`context_from=[job_id]`** chains jobs; the upstream must complete first.

## Timezone discipline (this host)

The host clock is **UTC+8**; WIB is UTC+7. A job meant for 09:00 WIB is scheduled at 10:00 host:

```
09:00 WIB  ==  10:00 host  ==  "0 10 * * *"
```

State which clock you used in the job name or prompt. Never assume the scheduler converts TZ.

## Script rules for `no_agent` jobs

```bash
#!/usr/bin/env bash
set -uo pipefail
LOG="$HERMES_HOME/logs/job.log"
mkdir -p "$(dirname "$LOG")"

out=$(some_check 2>>"$LOG")
rc=$?
if [ $rc -ne 0 ]; then
  echo "CHECK FAILED rc=$rc: $out"      # only a broken state reaches the user
fi
exit 0
```

- Resolve python explicitly (`$(command -v python)`); never assume `python3`.
- Redirect stderr to the log — stray stderr can be delivered as noise.
- Truncate the log inside the script when it grows (keep the last ~1000 lines).
- One alert per failure class per 24h: store the last-sent timestamp in `/tmp/<job>_last_alert`.

## Diagnosing "it didn't run"

1. `cron status` — scheduler running? If not, nothing else matters.
2. `cron list` — is the job `active`, and what is `Next run`? A past `Next run` with no `Last run`
   means dispatch is stuck.
3. `cron runs <id>` — durable attempts, exit status, timestamps.
4. `cron incidents` — failures needing acknowledgement; a stuck incident can block reruns.
5. `cron doctor` — config-level problems.
6. Watch for `catch-up after missed fire`: the host slept and the job ran late. Harmless for
   monitors, dangerous for anything time-sensitive.

## Diagnosing "it delivered the same message again"

- Watchdog printing on success → fix the condition, not the schedule.
- Agent job repeating itself → set `continuity=True` and tell it to compare with its last output.
- `monitor` on output containing a timestamp → every tick looks changed; strip the timestamp.

## Creating a job safely

```python
cronjob_manage(action="create",
    name="disk watchdog",
    schedule="0 10 * * *",          # 10:00 host = 09:00 WIB
    no_agent=True,
    script="disk_watchdog.sh",
    failure_deliver="local")
```

Then confirm with `cron list` that `Next run` is the timestamp you intended, and force one run
(`cron run <id>` or `cron tick`) before walking away.

## Checklist

- [ ] `cron status` healthy
- [ ] `Next run` matches the intended WIB time after conversion
- [ ] Prompt self-contained (no reference to this chat)
- [ ] `workdir` set if the job needs project rules
- [ ] Script resolves python explicitly, logs to file, silent when healthy
- [ ] One forced run verified in `cron runs`
