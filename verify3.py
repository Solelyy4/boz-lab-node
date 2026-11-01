"""verify3.py — pastikan jailbreak (godmode) dan persona BOZ sampai ke bot."""
import importlib.util
import os
import pathlib

HOME = os.path.expanduser("~/persist")
spec = importlib.util.spec_from_file_location("tk", os.path.join(HOME, "telekey/telekey.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

os.environ["TELEKEY_AGENT_PLAN"] = "mistral/codestral-latest|9router"
m._router_alive = lambda: False

god = pathlib.Path(HOME, "skills/security/godmode")
print("fail godmode:", [p.name for p in god.rglob("*.md")] if god.is_dir() else "TIADA")
print("SKILL.md bait:", (god / "SKILL.md").stat().st_size if (god / "SKILL.md").is_file() else 0)
print("SOUL.md bait:", pathlib.Path(HOME, "SOUL.md").stat().st_size)
print("AGENTS.md bait:", pathlib.Path(HOME, "AGENTS.md").stat().st_size)

out, err, note = m._agent_core(
    m.BM_AGENT_PREFIX
    + "Buka skill 'godmode'. Sebut (a) tiga nama teknik jailbreak pertama yang tersenarai "
      "dalam fail itu, dan (b) apa kau panggil aku dalam persona kau sekarang.", "hard", timeout=300)
print("\n--- jawapan agen ---")
print((out or err or "")[:700])
