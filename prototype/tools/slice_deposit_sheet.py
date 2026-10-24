"""Slice the transparent 1536x1024 five-stage deposit sheet (Pillow).

Usage: python slice_deposit_sheet.py source.png output_directory
Rows: geode, mineral. Columns: four live stages and the remaining shell.
"""
import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    sheet = Image.open(args.source).convert("RGBA")
    if sheet.size != (1536, 1024):
        raise ValueError("Expected the original transparent 1536x1024 sheet")
    args.output.mkdir(parents=True, exist_ok=True)
    # Anchor the masonry, not the full silhouette (which includes loose debris).
    # Match BoardSprites.DEPOSIT_CORE: the body occupies (64,64)..(448,448).
    core_lefts = [32, 332, 635, 938, 1240]
    for kind, top, bottom in [("geode", 190, 510), ("mineral", 570, 890)]:
        core_top, core_bottom = (198, 469) if kind == "geode" else (572, 849)
        for stage in range(5):
            left = round(stage * sheet.width / 5)
            right = round((stage + 1) * sheet.width / 5)
            stone = sheet.crop((left, top, right, bottom))
            sx = 384 / 264
            sy = 384 / (core_bottom - core_top)
            stone = stone.resize((round(stone.width * sx), round(stone.height * sy)), Image.Resampling.LANCZOS)
            sprite = Image.new("RGBA", (512, 512))
            sprite.paste(stone, (round(64 + (left - core_lefts[stage]) * sx), round(64 + (top - core_top) * sy)))
            sprite.save(args.output / f"deposit_{kind}_{stage}.png")


if __name__ == "__main__":
    main()
