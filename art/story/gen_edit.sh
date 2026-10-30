#!/bin/sh
# Edit a story portrait (ChatGPT image generation via Codex CLI), keeping the framing; style refs show the target look.
# Usage: sh gen_edit.sh <codex.exe> <src png> <out png> "<change>" <style ref> [style ref...]
C="$1"; SRC="$2"; OUT="$3"; CHANGE="$4"; shift 4
IMGS=""; for s in "$@"; do IMGS="$IMGS -i $s"; done
P="\$imagegen EDIT the LAST attached image and save the result as ONE PNG file. Do not edit any other files, do not run anything else.
The other attached images are ONLY style references (characters from the same game) - the target look.
Keep EXACTLY the same character, pose, clothes, props, position and size in the frame, the same crop, the same solid flat magenta #FF00FF background and the same 1024x1536 size. Do not move, rescale or recompose anything. Keep the jagged sharp slivers on the silhouette and the flat-shard drawing style.
Change ONLY this: $CHANGE
No text, no UI, no frame. When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only $IMGS -i "$SRC" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
