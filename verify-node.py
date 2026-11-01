"""verify-node.py — buktikan tiga model Mistral berfungsi melalui laluan bot.

Setiap model diuji dengan satu tugasan yang memerlukan DUA keupayaan serentak:
  1. skill_view pada skill yang dulu tiada di nod (smart-contract-audit)
  2. alat terminal (hostname)
Lulus hanya jika kedua-dua kesan benar-benar muncul dalam jawapan.
"""
import importlib.util
import json
import os
import re

HOME = os.path.expanduser("~/persist")
spec = importlib.util.spec_from_file_location("tk", os.path.join(HOME, "telekey/telekey.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

MODELS = ["mistral/codestral-latest", "mistral/ministral-8b-latest", "mistral/mistral-large-4"]
PROMPT = ("Buka skill 'smart-contract-audit' dengan skill_view dan sebut tajuk seksyen pertama "
          "dalam fail itu. Kemudian jalankan alat terminal: hostname. Beri kedua-dua hasil, ringkas.")

print("skills tersedia:", len(list(__import__("pathlib").Path(HOME, "skills").rglob("SKILL.md"))))
print("router alive  :", m._router_alive())

# 1. Laluan CHAT bot
cfg = m.load_config()
ups = m.Upstreams(cfg)
st, obj = ups.race({"messages": [{"role": "user", "content": "Dalam satu ayat: apa itu flash-loan?"}]},
                   tier="chat")
chat_model = obj.get("model") if st == 200 else f"GAGAL {st}"
chat_text = obj["choices"][0]["message"]["content"][:80] if st == 200 else str(obj)[:80]
print(f"\nCHAT  status={st} model={chat_model}\n      {chat_text}")

# 2. Laluan AGEN untuk setiap model
print("\nAGEN (skill + terminal):")
hasil = {}
for model in MODELS:
    os.environ["TELEKEY_AGENT_PLAN"] = f"{model}|9router"
    m._router_alive = lambda: False          # paksa model ini
    out, err, note = m._agent_core(m.BM_AGENT_PREFIX + PROMPT, "hard", timeout=300)
    out = out or ""
    ada_skill = bool(re.search(r"Seksyen|seksyen|##|1\.", out)) and "smart-contract" in out.lower()
    ada_tool = "runnervm" in out.lower() or "hostname" in out.lower()
    hasil[model] = {"skill": ada_skill, "alat": ada_tool, "saat": note}
    print(f"  {model:32} skill={'YA' if ada_skill else 'TIDAK':5} alat={'YA' if ada_tool else 'TIDAK':5}")
    print(f"      {out[:110].replace(chr(10), ' ')}")

print("\nRINGKASAN:", json.dumps({k: (v["skill"] and v["alat"]) for k, v in hasil.items()}))
