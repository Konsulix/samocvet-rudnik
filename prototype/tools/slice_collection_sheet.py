"""Package the user's 1825x862 mineral collection without redrawing it.

Usage: python slice_collection_sheet.py source.png output_directory
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
    if sheet.size != (1825, 862):
        raise ValueError("Expected the original 1825x862 collection sheet")
    regions = {
        "gold": (0, 0, 480, 450),
        "dark": (480, 0, 880, 450),
        "opal": (880, 0, 1245, 450),
        "green": (1245, 0, 1600, 450),
        "rose": (0, 450, 1825, 862),
    }
    args.output.mkdir(parents=True, exist_ok=True)
    for name, region in regions.items():
        cell = sheet.crop(region)
        mask = cell.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        left, top, right, bottom = mask.getbbox()
        stone = cell.crop((max(0, left - 6), max(0, top - 6), min(cell.width, right + 6), min(cell.height, bottom + 6)))
        stone.thumbnail((218, 218), Image.Resampling.LANCZOS)
        sprite = Image.new("RGBA", (256, 256))
        sprite.paste(stone, ((256 - stone.width) // 2, (256 - stone.height) // 2))
        sprite.save(args.output / f"{name}.png")
        print(f"{name}: {stone.width}x{stone.height} in 256x256")


if __name__ == "__main__":
    main()
