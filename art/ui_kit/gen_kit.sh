#!/bin/sh
# A sheet of separate UI kit pieces on flat magenta, in the chosen style (ref/style_*.png), for cutting into 9-slices.
# Usage: sh gen_kit.sh <codex.exe> <out png> frames|icons
C="$1"; OUT="$2"; WHAT="$3"
D="$(cd "$(dirname "$0")" && pwd -W)"
COMMON="\$imagegen Create ONE new image and save it as ONE PNG file, 1536x1024. Do not edit any other files, do not run anything else.
It is a SPRITE SHEET of separate game-UI pieces for a mobile game about a 19th-century Ural gem mine, to be cut out and used in the game engine.
STYLE: exactly the style of the attached references style_bar.png, style_window.png and style_home.png: dark charcoal slate panels with a fine stone texture, frames of dark iron with warm aged-brass edges, round brass rivets / bolts, small brass corner plates, hand-drawn with crisp dark ink outlines, warm lantern light from the top-left; slightly dark and moody.
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around the pieces, no gradient, no shadow on it, no texture. Every piece is fully separate, with at least 40 px of magenta between pieces. No text anywhere, no letters, no numbers. Pieces seen straight from the front, not in perspective, no drop shadows outside the pieces.
"
if [ "$WHAT" = frames ]; then
P="$COMMON
These pieces will be STRETCHED as 9-slice frames, so: ornaments (rivets, corner plates) ONLY in the corners; the straight edges between the corners must be plain and uniform along their whole length; the inside must be an even slate fill without a central picture.
Draw these pieces in a 4 columns x 3 rows grid, in this order (row by row, left to right):
Row 1: (1) a big WINDOW panel frame, square ~330 px, thick brass-and-iron frame with corner plates and 4 rivets per corner; (2) a SMALL CARD frame, square ~220 px, thinner brass frame with one rivet per corner; (3) a TAB tile, square ~220 px, dark iron frame, unlit; (4) the same TAB tile SELECTED: warm glowing brass frame and a soft amber light inside.
Row 2: (5) a GREEN action button, wide ~340x120 px: deep green enamel / green stone face with a brass frame and a small rivet tab on each short end; (6) a GOLD button, ~340x120: polished warm gold-brass face with darker brass frame; (7) a DARK button, ~340x100: slate face with brass frame; (8) a TITLE PLATE, ~340x90: dark iron plate with brass rim and one rivet at each end.
Row 3: (9) a resource CAPSULE, ~300x80: long dark slate bar with brass rim, rounded ends; (10) a small square PLUS button frame ~90 px (brass, empty face, no plus sign) and next to it a small square slate button frame ~90 px; (11) a ROUND token frame ~200 px: thick brass ring with rivets, dark slate disc inside; (12) a ROUND portrait frame ~200 px: thinner dark iron ring with a brass inner rim, empty dark inside.
"
elif [ "$WHAT" = coins ]; then
P="$COMMON
These are five DIFFERENT DESIGNS of the game's COIN icon (soft currency), to choose one from. Draw them in the same hand-drawn icon style as the coin and nuggets on the attached icons_a.png (crisp dark ink outline, warm light from the top-left, rich but slightly worn metal), each about 260 px, in one row of 5, big and clear, readable at a small size. None of them may look like a real-world currency: no ruble, dollar or euro signs, no double-headed eagle, no state emblem.
(1) MINER'S TOKEN: an old brass token with crossed pickaxe and sledgehammer stamped in the middle, a milled / notched rim.
(2) LIZARD COIN: a gold coin with a small emerald-green lizard (the Mistress of the Copper Mountain from Ural tales) curled around a faceted red gemstone set in the centre.
(3) MINING EAGLE: a gold coin with a single-headed stylised eagle like an old mining-works hallmark, holding a pickaxe in one claw and a crystal in the other.
(4) GEM-SET COIN: a hexagonal gold coin with a faceted cut gem (ruby red) set in its middle, small engraved rays around it.
(5) STRUCK NUGGET: a rough uneven gold nugget with a mine mark (a little headframe over a pick) stamped flat into its face.
"
else
P="$COMMON
These are ICONS and decorations, each drawn as a self-contained object (no frame, no background tile), about 150-190 px each, arranged in a 5 columns x 4 rows grid, in this order (row by row, left to right):
Row 1: (1) MAP OF MINES: an old folded parchment map with a dotted route and a pick mark; (2) MINE / HOME: a small wooden headframe over a mine entrance; (3) COLLECTION: a cluster of blue-violet crystals; (4) EQUIPMENT: a miner's helmet with a carbide lamp and a pickaxe crossed behind it; (5) BUILD / DEVELOP: a hammer over a small wooden building frame.
Row 2: (6) PLAY: a big solid triangle play mark in warm cream with dark ink outline; (7) GOLD COIN with a stamped double-headed eagle; (8) IRON: a lump of dark grey iron ore with a few steel cube crystals; (9) GOLD: a gold nugget; (10) COPPER: a copper-orange nugget with green malachite spots.
Row 3: (11) HEART (lives), deep red, glossy; (12) GEAR (settings), brass; (13) a brass PLUS sign; (14) a brass MINUS sign; (15) a green CHECK mark.
Row 4: (16) a PADLOCK, iron; (17) a CLOSE cross X, brass; (18) a small red NOTIFICATION dot with a white exclamation mark; (19) an old miner's OIL LANTERN with a brass cap and a ring on top, glass panes and a small warm flame, a short twisted rope hanging from it; (20) a PICKAXE.
"
fi
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/ref/style_bar.png" -i "$D/ref/style_window.png" -i "$D/ref/style_home.png" $([ "$WHAT" = coins ] && echo "-i $D/icons_a.png") - 2>&1 | tee "$OUT.log" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
