#!/bin/sh
# Empty board tiles in the exact look of mock F (slate cell + mud cell), on magenta, for cut_tiles.py.
# Usage: sh gen_tiles.sh <codex.exe> <out png>
C="$1"; OUT="$2"
D="$(cd "$(dirname "$0")" && pwd -W)"
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1536x1024. Do not edit any other files, do not run anything else.
A sprite sheet of EMPTY match-3 board cell tiles, copied exactly from the board in the attached mockup (look F): the same material, colour, light and painterly game-art finish.
TOP ROW: 4 square SLATE tiles - matte mid-dark cool blue-grey slate (like the empty parts of the cells in the mockup), smooth surface with only a very faint stone texture, a soft lighter gradient towards the top-left, a crisp light bevelled rim along the top and left edges and a darker rim along the bottom and right; each of the 4 slightly different in its faint texture, same colour.
BOTTOM ROW: 4 square MUD tiles - exactly like the mud cells in the mockup: glossy reddish-brown wet mud filling the tile, heaped into a lumpy raised rim along the edges, smoother and a bit darker in the middle, a few wet highlights; each of the 4 slightly different.
NO gems, no objects, nothing on the tiles. All 8 tiles the same size (about 300x300 px), seen straight from above, perfectly square outline, evenly spaced in a 4x2 grid with wide gaps.
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around and between the tiles, no shadow, no text."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$D/mock_f.png" - 2>&1 | tee "$OUT.log" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
