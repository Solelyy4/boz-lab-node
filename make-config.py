#!/usr/bin/env python3
"""make-config.py — jana ~/persist/config.yaml untuk Hermes di nod awan.

Nod tiada 9router (ia hidup di PC), jadi provider mesti yang boleh dicapai
dari internet: tokenomix dan groq. Kunci dibaca dari persekitaran (start.sh
sudah source .env), tidak pernah ditulis ke repo.

Jalankan dengan python venv Hermes supaya `yaml` tersedia:
    ~/persist/hvenv/bin/python ~/persist/make-config.py
"""
import os
import pathlib
import sys

HOME = pathlib.Path(os.environ.get("HERMES_HOME") or (pathlib.Path.home() / "persist"))
CFG = HOME / "config.yaml"


def nine_key() -> str:
    """Kunci API 9router dari DB tempatan (dicipta oleh 9router sendiri)."""
    db = HOME / "nine" / "db" / "data.sqlite"
    if not db.exists():
        return ""
    try:
        import sqlite3
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        row = con.execute("SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1").fetchone()
        con.close()
        return (row[0] if row else "") or ""
    except Exception:
        return ""


def build() -> dict:
    providers = {}

    # 9router DI NOD: didahulukan kerana ia memberi 32 akaun Mistral dengan
    # round-robin. Tanpanya bot hanya ada satu provider awan.
    nk = nine_key()
    if nk:
        providers["9router"] = {
            "base_url": "http://127.0.0.1:20128/v1",
            "api_key": nk,
            "api_mode": "chat_completions",
            "model": "mistral/codestral-latest",
            "request_timeout_seconds": 120,
            "models": {
                "mistral/codestral-latest": {},
                "mistral/ministral-8b-latest": {},
                "mistral/mistral-large-4": {},
                "mistral-safe": {},
            },
        }

    tok = os.environ.get("TOKENOMIX_API_KEY", "").strip()
    if tok:
        providers["tokenomix"] = {
            "base_url": "https://api.tokenomixai.com/v1",
            "api_key": tok,
            "model": "deepseek-v4.1-flash",
            "api_mode": "chat_completions",
            "models": {
                "deepseek-v4.1-flash": {},
                "deepseek-v4-flash": {},
                "glm-5.2": {},
                "deepseek-v4.1-flash-1017": {},
            },
        }

    groq = os.environ.get("GROQ_API_KEY", "").strip()
    if groq:
        providers["groq"] = {
            "base_url": "https://api.groq.com/openai/v1",
            "api_key": groq,
            "model": "qwen/qwen3.8-27b",
            "models": {"qwen/qwen3.8-27b": {}},
        }

    if not providers:
        return {}

    # 9router diutamakan bila wujud (Mistral dari 32 akaun), tokenomix jadi sandaran.
    primary = "9router" if "9router" in providers else ("tokenomix" if "tokenomix" in providers else next(iter(providers)))
    return {
        "model": {"default": providers[primary]["model"], "provider": primary},
        # Bentuk PETA (bukan senarai) — hanya bentuk ini didaftarkan oleh
        # hermes 0.19; senarai menghasilkan "Unknown provider".
        "providers": providers,
        "skills": {
            "auto_load": ["tool-discipline", "elyy-ops-atlas"],
            "external_dirs": [str(HOME / "skills")],
        },
        "terminal": {"backend": "local", "timeout": 180},
    }


def main() -> int:
    try:
        import yaml
    except Exception as exc:  # pragma: no cover - hanya diagnostik
        print(f"gagal import yaml: {exc}", file=sys.stderr)
        return 1

    cfg = build()
    if not cfg:
        print("tiada kunci provider dalam persekitaran - config tidak ditulis", file=sys.stderr)
        return 1

    CFG.write_text(yaml.safe_dump(cfg, sort_keys=False), encoding="utf-8")
    CFG.chmod(0o600)
    skills = HOME / "skills"
    n = len(list(skills.rglob("SKILL.md"))) if skills.is_dir() else 0
    print(f"config ditulis: {CFG} ({CFG.stat().st_size} bait), provider={list(cfg['providers'])}, skills={n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
