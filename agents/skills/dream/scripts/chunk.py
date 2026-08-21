#!/usr/bin/env python3
"""Split a cleaned transcript into page-files small enough to Read in full.

A single Read call returns at most ~2000 lines, so any transcript longer than
the chunk budget must be paged or a scanner silently reads only the head. This
splits the body (everything after the 4-line header) into overlapping chunks of
at most CHUNK_LINES lines and writes them as `<base>.partNN.txt`, each carrying
the session header plus a `part k/n` marker. Chunks overlap by OVERLAP lines so a
correction near a boundary keeps its lead-up.

Usage: chunk.py <cleaned_transcript.txt> <chunk_lines> [overlap]
Prints (newline-separated) the paths a scanner should read for this session:
the original path if it fits, else the part files. Idempotent.
"""
import os
import sys

src = sys.argv[1]
chunk_lines = int(sys.argv[2])
overlap = int(sys.argv[3]) if len(sys.argv) > 3 else 40

with open(src, encoding="utf-8", errors="replace") as f:
    lines = f.read().splitlines()

header, body = lines[:4], lines[4:]

if len(body) <= chunk_lines:
    print(src)
    sys.exit(0)

base, ext = os.path.splitext(src)
step = max(1, chunk_lines - overlap)
chunks = [body[i:i + chunk_lines] for i in range(0, len(body), step)]
# drop a trailing chunk fully contained in the previous one (overlap artifact)
if len(chunks) >= 2 and len(chunks[-1]) <= overlap:
    chunks.pop()

n = len(chunks)
paths = []
for k, ch in enumerate(chunks, 1):
    p = f"{base}.part{k:02d}{ext}"
    with open(p, "w", encoding="utf-8") as f:
        f.write(header[0] + "\n")
        f.write(header[1] + "\n")
        f.write(f"=== part: {k}/{n} (this session may continue in other shards; "
                f"emit what you find, the reducer reunites by session_id) ===\n\n")
        f.write("\n".join(ch) + "\n")
    paths.append(p)

print("\n".join(paths))
