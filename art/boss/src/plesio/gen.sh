#!/bin/sh
# The plesiosaur's parts for his hunt (GulpView), in ChatGPT image generation via Codex CLI, in the bosses' style.
# Usage: sh gen.sh <codex.exe> neck|head <style ref png> <out png>
C="$1"; WHAT="$2"; REF="$3"; OUT="$4"
STYLE="dark fairy-tale book illustration in pixel-art style, inspired by Inscryption; bold dark ink outlines, flat colour fills with 2-3 shade steps, coarse dithered shading, chunky readable shapes, crisp hard edges, no blur, no soft gradients; gloomy, grim and grimy, muted dirty palette (cold slate teal and grey-green hide, pale bone-yellow underside), deep near-black shadows, light from the upper left as a dim rim"
case "$WHAT" in
neck) SUBJ="ONE straight piece of the long neck of an ancient plesiosaur, seen exactly from the side, lying perfectly HORIZONTAL across the WHOLE width of the image from the left edge to the right edge and cut off flat by both edges. The SAME thickness all along (about a fifth of the image height), centred vertically, no taper, no head, no body, no bend. Wet scarred hide: the back (top) dark slate teal with a row of low bumps and mottled darker blotches, the underside (bottom) pale bone-yellow with crosswise belly folds; old scars, a few barnacles and clinging weed, evenly spread so that the piece could be repeated end to end. Nothing else in the picture.";;
head) SUBJ="The head of an ancient plesiosaur as TWO SEPARATE PARTS with a clear gap of background between them, both seen exactly from the side, snout pointing LEFT. PART 1 (upper, in the top half): the skull with the upper jaw - long flat reptile head, an amber eye with a slit pupil, a nostril, scarred slate-teal hide with barnacles, a row of long needle teeth pointing DOWN along the whole upper jaw, and a short stump of neck at the right end. PART 2 (lower, in the bottom half, directly under part 1, NOT touching it): the lower jaw alone - a long narrow jaw, pale underside, a row of long needle teeth pointing UP along it, its hinge end at the right. Both parts the same scale, each about 70% of the image width, horizontal. Nothing else in the picture.";;
esac
P="\$imagegen GENERATE a new image and save it as ONE PNG file. Do not edit any other files, do not run anything else.
The attached image is ONLY a style reference: draw a DIFFERENT subject in exactly its drawing style - $STYLE.
Subject: $SUBJ
Frame: LANDSCAPE 3:2, 1536x1024. Solid flat magenta #FF00FF background, no shadow on the background, no glow, no particles, no water. No text, no UI, no frame, no border, no watermark.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$REF" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
