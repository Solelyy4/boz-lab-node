# Driving a logged-in web app in the user's own browser

Use when the work must happen inside a web app the user is already signed into
(their Chrome/Firefox profile), where `browser_*` cannot follow: no CDP endpoint,
no shared cookie jar, and a fresh headless session is a logged-out stranger.

## 0. Decide the route first

```bash
netstat -ano | grep LISTENING | grep -E ':(9222|9223|9333)\b'   # CDP available?
```

- A CDP port is listening → prefer `browser_exec` against the live page; DOM reads beat
  pixels.
- No CDP port → drive the page with `computer_use`. Do not launch another browser and
  hope the login follows; it will not.

Capture Chrome scoped to its app and pid so you get the page tree, not the desktop:

```
computer_use(action="list_windows")
computer_use(action="capture", app="chrome.exe", pid=<pid>, window_id=<wid>, mode="som")
```

## 1. Put text in the box without fighting newlines

Typing multi-line prompts with `type` is fragile: a `\n` may be delivered as a submit.
Paste instead.

```bash
cat prompt.txt | clip.exe          # Windows/MSYS: fast, no round-trip
cat prompt.txt | pbcopy            # macOS
```

Then focus the field and paste:

```
computer_use(action="click", coordinate=[<x/scale>, <y/scale>], delivery_mode="foreground")
computer_use(action="key",   keys="ctrl+v", delivery_mode="foreground")
```

Pitfalls:
- A clipboard *read-back* for verification can block for minutes; skip it and verify on
  screen instead. `cat file | clip.exe` returns immediately.
- `click` may report `ok:true` in the background yet leave the field unfocused, so the
  paste lands nowhere. Send the focus click with `delivery_mode="foreground"` too.
- Verify the draft is really in the field with a fresh `vision` capture before submitting.

## 2. Submit — Enter is not universal

Many chat UIs ignore a synthetic `return` and only submit on the arrow button. If Enter
changes nothing (compare captures), click the button.

Icon-only buttons usually have no usable AX node, and the composer layer is often missing
from the tree entirely. Locate the control from pixels:

```python
from PIL import Image
im = Image.open(shot).convert("RGB"); px = im.load()
pts = [(x, y) for y in range(h0, im.size[1]) for x in range(w0, im.size[0])
       if max(px[x, y]) - min(px[x, y]) > 60 and max(px[x, y]) > 90]
cx, cy = sum(p[0] for p in pts) // len(pts), sum(p[1] for p in pts) // len(pts)
```

That centroid is the accent-coloured send control in **screenshot** space — feed it to
`coordinate` as-is (no `bounds_scale` division; the driver scales it). Restrict the scan
window to the composer band, or a highlighted message bubble wins the cluster.

## 3. Read the result

The element tree is unreliable for "what did the app just say": scrolled content reports
negative or stale bounds and the newest nodes fall outside the dumped range. Read the
screenshot instead — if the main model has no vision, `vision_analyze` on the saved
`computer_use_*.png` returns a text transcription. Ask for exactly what you need (newest
message, whether a typing indicator is present, whether the composer is empty).

## 4. Politeness rules when the human is at the keyboard

- Foreground delivery briefly steals the window. Batch a step into one foreground
  sequence rather than flickering per call.
- If the user switches tabs or starts chatting elsewhere mid-run, stop escalating. Report
  what is confirmed and what is pending; resume when they are away — do not keep pulling
  focus back.
- Never type credentials, and never create accounts on their behalf; sign-in and 2FA are
  the user's job.
