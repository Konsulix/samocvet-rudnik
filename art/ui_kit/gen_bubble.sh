#!/bin/sh
# Speech bubbles for the mine's guide (GuideBubble), drawn by GPT in the mine's own style, as a sheet on magenta.
# usage: sh gen_bubble.sh <out png>
D="$(cd "$(dirname "$0")" && pwd -W)"; C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1536x1024. Do not edit any other files, do not run anything else.
It is a SPRITE SHEET of SPEECH BUBBLES for a mobile game about an old Ural gold mine. An old miner standing in the
mine scene says short lines in them (2-3 lines of text will be written on top later by the game).
STYLE: exactly the drawing style of the FIRST attached image (the mine picture): hand-painted, warm, crisp dark ink
outlines, slightly worn and hand-made, muted earthy colours. The SECOND image shows the game screen the bubble goes on
(the bubble there is a placeholder - do not copy it). The bubble must look like it belongs to the drawing, calm and
neat, light enough that dark text reads well on it, not loud, not cartoonish.
Draw SIX DIFFERENT DESIGNS in a 3 columns x 2 rows grid. For each design draw TWO separate pieces: the BUBBLE BODY
(a wide empty shape about 400x170 px) and, under it with a gap, its TAIL on its own (a small pointer about 50x45 px
pointing down, matching the body's edge and outline, made to be attached under the body).
The body will be STRETCHED as a 9-slice: any ornaments ONLY in the four corners; the straight edges between corners
plain and uniform; the inside an even, quiet fill with no picture and NO text.
Designs: (1) old parchment note with an ink outline and softly rounded corners; (2) a page torn from a miner's
notebook, faint ruled lines, slightly torn edges, a small brass pin in one corner; (3) a pale birch-bark strip;
(4) a smooth pale stone tablet with chipped corners; (5) a rounded ink-outlined cloud of warm cream paper, like a
book illustration; (6) a small worn wooden sign board, light wood, two nails in the corners.
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around the pieces, no gradient, no shadow on it. Every
piece fully separate, at least 40 px of magenta between pieces. No text, no letters anywhere. Seen straight from the
front, no perspective.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/../zone/mine1/s2_final.png" -i "$D/bubble/ref_screen.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
