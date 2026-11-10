#!/bin/bash
# usage: run_prep.sh <out dir> <grid dir> id...   (6 Blender processes at a time)
R="$(cd "$(dirname "$0")/../../.." && pwd)"; B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
OUT="$1"; GR="$2"; shift 2; mkdir -p "$OUT" "$GR"
printf "%s\n" "$@" | xargs -P 6 -I{} bash -c '"$0" -b -P "$1/prototype/tools/skull/beast_prep.py" -- "$1/prototype/tools/skull/beasts.json" {} "$HOME/Desktop/черепа" "$2" "$3" > "$3/{}.log" 2>&1' "$B" "$R" "$OUT" "$GR"
grep -h "PREP part\|Error\|Traceback" "$GR"/*.log
