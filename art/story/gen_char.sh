#!/bin/sh
# A new story character in the faceted style (ChatGPT image generation via Codex CLI).
# Usage: sh gen_char.sh <codex.exe> <feature ref> <out png> "<character>" <style ref> [style ref...]
# The feature ref is a picture something on the character is taken from (e.g. a boss's scales), not a style.
C="$1"; FEAT="$2"; OUT="$3"; WHAT="$4"; shift 4
IMGS=""; for s in "$@"; do IMGS="$IMGS -i $s"; done
P="\$imagegen GENERATE a new image and save it as ONE PNG file. Do not edit any other files, do not run anything else.
Several images are attached. The LAST one is ONLY a material reference - take from it the look of the thing named in the character description (its shapes, colours, materials), NOT its drawing style. ALL the other images are style references (characters from the same game): copy their drawing style exactly, the old miner with the pick is the closest match.
The style: a hand-painted angular vector illustration of FEW, LARGE, irregular flat shards of colour of very different sizes (long slivers, broad planes, jagged hooks), cut freely like paper - NOT a uniform triangle mesh, NOT a low-poly 3D model. Each shard is ONE flat colour - no texture, no gradient. Hair and fur are a few big chunky clumps with a jagged outline. Muted, slightly desaturated palette, deep dark shadow shapes, a few pale highlight shards along edges, jagged sharp slivers sticking out of the silhouette. No outlines. Light from the upper left. Graphic, a little cartoonish with exaggerated proportions - NOT a realistic portrait.
Character: $WHAT
Frame: PORTRAIT 2:3, 1024x1536. Single character, three-quarter length (head to mid-thigh), body three-quarter view turned RIGHT, head in the upper third, cut off by the bottom edge, nothing touches the top edge. Solid flat magenta #FF00FF background, no shadow on the background. No text, no UI, no frame, no watermark.
When done, print the absolute path of the saved image."
if [ "$FEAT" = "-" ]; then
  P=$(printf '%s' "$P" | sed 's/^Several images are attached. The LAST one is ONLY a material reference.*NOT its drawing style\. ALL the other images/All attached images/')
else IMGS="$IMGS -i $FEAT"; fi
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only $IMGS - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
