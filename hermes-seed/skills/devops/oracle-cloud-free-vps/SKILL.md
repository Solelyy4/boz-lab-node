---
name: oracle-cloud-free-vps
description: "Use when provisioning an Oracle Cloud free VPS."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [oracle, oci, vps, cloud, provisioning, cloud-init, always-free]
---

# ORACLE CLOUD ALWAYS FREE — VPS

Target: `VM.Standard.A1.Flex` ARM, 4 OCPU / 24 GB, 200 GB block, 10 TB egress, free forever, one
account per person. Singapore (`ap-singapore-1`) has the loosest ARM capacity for Malaysian users.

## When to Use

- "setupkan VPS Oracle", "free VPS", "Always Free ARM", "patut daftar region mana".
- A box is needed for 24/7 work (bot, cron, relay, agent node) and the free ARM tier is the target.
- An existing OCI tenancy needs a new instance, VCN, or security-list rule from the API.
- Skip when the task is a paid host (Hetzner/DO/Vultr) — the OCI SDK steps below do not apply.

## Prep that needs nobody's account (do this first)

1. SSH keypair: `ssh-keygen -t ed25519 -f keys/oci_ed25519 -N "" -C "boz-oracle-vps"`.
2. OCI API key — generate locally, the **public** half is what the console wants:
   `openssl genrsa -out ~/.oci/oci_api_key.pem 2048` then
   `openssl rsa -in ~/.oci/oci_api_key.pem -pubout -out ~/.oci/oci_api_key_public.pem`.
3. SDK: **install only `oci`, never `oci-cli`**, and force wheels:
   `python -m venv .venv && .venv/Scripts/python -m pip install --only-binary=:all: oci`.
   `oci-cli` drags `PyYAML`, which has no wheel for a brand-new Python and fails at build time — the
   SDK alone is what provisioning needs.
4. Windows/MSYS: build the venv with a **native interpreter path**. `uv venv --python /c/Users/...`
   fails with "No interpreter found at path"; `python -m venv .venv` works.
5. Validate `cloud-init.yaml` before it ever boots: `python -c "import yaml; yaml.safe_load(open('cloud-init.yaml',encoding='utf-8'))"`.
   A YAML error there surfaces only as a server that boots dead.

## The human-only gates (stop here, hand back, do not improvise)

- **Card verification + SMS OTP.** Never type a card number, CVC, or OTP into a form, and never
  accept one in chat. Everything after account creation is automatable; nothing before it is.
- **Signup form quirks** that read as "the site is broken": the phone field takes **digits only** —
  a formatted `+60 11-5693-8166` leaves **Continue greyed out**; the human-check widget does not
  render in a headless browser (empty `[name="cf-turnstile-response"]`, no iframe), so account
  creation is one human pass; home region is fixed at signup and cannot be changed afterwards.
- **One free account per person** — never suggest multi-account workarounds.

## Provision (after the account exists)

```bash
.venv/Scripts/python provision-oracle-arm.py --ssh-key keys/oci_ed25519.pub
```

`scripts/provision-oracle-arm.py` creates VCN `10.0.0.0/16` → public subnet → IGW → route table →
security list (22, 80, 443, 8080, 8877, 20128) → newest Ubuntu 24.04 ARM image → launches the
instance with `ssh_authorized_keys` + `user_data` from `cloud-init.yaml` → prints the public IP and
SSH line. It retries across every Availability Domain because
**"Out of host capacity" is the normal free-tier answer**, not a config error; give it an hour and
rerun rather than rebuilding the tenancy.

`templates/cloud-init.yaml` is the first-boot setup: 4 GB swap + sysctl, password auth and root
login off, UFW 22/80/443, fail2ban, Docker + compose, python/git/tmux/rg/sqlite, a `boz-verify`
status script.

**Status: the prep, keys, YAML validation and the `~/.oci/config` guard are verified on this host.
The launch path itself is written and syntax-checked but has not yet run against a live tenancy —
treat the first real run as the test, and read the ServiceError text instead of assuming success.**

## Verify after the account exists

```bash
.venv/Scripts/python -c "import oci,pathlib;c=oci.config.from_file(str(pathlib.Path.home()/'.oci/config'));print(c['region'], c['tenancy'][:18])"
ssh -i keys/oci_ed25519 ubuntu@<IP> boz-verify
```

`boz-verify` prints host/kernel/arch, cores/RAM/disk, OS, timezone, UFW line, Docker version,
Python version and public IP — that block is the evidence that the node is real.

## Pitfalls

- The console's **configuration file preview** is the only reliable source of `user`, `tenancy`,
fingerprint and region; the fingerprint can also be computed with
`openssl rsa -pubin -in <pub> -outform DER | openssl md5 -c`.
- Set the instance timezone deliberately in cloud-init (this stack standardises on `Asia/Jakarta`)
— servers come up UTC and every log timestamp is wrong until it is set.
- Always Free instances bill nothing while stopped; stop the instance to preserve quota instead of
terminating it, and never recreate the tenancy to "fix" capacity.
