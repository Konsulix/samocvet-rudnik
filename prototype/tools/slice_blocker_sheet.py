"""Package supplied rock sprites and generated gas/timber with consistent padding."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot/assets/board/blockers_natural"


def pack(image, name):
    mask = image.getchannel("A").point(lambda a: 255 if a >= 24 else 0)
    bounds = mask.getbbox()
    if not bounds:
        raise ValueError(f"Empty sprite: {name}")
    left, top, right, bottom = bounds
    image = image.crop((max(0, left - 2), max(0, top - 2), min(image.width, right + 2), min(image.height, bottom + 2)))
    image.thumbnail((212, 212), Image.Resampling.LANCZOS)
    sprite = Image.new("RGBA", (256, 256))
    sprite.paste(image, ((256 - image.width) // 2, (256 - image.height) // 2))
    sprite.save(OUT / f"{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(ROOT / "art/board/blockers-source.png").convert("RGBA")
    for name, box in {
        "mud": (80, 0, 440, 300),
        "rock1": (70, 320, 430, 630),
        "rock2": (70, 650, 430, 940),
    }.items():
        pack(sheet.crop(box), name)
    # Keep the granite body near its intact size; loose chips must not shrink it.
    cracked = sheet.crop((590, 650, 950, 940))
    scale = 200 / 256
    cracked = cracked.resize((round(cracked.width * scale), round(cracked.height * scale)), Image.Resampling.LANCZOS)
    sprite = Image.new("RGBA", (256, 256))
    sprite.paste(cracked, (round(128 - (756 - 590) * scale), round(128 - (801 - 650) * scale)))
    sprite.save(OUT / "rock_cracked.png")
    for name, source in [("gas", "gas-source.png"), ("lock", "timber-source.png")]:
        pack(Image.open(ROOT / "art/board" / source).convert("RGBA"), name)


if __name__ == "__main__":
    main()
