#!/bin/sh
# The card's back, full bleed (24.11: the card back stretched to the frame showed torn edges and empty corners).
# Painted edge to edge: the game lays it inside the card's own brass frame, keeping its proportions.
#   sh gen4.sh <out png> e|f|g
D="$(cd "$(dirname "$0")" && pwd -W)"
# (the Codex app's own CLI, and a model a ChatGPT account takes: the old CLI and the config's model failed - 24.11)
#   (WindowsApps can't be listed: its path from `Get-AppxPackage OpenAI.Codex`, or CODEX=... to give it)
C="${CODEX:-/c/Program Files/WindowsApps/OpenAI.Codex_26.1120.5083.0_x64__2p2nqsd0c76g0/app/resources/codex.exe}"
[ -f "$C" ] || C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
case "$2" in
e) V="a page from a mineralogist's secret field notebook: thick aged cream paper, a careful sepia ink drawing of a crystal cluster cut in half showing its inner layers, thin measuring lines, a small compass rose, faint grid of a mine section, a few dried pressed leaves, small illegible squiggle notes (not real letters), one red wax seal";;
f) V="a sheet of old indigo cyanotype blueprint paper: white fine-line technical drawings of crystal forms (prisms, octahedra), a cross-section of a mine with shafts and galleries, construction lines and circles, a faint large star-like crystal emblem in the middle of the upper half, illegible squiggle notes (not real letters), slight paper wear and stains";;
g) V="old kraft cardboard with a fine linen texture: a large faded ink engraving of an amethyst geode in the upper half, two round faded ink stamps, a thin double-line border drawn in ink, small illegible squiggle notes (not real letters), a faint coffee ring";;
esac
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1024x1536. Do not edit any other files, do not run anything else.
It is the BACK of a collectible card in a mobile match-3 game about a Ural mine full of crystals (the attached images show the FRONT of such a card: dark slate, iron, old brass). Hand-painted, rich, realistic materials, not cartoonish, not flat vector.
DESIGN: $V.
FULL BLEED: the surface fills the WHOLE image edge to edge — no card outline, no frame, no border around the image, no rounded corners, no torn edges, no background around it. The game crops it a little at the left and right, so keep everything important within the middle 75% of the width.
The game will stick buttons, a gauge and a slate panel over the LOWER 45%, so that part must stay calm (just the surface's texture, a few faint marks); the interesting things in the upper part.
Seen straight from the front, flat, no perspective. NO real text, NO real letters, NO numbers.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec -m gpt-6-luna --skip-git-repo-check -s read-only -i "$D/../card_levitate_text.png" -i "$D/../../godot/assets/ui/kit/card.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
