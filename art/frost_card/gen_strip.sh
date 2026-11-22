#!/bin/sh
# A strip of frost growing in from an edge, for CardFrost: ice ferns rooted on the BOTTOM edge, reaching up; white on black.
#   sh gen_strip.sh <out png>
C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
D="$(cd "$(dirname "$0")" && pwd -W)"
P="\$imagegen Create ONE new image and save it as ONE PNG file, landscape 1536x1024. Do not edit any other files, do not run anything else.
A close-up photograph of FROST growing on a window pane from its BOTTOM EDGE upward, as frost creeps in from a window
frame: along the very bottom a dense band of white rime and ice crystals, and out of it feathery FERN-LIKE ice fronds
(dendrites, 'Jack Frost') ROOTED ON THE BOTTOM EDGE and growing UPWARD, branching as they go, their tips pointing up
and slightly sideways; fronds of different lengths — most reach a third to a half of the height, a few longer ones
reach about two thirds; between them shorter tufts. The top quarter of the image is empty pure black. Pure WHITE ice on
a pure BLACK background (the glass is black), evenly lit, sharp, high detail, no blur, no vignette, no text.
The style of the frost is exactly that of the attached image (its fronds, its fine side branches).
The strip is SEAMLESSLY TILEABLE left to right (its left edge continues into its right edge).
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/frost_a.png" - 2>&1 | tee "$1.log" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
