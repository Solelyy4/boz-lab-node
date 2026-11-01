"""verify-pc.py — laluan bot di PC: tiga model Mistral, skill + alat."""
import importlib.util
import json
import os
import re

BASE = "C:/Users/zahin/projects/telekey-bot"
spec = importlib.util.spec_from_file_location("tk", os.path.join(BASE, "telekey.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

MODELS = ["mistral/codestral-latest", "mistral/ministral-8b-latest", "mistral/mistral-large-4"]
PROMPT = ("Buka skill 'godmode' dengan skill_view dan sebut nama teknik pertama di dalamnya. "
          "Kemudian jalankan alat terminal: hostname. Beri kedua-dua hasil.")

cfg = m.load_config()
ups = m.Upstreams(cfg)
st, obj = ups.race({"messages": [{"role": "user", "content": "Satu ayat: apa itu flash-loan?"}]}, tier="chat")
print(f"CHAT status={st} model={obj.get('model') if st == 200 else obj}")
print(f"     {(obj['choices'][0]['message']['content'][:70] if st == 200 else '')}")

hasil = {}
for model in MODELS:
    os.environ["TELEKEY_AGENT_PLAN"] = f"{model}|9router"
    m._router_alive = lambda: False
    out, err, note = m._agent_core(m.BM_AGENT_PREFIX + PROMPT, "hard", timeout=300)
    out = out or ""
    ok_skill = "godmode" in out.lower() or "verb downgrade" in out.lower()
    ok_tool = "zahin" in out.lower() or "DESKTOP" in out.upper()
    hasil[model] = ok_skill and ok_tool
    print(f"{model:32} skill={'YA' if ok_skill else 'TIDAK':5} alat={'YA' if ok_tool else 'TIDAK':5} | {out[:90]}".replace("\n", " "))
print("RINGKASAN:", json.dumps(hasil))
