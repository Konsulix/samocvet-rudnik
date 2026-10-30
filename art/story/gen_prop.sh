#!/bin/sh
# A story PROP (an object shown in a portrait scene) in the faceted style (ChatGPT image generation via Codex CLI).
# Usage: sh gen_prop.sh <out png> "<object>" <style ref> [style ref...]
C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1); OUT="$1"; WHAT="$2"; shift 2
IMGS=""; for s in "$@"; do IMGS="$IMGS -i $s"; done
P="\$imagegen GENERATE a new image and save it as ONE PNG file. Do not edit any other files, do not run anything else.
All attached images are style references (characters from the same game): copy their drawing style exactly.
The style: a hand-painted angular vector illustration of FEW, LARGE, irregular flat shards of colour of very different sizes (long slivers, broad planes, jagged hooks), cut freely like paper - NOT a uniform triangle mesh, NOT a low-poly 3D model. Each shard is ONE flat colour - no texture, no gradient. Muted, slightly desaturated palette, deep dark shadow shapes, a few pale highlight shards along edges, jagged sharp slivers on the silhouette. No outlines. Light from the upper left.
Draw ONE OBJECT, no people, no hands: $WHAT
Frame: square 1024x1024, the object large in the middle, nothing touching the edges. Solid flat magenta #FF00FF background, no shadow on the background. No text, no letters, no UI, no frame, no watermark.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only $IMGS - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
