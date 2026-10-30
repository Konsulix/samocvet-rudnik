#!/bin/sh
# The coaching hand (tutorial pointer), in the style of the kit's icons.
# Usage: sh gen_hand.sh <codex.exe> <out png>
C="$1"; OUT="$2"
D="$(cd "$(dirname "$0")" && pwd -W)"
G="$(cd "$(dirname "$0")/../../godot/assets/ui/kit/icons" && pwd -W)"
P="\$imagegen Create ONE new image and save it as ONE PNG file, 1024x1024. Do not edit any other files, do not run anything else.
ONE game UI icon: a POINTING HAND for a tutorial pointer - a hand in a worn brown leather miner's work glove, the index finger stretched out and pointing straight UP, the other fingers curled in a loose fist, the thumb tucked along them, a short rolled glove cuff at the bottom with one small brass rivet. The fingertip is the topmost point of the picture. Exactly the same hand-drawn icon style, outline weight and top-left warm light as the attached kit icons (crisp dark ink outline, rich but slightly worn colours), friendly and clearly readable at a small size. Seen straight from the front (the back of the hand towards the viewer, very slightly turned), centred, about 520 px tall.
BACKGROUND: one solid flat pure magenta #FF00FF everywhere around it, no gradient, no shadow, no text."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only -i "$G/pick.png" -i "$G/heart.png" -i "$D/icons_a.png" - 2>&1 | tee "$OUT.log" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$OUT" && echo "OK $OUT"; else echo "FAIL $OUT"; fi
