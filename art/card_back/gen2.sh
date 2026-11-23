#!/bin/sh
# Simpler card backs: room for buttons and a gauge in the lower part.  sh gen2.sh <out png> 1..5
D="$(cd "$(dirname "$0")" && pwd -W)"; C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
case "$2" in
1) V="DARK. Plain dark blue-grey slate, evenly textured, like the attached card's slate; a thin engraved brass line border with a small rivet in each corner; a SMALL brass emblem (a geode broken in two and mended with one gold seam) in the upper third.";;
2) V="DARK. Plain deep black lacquer with a soft warm sheen; a thin gold leaf line border; a SMALL gold kintsugi emblem in the upper third: a round lacquer disc cracked and mended with three gold seams.";;
3) V="DARK. Plain midnight-blue enamel, very faint fine guilloche; a thin double gold line border with tiny gem studs in the corners; a SMALL gold eight-pointed crystal star in the upper third.";;
4) V="LIGHT. Plain ivory porcelain with a soft glaze; a thin cobalt-blue painted line border with tiny leaf curls only in the corners; a SMALL cobalt medallion with a crystal in the upper third, one thin gold kintsugi seam crossing it.";;
5) V="LIGHT. Plain warm cream bone / parchment plate; a thin engraved sepia double line border with small brass corner pieces; a SMALL sepia engraving of a mine headframe in a little oval in the upper third.";;
esac
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1024x1536. Do not edit any other files, do not run anything else.
It is the BACK of a collectible card in a mobile match-3 game about a Ural mine full of crystals (the attached images show the FRONT of such a card and its interface kit: dark slate, iron, old brass). Same game, hand-painted, crafted materials, premium, not cartoonish, not flat vector.
DESIGN: $V
IMPORTANT: the design must be SIMPLE and CALM. The game will put three buttons and a progress gauge over the LOWER HALF of the back, so the lower half (and the middle) must be an even, quiet, plain field with no ornament and no picture, only the material's own texture and the thin border. The only decoration: the thin border and the small emblem in the upper third (the emblem no wider than a third of the card).
Symmetric, seen straight from the front, no perspective. The card fills the image almost to the edges (about 30 px margin), portrait, rounded corners (radius about 6% of the width). Outside the card: one solid flat pure magenta #FF00FF, no shadow. NO text, NO letters, NO numbers.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/../card_levitate_text.png" -i "$D/../../godot/assets/ui/kit/card.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
