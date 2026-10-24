"""Package the selected six-stone PNG into equally padded Godot sprites.

Usage: python slice_gem_sheet.py source.png output_directory
Only slices and scales the supplied artwork; does not redraw its materials.
Source order: red, yellow, blue, green, purple, white.
"""
import argparse
import math
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--balanced", action="store_true", help="Balance visible area for differently shaped stones; cap either dimension at 224 px")
    args = parser.parse_args()
    sheet = Image.open(args.source).convert("RGBA")
    alpha = sheet.getchannel("A")
    # Ignore near-transparent export fringes when finding the six silhouettes.
    mask = alpha.point(lambda value: 255 if value >= 128 else 0)
    runs = []
    start = None
    for x in range(sheet.width + 1):
        occupied = x < sheet.width and mask.crop((x, 0, x + 1, sheet.height)).getbbox() is not None
        if occupied and start is None:
            start = x
        elif not occupied and start is not None:
            if x - start >= 20:
                runs.append((start, x))
            start = None
    if len(runs) != 6:
        raise ValueError(f"Expected six separated stones, found {len(runs)}")
    args.output.mkdir(parents=True, exist_ok=True)
    names = ["ruby", "citrine", "sapphire", "emerald", "amethyst", "diamond"]
    for name, (left, right) in zip(names, runs):
        _, top, _, bottom = mask.crop((left, 0, right, sheet.height)).getbbox()
        # Keep original RGBA edge pixels, including their antialiasing.
        stone = sheet.crop((max(0, left - 6), max(0, top - 6), min(sheet.width, right + 6), min(sheet.height, bottom + 6)))
        if args.balanced:
            area = sum(mask.crop((left, top, right, bottom)).histogram()[128:])
            scale = min(math.sqrt(27000 / area), 224 / max(stone.size))
            stone = stone.resize((round(stone.width * scale), round(stone.height * scale)), Image.Resampling.LANCZOS)
        else:
            stone.thumbnail((218, 218), Image.Resampling.LANCZOS)
        sprite = Image.new("RGBA", (256, 256))
        sprite.paste(stone, ((256 - stone.width) // 2, (256 - stone.height) // 2))
        sprite.save(args.output / f"{name}.png")
        print(f"{name}: {stone.width}x{stone.height} in 256x256")


if __name__ == "__main__":
    main()
