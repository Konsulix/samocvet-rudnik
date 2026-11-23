#!/bin/sh
# Pieces of the achievements screen for the game, drawn by GPT on magenta (cut by cut_parts.py):
#   sh gen_parts.sh <out png> icons1|icons2|icons3|icons4|icons5|icons6|icons7|icons8|icons9|icons10|icons11|icons12|icons13|icons14|parts
D="$(cd "$(dirname "$0")" && pwd -W)"
C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
ICON="Each icon is an INK DRAWING like the emblems on the left of the strips in the attached mock-ups: dark brown ink
lines with light hatching and a little warm wash, drawn for cream parchment, NO frame, NO medallion, NO circle behind,
NO parchment behind - only the drawing itself on the magenta. All icons the SAME visual weight and size (each fills
about 70% of its cell), the same line thickness, centred in its cell."
case "$2" in
icons1) L="(row 1) three human skulls in a small heap; a girl made of flame leaping; an egg with a needle through it;
a cluster of pyrite cubes; a small carved casket of malachite; three nested cubes, one inside another;
(row 2) a stone split into two matching halves, a spiral ammonite on each; an open oyster with a pearl under a
crescent moon; a butterfly; three mushrooms; a stone overgrown with moss; a star shining inside a crystal;
(row 3) a trilobite; a fly in a drop of amber; a sharp shard of obsidian; a tongue of flame; a flower inside a
clear drop of quartz; a fern leaf print;
(row 4) a skull wearing a small crown; a string of pearls; a fluorite cube; a mine adit entrance with timber
frame; a serpent's head; a glowing stone with rays";;
icons2) L="(row 1) a mine headframe with a wheel; a rolled scroll; an open eye; a lizard; an octopus tentacle; a
lightning bolt;
(row 2) a canary on a perch; a crowned axe; an hourglass; falling boulders (rockfall); a powder keg with a fuse; an
alchemist's flask;
(row 3) two open empty hands; a bonfire; a clean faceted crystal; old balance scales with coins; a broken heart;
a cracked stone;
(row 4) a bird cage; a crescent moon with stars; two identical crystals side by side; a big question mark; an open
book; a horned mask";;
icons3) L="(row 1) a trail of hobnailed boot prints; an open atlas book with a stone drawn on its page; two identical
crystals growing side by side like twin peaks; a strange crystal under a magnifying glass; a crystal growing out of a
rock of the same crystal; a moth circling a candle flame;
(row 2) a stone overgrown with moss, a mushroom and little flowers; an eye peeking through a crack in rock; a hanging
miner's lantern with a crescent moon behind; a serpent's head with a stick of dynamite; a lizard holding one single
emerald in its mouth; a big octopus eye with three cracks around it;
(row 3) an anvil with a lightning rod and a bolt striking it; a crown over a heap of bones; three powder kegs in a row,
toppling like dominoes; a lantern beam cutting through darkness; a conveyor belt carrying stones; two sticks of dynamite
crossed and exploding;
(row 4) a miner asleep in a hammock; a horseshoe broken in two; an old man's pipe lying on a pyrite cube; a pebble
with a ribbon bow, like a pet; a chest overflowing with stones; a stone with a circular arrow around it";;
icons4) L="(row 1) two animal skulls side by side like hunting trophies, a wolf's and a stag's with antlers; a single long
bird feather; a ghostly wolf's head made of wisps of light rising from a small animal skull;
(row 2) a wolf's skull in side view with sharp crystals growing in its open jaws; an animal skull cloaked in layered
feathers; an empty tipped-over mine cart with a pickaxe leaning on it and only a few crumbs of ore";;
icons5) L="(row 1) a painter's wooden palette with small crystals standing on it where the dabs of paint would be; three
long ribbed crystal pencils with flat ends, banded in two tones along their length, tied in a bundle with a string; a
round slice of a crystal cut like a slice of watermelon, a darker heart, a pale ring, a thin rind; a cube-shaped crystal
holding a theatre mask in front of itself;
(row 2) a small heap of metal cubes wearing a jester's cap with bells; two different crystals grown together and leaning
on each other, one a tall pointed prism and one a cube; a tall pointed crystal with lumpy gold nuggets clinging to its
side and tip; two different crystals tied together with a ribbon bow";;
icons6) L="(left) a rough lump of rock with a pointed crystal standing on it and a clump of small wild violets growing
out of a crack in it, their heart-shaped leaves round the foot; (right) a single tiger lily with curled-back spotted
petals and long stamens on a short stem";;
icons7) L="(left) a trophy cup seen straight from the front: a wide bowl with two curled handles, a laurel branch
engraved on it, a short stem and a square foot; (right) a round medal with a five-pointed star stamped on it, hanging
from a short folded ribbon";;
icons8) L="(left) a butterfly with its wings spread wide, sealed inside a smooth rounded drop of amber (the drop's outline
and a few curved highlight strokes, a little warm amber wash); (right) an oak leaf, an acorn and a small fern frond lying
together inside the same kind of smooth rounded drop of amber";;
icons9) L="(row 1) a branching sea coral standing on a little rock, a small sea anemone with waving tentacles at its foot; a
five-armed starfish lying beside a round spiny sea urchin; a spiral sea snail shell lying with a ribbed scallop shell;
(row 2) a crab seen from above, claws raised; an ancient sea reptile (a plesiosaur: long neck, four flippers) swimming
sideways; a strand of kelp seaweed with its long ribbon leaves swaying";;
icons10) L="(left) a little school of three small reef fish swimming together, one behind another, each a
different size, seen from the side; (right) a stingray seen from above, its long tail curved";;
icons11) L="(left) a six-sided twinned crystal (alexandrite) standing upright, its left half deep bluish green and its
right half wine red, a small lit oil lamp beside it on the right throwing warm light; (right) a small crown over a
six-sided crystal, the crystal half green half red";;
icons12) L="(left) a FEATHER DUSTER crossed over a small rock with a crystal cluster on it, the crystal spotless and
gleaming, a little cloud of dust drifting off to the side; (right) a small rock with a crystal on it inside a big
billowing cloud of dust, short motion arcs on both sides as if it were being shaken hard";;
icons14) L="(left) a single pointed crystal broken in two, the two pieces put back together and joined along the break by one bright seam of GOLD (kintsugi), a drop of gold on it; (right) a round stone shattered into many pieces and mended whole again with a web of bright GOLD seams (kintsugi)";;
icons13) L="(left) a plesiosaur's long neck rising out of rippling water in an S, its head turned back, jaws wide, a
round faceted gem flying out of the open jaws with a few drops of water; (right) a round faceted gem held up in a
miner's gloved hand, behind it a plesiosaur's long neck and head sinking back under the water, rings of ripples";;
parts) L="Each cell holds ONE game UI piece, in the style of the attached mock-ups (old brass, dark slate, leather,
parchment, wax), seen straight from the front:
(row 1) [a] an EMPTY square niche card: dark slate inside with a thin calm old-brass rim, slightly rounded corners,
nothing inside; [b] a round red wax seal with a stamped pickaxe, a little ribbon under it; [c] a bookmark TAB of dark
brown leather with an old-brass rim, pointed bottom (a pennant), EMPTY (no icon, no text), about 1:1.25;
[d] the same tab but ACTIVE: warm lit brass, EMPTY;
(row 2) [e] a small brass-and-slate label plate, wide (about 4:1), EMPTY; [f] a darker, crumpled, stained parchment
strip, wide (about 4:1), EMPTY; [g] a book icon; [h] a butterfly icon;
(row 3) [i] a pickaxe icon; [j] a horned mask icon; [k] an hourglass icon; [l] a keyhole icon.
The icons g-l are for the leather tabs: drawn in LIGHT warm brass/cream lines (not dark ink), NO frame around them.";;
esac
case "$2" in parts) G="a 4 columns x 3 rows grid";; icons4|icons9) G="a 3 columns x 2 rows grid of 6 icons, in this order";; icons5) G="a 4 columns x 2 rows grid of 8 icons, in this order";; icons6|icons7|icons8|icons10|icons11|icons12|icons13|icons14) G="a 2 columns x 1 row grid of 2 icons, in this order";; *) G="a 6 columns x 4 rows grid of 24 icons, in this order";; esac
case "$2" in parts) S="";; *) S="$ICON";; esac
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1536x1024. Do not edit any other files, do not run anything else.
It is a SPRITE SHEET for the achievements screen of a mobile game about mines and minerals (the attached images are
mock-ups of that screen). Lay the pieces out in $G, every piece centred in its own equal cell, at least 40 px of
magenta between pieces.
$S
$L
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around the pieces, no gradient, no shadow on it, no text,
no letters anywhere (except the question mark). When done, print the absolute path of the saved image."
# a new sheet of icons keeps to the first ones: their sheet goes along as the reference of the style
X=""
case "$2" in icons3|icons4|icons5|icons6|icons7|icons8|icons9|icons10|icons11|icons12|icons13|icons14) X="-i $D/sheet_icons2.png"; P="$P
The LAST attached image is a sheet of icons already in the game: draw the new ones in EXACTLY that style, line and weight.";; esac
OUT=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/mock_b.png" -i "$D/screen_combo.png" $X - 2>&1); echo "$OUT" > "$1.full.log"; R=$(echo "$OUT" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
