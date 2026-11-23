#!/bin/sh
# The back of a find's card (the kintsugi card turns over), drawn by GPT: one design per call.
#   sh gen.sh <out png> 1|2|3|4|5
D="$(cd "$(dirname "$0")" && pwd -W)"; C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
case "$2" in
1) V="DARK. Dark blue-grey slate (like the attached card's slate) with a fine engraved brass filigree border of scrolls and
small rivets in the corners; in the middle a round brass medallion holding a geode broken in two and mended with gold
seams (kintsugi), a few small crystals glinting inside it; thin brass rays and fine engraved lines spreading from the
medallion to the border in a symmetric pattern.";;
2) V="DARK. Black lacquer (Japanese urushi) with a deep warm shine; across the whole back a network of thin bright GOLD
kintsugi seams, as if the lacquer panel had shattered and been mended with gold; in the centre a single faceted crystal
outlined in gold leaf, the seams radiating from it; a narrow gold leaf border with small cloud-scroll corners.";;
3) V="DARK. Deep midnight-blue enamel with a gold compass rose in the middle whose points are long thin crystals; around it
a ring of tiny gold stars and the phases of the moon; a double gold border with little gem studs (ruby, emerald, sapphire)
in the four corners; fine gold guilloche lines filling the field.";;
4) V="LIGHT. Ivory white porcelain with a soft glaze; a border and corner ornament painted in cobalt-blue underglaze (old
Ural / Gzhel feeling: flowing leaves and scrolls); in the middle a round cobalt medallion with a crystal cluster; the
porcelain has been broken and mended with gold - a few thin gold kintsugi seams run across it, through the ornament.";;
5) V="LIGHT. Warm cream parchment-coloured bone / ivory plate engraved like an old book plate: a fine sepia ink engraving of
a mine headframe over a cave full of crystals, framed by an oval laurel wreath; a thin engraved double line border with
small brass corner pieces held by rivets; faint hatching, warm and calm.";;
esac
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1024x1536. Do not edit any other files, do not run anything else.
It is the BACK of a collectible card in a mobile match-3 game about a Ural mine full of crystals and minerals (like the
back of a fine playing card or a trading card). The attached images show the FRONT of such a card in the game (a stone
over a slate info panel, the dark slate, iron and old brass interface kit): the back must belong to the same game - hand-
painted, rich, crafted, old brass and stone materials, premium and beautiful, not cartoonish, not flat vector.
DESIGN: $V
The design is SYMMETRIC (mirror left-right, ideally also top-bottom), seen straight from the front, no perspective, no
tilt, no hand, no table. The card fills the image almost to the edges (about 30 px of margin), portrait, with rounded
corners (radius about 6% of the width). Outside the card: one solid flat pure magenta #FF00FF, no shadow on it.
NO text, NO letters, NO numbers, NO logo anywhere.
When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/../card_levitate_text.png" -i "$D/../../godot/assets/ui/kit/card.png" - 2>&1 | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
