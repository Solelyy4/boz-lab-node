Hermes home (Windows): C:\Users\zahin\AppData\Local\hermes, exposed as $HERMES_HOME; no profiles exist yet, profile roots would be $HERMES_HOME/profiles/<name>.
§
Identity stack v17 compact: SOUL.md 7.7KB + AGENTS.md 6.8KB di <BASE>, ~, shared/elyy (prompt 164KB→57KB). Naskah penuh v16.8 + blueprint + godmode: skill elyy-atlas-full/references. Sync: bash <BASE>/bin/elyy-sync.
§
Hermes loads AGENTS.md from cwd only, so the always-armed carrier is SOUL.md plus the auto-loaded skill elyy-ops-atlas (config skills.auto_load + skills.external_dirs).
§
Host clock is UTC+8 (MPST); WIB = host minus 1 hour. Convert before writing timestamps or cron schedules.
§
Guardrail patch set: <HERMES_HOME>/apply_patches.py — green verdict is the line 'RESULT: ALL BYPASS GUARDRAILS VERIFIED ACTIVE' (18 components). Source patches bind at process start, so live effect needs `hermes gateway restart`.
§
Identity-stack watchdog cron: job 6be3aece2f2a (no_agent, silent when healthy), 10:00 host = 09:00 WIB, runs <HERMES_HOME>/scripts/guardrail_watchdog.sh, logs to logs/guardrail_watchdog.log.
§
Model Hermes (30 Okt 2026): primer custom:tokenharbor mimo-v2.5:free; fallback deepseek-v4.1-flash:free → openrouter nemotron-3-ultra:free → groq gpt-oss-120b.
§
GitHub siap pakai: gh 2.103.2 di <HERMES_HOME>/bin/gh.exe + wrapper <HERMES_HOME>/bin/ghget (repo/file/tree/rel/asset/search/info); login akun Solelyy4 (token di Windows keyring, scopes repo/read:org/gist/workflow), kuota API 5.000/jam.
§
Video: ffmpeg 9.0.1 di <HERMES_HOME>/tools/ffmpeg-9.0.1-win32-x64/bin (libx264+aac); PIL ada; numpy/moviepy/manim/cv2 TIDAK terpasang. Catatan: stderr ffmpeg jangan di-pipe (deadlock) — tulis ke file.
§
Desktop BOZ di OneDrive\Desktop (bukan C:\Users\zahin\Desktop). Key provider di $HERMES_HOME/.env via tool `freeapi`.
§
Token Harbor free API: custom provider `tokenharbor` (https://tokenharbor.ai/v1), 4 model `:free`; key <HERMES_HOME>/secrets/tokenharbor.key; free route = data boleh dibaca staf/provider train. Skill: tokenharbor-free-api.
§
TeleKey bot (v8, projects/telekey-bot): token in <HERMES_HOME>/secrets/telegram_bot_token; .env token must stay commented (one poller); skill telekey-bot-ops.