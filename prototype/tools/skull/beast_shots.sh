#!/bin/bash
# Gallery shots of the beasts, 4 to a picture: beast_shots.sh <out dir> <tag> "<extra gallery keys>" [beasts...]
# (default: plain bone, crystals at the crown, nothing else). Needs $G (Godot).
OUT="$1"; TAG="$2"; EXTRA="$3"; shift 3
R="$(cd "$(dirname "$0")/../../.." && pwd)"
LIST=("$@"); [ ${#LIST[@]} -eq 0 ] && LIST=(alligator spoonbill deer mouflon ram longhorn musk_ox wolf bear fox horse lion raven hornbill trex triceratops)
PLAIN="skin=bone tone=bone moss=none trees=0 flies=0 show=loose bloom=0 stream=0 roots=0 dmg=none milk=clear crown=1 eyes=none"
i=0
while [ $i -lt ${#LIST[@]} ]; do
  grp=$(IFS=,; echo "${LIST[*]:$i:4}")
  "$G" --path "$R/godot" --resolution 800x800 res://tests/spec_gallery.tscn -- area=0 sp=${SP:-amethyst} form=skull beast=$grp n=4 px=400 cols=2 ${PLAIN_OFF:-$PLAIN} $EXTRA shot=user://bs_${TAG}_$i.png after=${AFTER:-14} 2>&1 | grep -A2 "SCRIPT ERROR" | head -6
  cp "$APPDATA/Godot/app_userdata/Gemcore/bs_${TAG}_$i.png" "$OUT/"
  i=$((i+4))
done
