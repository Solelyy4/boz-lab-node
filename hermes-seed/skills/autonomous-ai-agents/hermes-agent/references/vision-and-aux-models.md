# Vision and auxiliary models

`vision_analyze` (and browser screenshots) take one of two paths: **native** — the image is
attached to the main model — or **aux** — a separate multimodal model describes it. When the
main model cannot actually see images but is *believed* to, the image is still attached to it
and the provider rejects the call before the auxiliary model is ever consulted.

## Symptom

```
Error analyzing image: Error code: 400 - {'error': {'message': "Vision is disabled for model 'X'"}}
```

This survives setting `auxiliary.vision.provider` alone. The message names the **main** model,
which is the tell: the native path was chosen, not the aux path.

## Fix — two knobs, both required

```bash
hermes config set auxiliary.vision.provider nous      # openrouter | nous | gemini | ollama-cloud | codex | main | auto
hermes config set auxiliary.vision.model ""           # empty = provider default
hermes config set model.supports_vision false         # forces the aux path
```

`model.supports_vision` is the first override consulted by the capability lookup in
`agent/image_routing.py` (`_supports_vision_override`), ahead of every provider/catalog probe.
Setting it `false` is the supported way to say "this main model cannot take images"; do not
patch the probe order.

## It applies live

`load_config()` caches on the **file signature**, so the next tool call after `hermes config set`
sees the new values. No gateway restart is needed for vision routing — a restart is only needed
for patches to Python source, not for config.

## Verify with a payload, not with config

Generate an image whose text you know, then read it back. A config that "looks right" can still
route to a model that silently ignores pixels.

```bash
python -c "from PIL import Image,ImageDraw;i=Image.new('RGB',(520,120),'white');\
d=ImageDraw.Draw(i);d.text((18,30),'VISION SELF-TEST',fill='black');d.text((18,60),'kode: ZX-4417',fill='black');\
i.save(r'C:/path/scratch/vision_selftest.png')"
```

Then `vision_analyze` that file and require the exact strings back. If it reads them, the aux
route is genuinely working.

## Pitfalls

- Aux provider needs credentials of its own: check `auth.json` → `providers.<name>` (e.g. Nous
  Portal OAuth) before switching, and prefer a provider that is already authenticated.
- `auxiliary.*` blocks are per task (`vision`, `web_extract`, `compression`, `title_generation`, …);
  setting one does not change the others.
- Aux calls are billed/rate-limited separately from the main model, and every embedded image can
  be re-sent on later turns when the main model is multimodal — `vision.max_calls_per_image` and
  `vision.embed_target_bytes` are the cost knobs.
- "Vision is broken" is almost always this routing mismatch. Diagnose the path first; do not
  conclude the tool or the provider is unusable.
