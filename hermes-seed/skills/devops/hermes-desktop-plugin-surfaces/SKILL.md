---
name: hermes-desktop-plugin-surfaces
description: "Use when restyling or extending Hermes Desktop UI."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [windows, macos, linux]
metadata:
  hermes:
    tags: [desktop, plugin, ui, token-usage, verification, cdp]
---

# Hermes Desktop plugin surfaces

Extend or restyle the Hermes desktop app **without editing core and without a
rebuild**: a plugin is one plain-ESM `plugin.js` the renderer hot-loads.

## Where plugins live

- `$HERMES_HOME/desktop-plugins/<id>/plugin.js` — folder name must equal `id`.
- Loaded within seconds of the file landing; every later save hot-reloads.
- Imports resolve **only** `@hermes/plugin-sdk`, `react`, `react/jsx-runtime`.
  No JSX syntax — `jsx()`/`jsxs()` calls only.
- Loader source of truth: `apps/desktop/src/contrib/runtime-loader.ts`.

## Surface → area map (all exported from the SDK)

| Want | Register |
|---|---|
| Full page in the workspace pane | `ROUTES_AREA`, `data:{path:'/x'}`, `render` |
| Sidebar row | `SIDEBAR_NAV_AREA`, `data:{path,label,codicon}`, `order` earlier = higher |
| ⌘K command | `PALETTE_AREA`, `data:{id,label,run,...}` |
| Dockable panel | `'panes'`, `data:{placement:'right',width:'318px'}` |
| Status-bar chip | `'statusBar.right'` (or `.left`) |
| **Per-session-row decoration** | `SESSION_ROW_AREAS.trailing` / `.leading`, `data:{render:({sessionId})=>…}` — `sessionId` is the durable lineage id (`_lineage_root_id ?? id`) |
| Empty-chat slot | `CHAT_EMPTY_AREA` |
| Sidebar profile-group header | `SIDEBAR_PROFILE_GROUP_HEADER_AREA`, `data:{render:route=>…}` |
| Theme | `THEMES_AREA`, `data` is a full `DesktopTheme` (`colors` + `darkColors`) |

A `palette` row needs `{id,label,run}` — `{title,subtitle}` is silently ignored.

## Data doors that already exist

- `window.hermesDesktop.api({path})` — the same authenticated renderer bridge
  core uses. Works for `/api/analytics/usage?days=N` (totals, daily, by_model)
  and `/api/profiles/sessions?profile=<p>&limit=200&order=recent` (session rows
  with `input_tokens`, `output_tokens`, `estimated_cost_usd`, `model`).
- `host.listPersistedSessions(null,{profile,limit})` — SDK proxy for the same list.
- `host.state.focusedUsage` — live `UsageStats` of the focused chat (input,
  output, cost_usd, context_used/max/percent); no polling needed.
- `host.request(method, params)` — gateway JSON-RPC (`session.list`, `session.stats`, …).
- `/api/sessions?…` may 422 from the bridge; `/api/profiles/sessions` answers 200.
- Per-message tokens: `messages.token_count` exists in `state.db` but **no**
  REST/RPC route exposes it — label any per-message number as an estimate.

## Pitfalls that cost real time

1. **Plugin classes are not in the app's compiled Tailwind CSS.** Style with your
   own namespaced class names in an injected `<style>` (append once to
   `document.head`), and read theme vars (`--card`, `--foreground`, `--border`,
   `--muted-foreground`, `--accent`) plus `color-mix()`. Dark mode keys off
   `[data-hermes-mode="dark"]`.
2. **`color-mix(... N%, transparent)` cards over pastel background gradients go
   washed out.** Use opaque `var(--card)` for cards and panels; keep decorative
   blobs to ≤0.35 opacity and out of the text column.
3. **A hot reload disposes the old contributions**, so a contributed route you
   are sitting on silently falls back to the chat. Re-navigate after every save.
4. **Nav order is registration order unless you set `order`** — two plugins both
   adding a row will swap places on reload without it.
5. **Core already prints the session's token total** in the row meta when the
   `Tokens` row-meta preference is on (`session-row.tsx`). A token badge in
   `sessionRow.trailing` is duplicate noise; use it for spend or another fact.
6. **Cost can legitimately be `—`**: vendors like `api.tokenomixai.com` report
   `0.0 / unknown`, so never print a fabricated price.
7. `onEvent` lives on **`ctx`**; `queryClient` is a **module import**, not `ctx.queryClient`.

## Verifying on a packaged build (no CDP)

A packaged/unpacked `Hermes.exe` keeps the DevTools port closed, so DOM reading
is out. Use the desktop loop instead:

1. `computer_use(action='capture', app='Hermes', mode='vision')` → screenshot path.
2. Read it with `vision_analyze` — ask concrete questions ("which card labels are
   legible", "is any panel clipped by the footer").
3. Click with `computer_use(action='click', coordinate=[sx,sy], delivery_mode='foreground')`.
   **Coordinates are SCREENSHOT-space and get scaled ~1.32× to native** on a
   1920-wide window; background `click` on element indexes often does not reach
   React — foreground + coordinates is the reliable path.
4. Iterate: save plugin → wait ~6 s for hot reload → re-navigate → re-capture.
5. Put real numbers on screen (`13,063,360 tok`, `240 messages`) — that is the
   proof the data path works, not a green toast.

## Hygiene

- Back the folder up before rewriting: `cp -r desktop-plugins backups/…`.
- Syntax-check every save: copy to `*.mjs` and `node --check`.
- Ship a `README.md` per plugin with its surfaces, data sources, honest limits
  and the one-line rollback (`rm -rf` the folder + Reload desktop plugins).
- Never touch `state.db`, `config.yaml` or sessions — the plugin layer is
  read-only by design.
