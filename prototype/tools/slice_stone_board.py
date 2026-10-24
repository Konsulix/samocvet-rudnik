"""Package the supplied stone frame and cell tile without redrawing them.

Usage: python slice_stone_board.py source.png output_directory
The frame's stone face supplies the texture for the board's contour rim.
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
    if sheet.size != (1535, 1024):
        raise ValueError("Expected the original 1535x1024 frame sheet")
    args.output.mkdir(parents=True, exist_ok=True)
    sheet.crop((22, 84, 857, 918)).save(args.output / "frame.png")
    sheet.crop((1238, 132, 1507, 412)).save(args.output / "tile.png")


if __name__ == "__main__":
    main()
