#!/bin/sh
# Frost ferns on a window, for the frost bloom's card (CardFrost): white ice on pure black, its brightness is the frost.
#   sh gen.sh <out png>
C=$(ls -t "$LOCALAPPDATA"/OpenAI/Codex/bin/*/codex.exe | head -1)
P="\$imagegen Create ONE new image and save it as ONE PNG file, square 1024x1024. Do not edit any other files, do not run anything else.
A close-up photograph of FROST FERNS on a winter window pane: feathery branching ice crystals (dendrites, 'Jack Frost'
patterns) of many sizes — long curving fronds with fine side branches, small starry clusters between them, fine rime
in the gaps. Pure WHITE ice on a pure BLACK background (the glass is black, nothing seen through it), evenly lit, sharp,
high detail, no blur, no vignette, no text. The pattern fills the whole square evenly and is SEAMLESSLY TILEABLE
(its left edge continues into its right edge, its top into its bottom). When done, print the absolute path of the saved image."
R=$(printf '%s' "$P" | "$C" exec --skip-git-repo-check -s read-only - 2>&1 | tee "$1.log" | grep -o 'C:.*\.png' | tail -1)
if [ -n "$R" ]; then cp "$R" "$1" && echo "OK $1"; else echo "FAIL $1"; fi
