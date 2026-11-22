#!/bin/sh
# The mark of the plesiosaur's bite on the board: his open maw seen straight on, a ring of teeth. Usage: sh gen3.sh <codex.exe> <ref png> <out png>
C="$1"; REF="$2"; OUT="$3"
P="\$imagegen GENERATE a new image and save it as ONE PNG file. Do not edit any other files, do not run anything else.
The attached image shows the creature and the drawing style to keep: dark fairy-tale book illustration in pixel-art style, inspired by Inscryption; bold dark ink outlines, flat fills with 3-4 shade steps, coarse dithered shading, crisp hard edges, no blur.
Subject: the creature's wide-open MAW seen exactly from the FRONT, as a SQUARE-ish RING: only the gums and the teeth - a thick ring of dark red gum with slate-teal lip at its outer rim, and long pale needle teeth all round it pointing INWARDS to the centre (about seven teeth on each of the four sides, the corner ones longest). The MIDDLE of the ring is EMPTY: fill it with the same flat magenta as the background, a big square hole taking about 55% of the ring's width. No tongue, no throat, no eyes, no head - just the ring of jaws and teeth, symmetrical, centred, filling about 80% of the picture.
Frame: SQUARE 1:1, 1024x1024. Solid flat magenta #FF00FF background and hole, no shadow, no glow. No text, no UI, no border, no watermark.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$REF" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
