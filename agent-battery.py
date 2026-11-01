#!/usr/bin/env python3
"""agent-battery.py — uji model 9router melalui laluan SEBENAR bot.

Setiap tugasan disemak dari kesan fizikal (fail di disk), bukan dari kata-kata
model. Model yang hanya memberi "langkah-langkah" akan gagal ujian ini.

    python agent-battery.py                 # semua model, semua tugasan
    python agent-battery.py codestral       # satu model sahaja
"""
from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import sys
import time

KIT = pathlib.Path(r"C:/Users/zahin/Downloads/tunnel-kit")
WORK = KIT / "battery"
TK = pathlib.Path(r"C:/Users/zahin/projects/telekey-bot/telekey.py")

MODELS = {
    "codestral": "mistral/codestral-latest",
    "ministral": "mistral/ministral-8b-latest",
    "large4": "mistral/mistral-large-4",
}


def load_telekey():
    os.environ.setdefault("HERMES_HOME", r"C:\Users\zahin\AppData\Local\hermes")
    spec = importlib.util.spec_from_file_location("tk", str(TK))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def tasks(tag: str) -> list[dict]:
    """Tiga saiz tugasan. `check` disahkan dari disk, bukan dari jawapan model."""
    f_med = WORK / f"medium_{tag}.txt"
    f_heavy = WORK / f"heavy_{tag}.txt"
    for f in (f_med, f_heavy):
        f.unlink(missing_ok=True)
    return [
        {
            "id": "senang",
            "prompt": "Kira 47 kali 89. Balas nombor itu sahaja, tiada ayat lain.",
            "check": lambda out: "4183" in out,
            "expect": "4183",
        },
        {
            "id": "sederhana",
            "prompt": (f"Tulis fail {f_med.as_posix()} dengan kandungan tepat BARIS-{tag}. "
                       "Kemudian baca semula fail itu dan sebut isinya. Laksanakan sekarang."),
            "check": lambda out: f_med.exists() and f"BARIS-{tag}" in f_med.read_text(errors="ignore"),
            "expect": f"fail {f_med.name} mengandungi BARIS-{tag}",
        },
        {
            "id": "berat",
            "prompt": (f"Kira berapa banyak fail .py dalam folder {(KIT / 'telekey').as_posix()} "
                       "(lapisan itu sahaja, bukan subfolder). Kemudian tulis nombor itu ke fail "
                       f"{f_heavy.as_posix()} dengan format N= diikuti nilai nombor itu. "
                       "Laksanakan dengan alat, jangan teka."),
            "check": lambda out: f_heavy.exists() and f_heavy.read_text(errors="ignore").strip().startswith("N="),
            "expect": f"fail {f_heavy.name} bermula N=",
        },
    ]


def run_model(m, key: str, model: str, only=None) -> dict:
    # Paksa model tertentu: timpa rancangan dan matikan pengesanan router.
    os.environ["TELEKEY_AGENT_PLAN"] = f"{model}|9router"
    m._router_alive = lambda: False
    res = {"model": model, "tasks": {}}
    for t in tasks(key):
        if only and t["id"] != only:
            continue
        t0 = time.time()
        out, err, note = m._agent_core(m.BM_AGENT_PREFIX + t["prompt"], "hard", timeout=300)
        secs = round(time.time() - t0, 1)
        passed = bool(out) and t["check"](out)
        res["tasks"][t["id"]] = {
            "lulus": passed, "saat": secs,
            "jawapan": (out or "")[:160].replace("\n", " "),
            "ralat": err,
        }
        print(f"  {t['id']:9} {'LULUS' if passed else 'GAGAL':5} {secs:5.1f}s  {(out or err or '')[:90]}")
    return res


def main() -> int:
    WORK.mkdir(parents=True, exist_ok=True)
    only_model = sys.argv[1] if len(sys.argv) > 1 else None
    only_task = sys.argv[2] if len(sys.argv) > 2 else None
    m = load_telekey()
    report = {}
    for key, model in MODELS.items():
        if only_model and only_model != key:
            continue
        print(f"\n=== {key} ({model}) ===")
        report[key] = run_model(m, key, model, only_task)
    total = sum(1 for v in report.values() for t in v["tasks"].values() if t["lulus"])
    n = sum(len(v["tasks"]) for v in report.values())
    print(f"\nJUMLAH LULUS: {total}/{n}")
    (WORK / "last-report.json").write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"laporan: {WORK / 'last-report.json'}")
    return 0 if total == n else 1


if __name__ == "__main__":
    sys.exit(main())
