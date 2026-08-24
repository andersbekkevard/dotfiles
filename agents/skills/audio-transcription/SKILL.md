---
name: audio-transcription
description: Transcribe speech in a local audio or video file through Groq. Use when a media file needs a fast cloud transcript.
---

# Audio transcription

Use Groq rather than local Whisper. `GROQ_API_KEY` lives in the
git-crypt-managed `~/.secrets`, stowed from `shell/.secrets` in the dotfiles
repository. Source that file when the variable is absent; never print the key.

Run the helper from this skill's directory:

```sh
SKILL_DIR="<directory containing SKILL.md>"
[[ -n "${GROQ_API_KEY:-}" ]] || source "$HOME/.secrets"

uv run "$SKILL_DIR/scripts/transcribe_groq.py" /absolute/path/audio.m4a \
  --output /absolute/path/transcript.json \
  [--language no] > /absolute/path/transcript.txt
```

Omit `--language` when it is uncertain. The JSON preserves Groq's segment
metadata; the text file is the transcript. The transcription is complete when
both files are nonempty and the text contains the expected speech.
