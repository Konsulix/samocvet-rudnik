#!/bin/sh
# Story portrait of a narrator in the faceted style (ChatGPT image generation via Codex CLI).
# Usage: sh gen_bust.sh <codex.exe> <character ref> <out png> "<character>" <style ref> [style ref...]
C="$1"; WHO="$2"; OUT="$3"; WHAT="$4"; shift 4
IMGS=""; for s in "$@"; do IMGS="$IMGS -i $s"; done
P="\$imagegen GENERATE a new image and save it as ONE PNG file. Do not edit any other files, do not run anything else.
Several images are attached. The LAST one shows WHO to draw (his look, clothes, beard, hat, pipe) - redraw him, NOT in that image's style. ALL the other images are ONLY style references (two characters from the same game): copy their drawing style exactly.
The style: a hand-painted angular vector illustration of FEW, LARGE, irregular flat shards of colour of very different sizes (long slivers, broad planes, jagged hooks), cut freely like paper - NOT a uniform triangle mesh, NOT a low-poly 3D model, NOT a triangulation filter. Each shard is ONE perfectly flat colour - no texture, no brush grain, no gradient. Hair, beard and fur are a FEW big chunky clumps with a jagged outline, NOT many spiky strands. Muted, slightly desaturated palette like the references: pale greyish skin with a few warm shards, dusty clothes, deep cool near-black shadow shapes, a few pale chalky highlight shards along edges. No outlines. Light from the upper left. Graphic, simplified, a little cartoonish with exaggerated proportions (long face, big nose, gangly limbs, oversized hat) - NOT a realistic detailed portrait, no fine wrinkle lines. Natural relaxed pose with attitude, like the references.
IMPORTANT, the four things that make this style:
1) Form is built by FLAT DARK SHADOW SHAPES, not by lighting: no smooth 3D shading, no rendered volume. Each body part has one or two big flat near-black/dark shadow patches (a sleeve, a trouser leg, the side of the apron) next to flat light patches - like a paper cut-out or a woodcut, as in the references.
2) The fur hat is NOT a lumpy low-poly mesh: draw it like the girls' hair in the references - a few big ragged flat patches, dark and mid tone, with a jagged torn outline.
3) Many 'random' sharp slivers: long thin sharp splinters and little corners that stick OUT of the silhouette (apron hem, sleeve cuffs, beard, hat fur, shirt collar), so the outline is jagged and lively, never smooth.
4) The face is drawn with only a few flat patches like the references: one shadow shape for the eye socket, one for the cheek, one for under the nose; eyes and mouth are tiny dark marks. Not a realistic face.
Character: $WHAT
Frame: PORTRAIT 2:3, 1024x1536. Single character, three-quarter length (head to mid-thigh), body three-quarter view turned LEFT, head in the upper third, cut off by the bottom edge, nothing touches the top edge. Solid flat magenta #FF00FF background, no shadow on the background. No text, no UI, no frame, no watermark.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only $IMGS -i "$WHO" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
