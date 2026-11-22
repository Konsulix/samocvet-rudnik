#!/bin/sh
# Kelp that grips a stone in the plesiosaur's hunt (BoardModel LOCK 2 drawn as kelp there), drawn by ChatGPT (Codex CLI)
# in the look of the board. Usage: sh gen.sh <codex.exe> <out png>   (outside the sandbox: chatgpt.com)
C="$1"; OUT="$2"
P="\$imagegen Create ONE new PNG image (1536x1024) and save it. Do not edit any other files, do not run anything else.
The attached image is a screenshot of a mobile match-3 mining game: hand-painted game art, gems and stone blocks on
dark slate cells, soft light from the top-left, painterly grain, no black outlines.
Draw FOUR board overlays in EXACTLY the style of its pieces (same painterly rendering, same light), in one row of
four, well separated, nothing touching. Each is a TANGLE OF SEA KELP that wraps round one square board cell, seen
from straight above, sized to fill about 95% of a square: three to five thick wet olive-green and brown-green kelp
straps with wavy frilled edges and a few round air bladders, crossing the square diagonally and along its edges like
ropes tied round a parcel, with a knot where they cross, small barnacles on them, a wet highlight along each strap.
Between the straps there are LARGE OPEN GAPS (at least half of the square stays open) so that a gem lying under the
kelp would show through: the gaps are plain background. Each of the four has a different pattern of straps.
Flat plain solid magenta #FF00FF background everywhere, also in the gaps between the straps, no shadows on the
background, no gem, no tile, no text, no labels, no grid lines.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$(dirname "$0")/../forge_kit/ref_board.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
