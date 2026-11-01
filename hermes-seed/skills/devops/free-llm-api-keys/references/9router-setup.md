# 9Router: self-hosted OpenAI-compatible gateway

9Router is a Node.js gateway that pools multiple AI provider connections behind one
OpenAI-compatible endpoint. Install it when you need to aggregate harvested sessions
or rotate across multiple provider keys from a single local port.

## Install

```bash
npm install -g 9router          # installs the CLI + Next.js standalone app
```

If the postinstall hook is skipped (`npm warn install-scripts`), re-run with:
```bash
npm install -g --allow-scripts=9router
```

Binary lands at `$HOME/AppData/Roaming/npm/9router` (Windows) or
`/usr/local/bin/9router` (POSIX).

## Headless startup on Windows

The `-n` (no-browser) flag does NOT skip the interactive menu — it only suppresses
browser launch. In a non-TTY background process the CLI receives EOF on stdin,
the menu selector returns "exit", and the server enters a crash loop
("Server exited (code=1). Restarting..."). The `-t` (tray) flag also crashes
because the tray child process is still a CLI invocation.

**Working headless startup:** run the Next.js standalone server directly, bypassing
the CLI menu entirely:
```bash
terminal(background=true, pty=true, command='cd "$HOME/AppData/Roaming/npm/node_modules/9router/app" && PORT=20136 HOSTNAME=127.0.0.1 exec node server.js')
```

`pty=true` is required — without a TTY, `node server.js` prints
`stdin is not a tty` and exits with code 1.

Verify: `curl -s http://127.0.0.1:20136/v1/models` returns `{"error":"API key required"}`
(server is alive).

## First-time password setup

A fresh 9Router install has `hasPassword: false` and no way to set the password
through the API (every `/api/*` endpoint returns `Unauthorized` until logged in).
The password is stored as a **bcrypt hash** in the `settings` table of the SQLite
DB at `<HOME>/AppData/Roaming/9router/db/data.sqlite`.

Set it directly in the database:
```bash
cd "$HOME/AppData/Roaming/9router/runtime"
npm install better-sqlite3 bcryptjs    # if not already present	node -e "
  const Database = require('better-sqlite3');
  const bcrypt = require('bcryptjs');
  const db = new Database('C:/Users/<user>/AppData/Roaming/9router/db/data.sqlite');
  const hash = bcrypt.hashSync('YOUR_PASSWORD', 10);
  const settings = { password: hash, setupComplete: true };
  db.prepare('INSERT OR REPLACE INTO settings (id, data) VALUES (1, ?)').run(JSON.stringify(settings));
  console.log('verify:', bcrypt.compareSync('YOUR_PASSWORD', hash));
"
```

**Field name is `password`, not `dashboardPassword`** — the auth check reads
`settings.password` (verified in compiled route `api/auth/status/route.js`).
SHA256 hashes do NOT work; only bcrypt (`$2b$`) is accepted.

Login endpoint: `POST /api/auth/login` with body `{"password":"..."}`. The
response sets an `auth_token` JWT cookie (24h expiry) for all subsequent API calls.

Check auth status without login: `GET /api/auth/status` returns `hasPassword`
and `authenticated` fields.

## Registering custom providers

9Router validates provider names against a built-in catalog — arbitrary names
like `cantutor` or `custom` are rejected with `{"error":"Invalid provider"}`.
Provider-node creation requires a `prefix` field and a known `type`.
To bridge a custom OpenAI-compatible upstream, register a provider connection
under a recognized type (e.g. `openai`) with a `baseUrl` pointing to your
local bridge.

## DB schema (for debugging)

Tables: `_meta`, `settings(id=1, data=TEXT)`, `providerConnections`, `providerNodes`,
`proxyPools`, `apiKeys`, `combos`, `kv(scope, key, value)`, `usageHistory`,
`usageDaily`, `requestDetails`.

Settings is a single row (`id=1`) with a JSON blob in `data`. The KV table holds
`modelAliases`, `customModels`, `mitmAlias`, and `pricing` scopes.
