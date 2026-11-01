---
name: programmatic-video
description: "Use when building videos from code with ffmpeg."
version: 1.0.0
author: BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [video, ffmpeg, python, rendering, motion-graphics]
---

# Video from code (no generative video model)

## When to Use

- "boleh buat video?" — title cards, promos, slide decks to video, data animations, narrated clips.
- Editing supplied footage: trim, concat, overlay, burn subtitles, compress, extract audio, GIF.
- Not for text-to-video model output; that needs a provider account and a video model.

## Pipeline: Python frames → ffmpeg

Render every frame (PIL / canvas / matplotlib), write raw RGB to ffmpeg's stdin, let ffmpeg encode.
Gives pixel-level control and no intermediate PNG dump.

```bash
ffmpeg -y -f rawvideo -pix_fmt rgb24 -s 1280x720 -r 24 -i - \
       -f lavfi -i "sine=frequency=330:duration=6" \
       -filter_complex "[1:a]volume=0.06,afade=t=in:st=0:d=1,afade=t=out:st=5:d=1[a]" \
       -map 0:v -map "[a]" -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
       -c:a aac -b:a 96k -movflags +faststart out.mp4
```

In Python: `Popen([...], stdin=PIPE, stdout=DEVNULL, stderr=open(log,'wb'))`, write
`img.tobytes()` per frame, `stdin.close()`, then `wait()`.

## Pitfall: stderr=PIPE deadlocks the pipe

The encoder logs progress to stderr. With `stderr=subprocess.PIPE` nobody drains it, the 64 KB
buffer fills, ffmpeg stops reading stdin, and the Python side blocks forever writing frames — the
job looks like "slow encoding" and hits the tool timeout. **Always redirect stderr to a file**, then
read that file for the failure reason.

## Verification (never eyeball)

```bash
ffprobe -v error -show_entries format=duration,size \
        -show_entries stream=codec_name,width,height,r_frame_rate,nb_frames \
        -of default=noprint_wrappers=1 out.mp4
```

Check duration, frame count, codec, and that the audio stream exists. Report those numbers, not
"video dah siap".

## Practical notes

- Native Windows binaries need `C:/...` paths — `/c/...` (MSYS) is not translated and fails with
  "No such file or directory" even when the file exists. Quote paths containing spaces.
- Audio without a music file: `-f lavfi -i "sine=frequency=…"`, or synthesise narration with TTS
  and mux it as a second input; burn captions with the `subtitles` filter.
- Vertical social formats: render 1080x1920 and keep text inside a 80 px safe margin.
- Fonts: `C:/Windows/Fonts/segoeuib.ttf` / `arialbd.ttf`; a missing font falls back to a bitmap
  default that ignores the size argument.
- Reading text out of an existing recording: `ffmpeg -ss <t> -i in.mp4 -frames:v 1 out.png`, then
  `vision_analyze` the frame — cheaper and more reliable than trying to view the video.
