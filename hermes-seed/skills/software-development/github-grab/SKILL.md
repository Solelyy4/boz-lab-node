---
name: github-grab
description: "Use when pulling repos, files, releases from GitHub."
version: 1.0.0
author: BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [github, fetch, clone, api, releases]
---

# Taking material from GitHub

## When to Use

- "ambil repo/fail/release dari GitHub", "clone this", "read that file on GitHub".
- Needing repo metadata, commit history, release assets, or code search without a full clone.

## Tools on this host

| Tool | Where | Notes |
|---|---|---|
| `git` 2.5x | PATH | clone, LFS 3.x installed |
| `gh` 2.10x | `<HERMES_HOME>/bin/gh.exe` (copied from `tools/gh/bin`) | winget needs a tty — install by downloading the release zip instead |
| `ghget` | `<HERMES_HOME>/bin/ghget` | one-line wrapper for the common grabs |

### Installing `gh` on Windows when winget refuses

`winget` needs a TTY and fails under a tool shell (`stdin is not a tty`). Fetch the release zip
instead — no admin, no installer:

```bash
TAG=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | python -c "import sys,json;print(json.load(sys.stdin)['tag_name'])")
VER=${TAG#v}
curl -L --fail -o "$HERMES_HOME/cache/scratch/gh.zip" \
  "https://github.com/cli/cli/releases/download/$TAG/gh_${VER}_windows_amd64.zip"
unzip -q "$HERMES_HOME/cache/scratch/gh.zip" -d "$HERMES_HOME/tools/gh"
cp "$HERMES_HOME/tools/gh/bin/gh.exe" "$HERMES_HOME/bin/"   # bin/ is already on PATH
gh --version
```

## One-liners (`ghget`)

```bash
ghget repo  owner/repo [folder]      # shallow clone
ghget file  owner/repo path/to/f     # print raw file
ghget tree  owner/repo [ref]         # every path in the repo
ghget rel   owner/repo [tag]         # release assets + sizes
ghget asset owner/repo v1.2.3 name.zip
ghget search "jwt verify" 20         # code search (needs login)
ghget info  owner/repo               # metadata JSON
```

## Auth

- Public + anonymous: works for clone and raw file fetch; REST API is **60 req/hour per IP**.
- `gh auth login --hostname github.com --git-protocol https --web` → device flow, one-time code,
  user authorizes in a browser. Never ask the user to paste a token in chat.
- Authenticated: **5,000 req/hour**, private repos, PR/issue actions, code search.
- Tokens are **free** with a GitHub account; do not tell the user otherwise.
- After login: `gh auth setup-git` so plain `git clone` of private repos works too.

## Without gh (curl fallback)

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH
curl -fsSL https://api.github.com/repos/OWNER/REPO          # metadata
curl -fsSL -o r.tgz https://codeload.github.com/OWNER/REPO/tar.gz/refs/heads/main
```

## Pitfalls

- **An unauthenticated `gh` refuses every command**, including `gh api` for a public repo
  ("To get started with GitHub CLI, please run: gh auth login"). A wrapper built on `gh` must
  detect that (`gh auth status` exit code) and fall back to `curl` for public material, or it is
  dead weight until the user logs in.
- `gh auth login --web` asks **"Authenticate Git with your GitHub credentials? (Y/n)"** *before*
  printing the one-time code: answer `Y`, then Enter to open the browser, then read the code from
  the output and hand it to the user.
- The device page requires being signed in to an existing GitHub account — it does not create one.
  Say so plainly; creating an account is optional and free, and public reads need no account at all.
- MSYS `/tmp` is unreliable for native binaries: download into `$HERMES_HOME/cache/scratch`.
- `gh` needs a TTY for interactive login; drive it as a background PTY and use `submit` to answer
  prompts (Enter on a Windows PTY is a carriage return — `write` with `\n` will not work).
- Device codes expire (~15 min). If the user was away, start the flow again.
- Release tag lookup: `gh release view` uses the LATEST release when no tag is given.
- Don't execute freshly downloaded code blindly — read install hooks first, run in a scratch dir
  without credentials, then vendor what is needed.
