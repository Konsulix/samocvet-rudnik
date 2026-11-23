#!/bin/sh
# A "secret" card back and the bits stuck on it, drawn by GPT.
#   sh gen3.sh <out png> a|b|c|d|parts
D="$(cd "$(dirname "$0")" && pwd -W)"; C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
case "$2" in
a) V="the back of an old collector's catalogue card for a mineral specimen: aged kraft cardboard, worn corners, two faded round ink stamps, a fine pencil sketch of a crystal cluster with measuring lines, small handwritten SCRIBBLE notes (only illegible squiggles, not real letters), a red wax seal, a faint coffee ring";;
b) V="a miner's secret map drawn in ink on old yellowed paper glued to the card: tunnels and shafts going down, a dashed path to a cross marking a hidden crystal cave, a compass rose, burnt and torn edges, illegible squiggle notes (not real letters)";;
c) V="the inside of a hidden compartment: dark worn walnut wood with brass corner plates and tiny screws, a faded velvet-lined recess in the upper part holding a pressed fern, an old brass key and a few loose small crystals, scratches and age";;
d) V="an old black chalkboard slate in a thin wooden frame: chalk sketches of crystal shapes, mine cross-sections and arrows, smudges and half-wiped chalk, illegible chalk squiggles (not real letters)";;
parts) V="";;
esac
if [ "$2" = parts ]; then
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1536x1024. Do not edit any other files, do not run anything else.
A SPRITE SHEET of separate pieces for a mobile game about a mine full of crystals (hand-painted, crafted, realistic materials, like the attached interface), each piece seen straight from the front, flat, no perspective:
(row 1) SIX different pieces of tape, each a short strip about 230x70 px with torn ragged ends: plain beige masking tape; old yellowed masking tape; brown paper packing tape; pale washi tape with a faint gold crystal pattern; dark grey cloth tape; translucent old sticky tape gone amber;
(row 2) a long horizontal GLASS VIAL / tube about 900x110 px with brass end caps, EMPTY and clear (it will be filled with molten gold by the game), a little reflection on the glass; and next to it a small brass label plate about 220x70 px, blank.
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around the pieces, no shadow. At least 40 px of magenta between pieces. No text, no letters.
When done, print the absolute path of the saved image."
else
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1024x1536. Do not edit any other files, do not run anything else.
It is the SECRET BACK of a collectible card in a mobile match-3 game about a Ural mine full of crystals (the attached images show the FRONT of such a card and its interface: dark slate, iron, old brass). The back must feel hidden, private, intriguing — something the player discovers by turning the card over. Hand-painted, rich, crafted, realistic materials, not cartoonish, not flat vector.
DESIGN: $V.
The game will stick three buttons and a gauge onto the LOWER HALF with tape, so the lower half must stay fairly calm (texture, a few faint marks only); the interesting things mostly in the upper half.
Seen straight from the front, no perspective. The card fills the image almost to the edges (about 30 px margin), portrait, rounded corners (radius about 6% of the width). Outside the card: one solid flat pure magenta #FF00FF, no shadow. NO real text, NO real letters, NO numbers.
When done, print the absolute path of the saved image."
fi
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/../card_levitate_text.png" -i "$D/../../godot/assets/ui/kit/card.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
