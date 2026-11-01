"""verify2.py — pisahkan punca: satu alat vs satu skill, setiap model."""
import importlib.util
import os

HOME = os.path.expanduser("~/persist")
spec = importlib.util.spec_from_file_location("tk", os.path.join(HOME, "telekey/telekey.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

CASES = [
    ("alat sahaja", "Jalankan alat terminal: hostname. Sebut output mentah sahaja."),
    ("skill sahaja", "Buka skill 'smart-contract-audit' dengan skill_view dan sebut tajuk seksyen pertama."),
]
MODELS = ["mistral/ministral-8b-latest", "mistral/mistral-large-4"]

for model in MODELS:
    od = os.environ.get("TELEKEY_AGENT_PLAN")
    os.environ["TELEKEY_AGENT_PLAN"] = f"{model}|9router"
    m._router_alive = lambda: False
    print(f"\n=== {model} ===")
    for label, prompt in CASES:
        out, err, note = m._agent_core(m.BM_AGENT_PREFIX + prompt, "hard", timeout=240)
        txt = (out or err or "").replace("\n", " ")[:100]
        print(f"  {label:12} -> {txt}")
    if od:
        os.environ["TELEKEY_AGENT_PLAN"] = od
