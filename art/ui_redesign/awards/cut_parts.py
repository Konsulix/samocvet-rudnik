# Cuts the achievements screen sheets (gen_parts.sh, GPT on flat magenta) into pieces for the game.
#   python cut_parts.py <sheet.png> icons1|icons2|parts <out_dir>
# Every sheet is an even grid; each cell is trimmed to its picture (bits smaller than 0.4% of the cell are dropped).
import sys, os
import numpy as np
from PIL import Image

NAMES = {
    "icons1": ["three_skulls", "fire_maiden", "egg_needle", "pyrite", "casket", "nested",
               "halves", "oyster_moon", "butterfly", "mushrooms", "moss_stone", "star_crystal",
               "trilobite", "amber_fly", "obsidian", "flame", "flower_drop", "fern",
               "crowned_skull", "pearls", "fluorite", "adit", "serpent", "glow_stone"],
    "icons3": ["footsteps", "atlas_book", "twin_peaks", "odd_one", "own_rock", "moth",
               "overgrown", "glimpse", "night_watch", "snake_eyes", "kind_lizard", "kraken_eye",
               "lightning_rod", "lord_below", "domino", "lights_out", "conveyor", "overkill",
               "lazy", "unlucky", "old_gold", "pet_rock", "hoarder", "second"],
    "icons2": ["headframe", "scroll", "eye", "lizard", "tentacle", "lightning",
               "canary", "axe_crown", "hourglass", "rockfall", "keg", "flask",
               "hands", "bonfire", "crystal", "scales", "broken_heart", "cracked",
               "cage", "moon", "twins", "question", "book", "mask"],
    "icons4": ["bestiary", "feather", "beast_spirit", "maw", "fledged", "worked_out"],
    "icons5": ["paintbox", "pencils", "slice", "impostor", "fool_right", "old_friends", "midas", "matchmaker"],
    "icons6": ["rock_garden", "tiger_lily"],
    "icons7": ["cup", "medal"],
    "icons8": ["amber_wings", "amber_forest"],
    "icons9": ["sea_coral", "sea_star", "sea_shell", "sea_crab", "sea_swim", "sea_weed"],
    "icons10": ["sea_fish", "sea_ray"],
    "icons11": ["tsar_lamp", "tsar"],
    "icons12": ["duster", "duster_cloud"],
    "icons13": ["hunt_spit", "hunt_hand"],
    "icons14": ["mended", "mended_spare"],
    "parts": ["niche", "seal", "tab", "tab_on", "plate", "strip_hidden", "t_tales", "t_coll",
              "t_mines", "t_boss", "t_mastery", "t_secrets"],
}
GRID = {"icons1": (6, 4), "icons2": (6, 4), "icons3": (6, 4), "icons4": (3, 2), "icons5": (4, 2), "icons6": (2, 1), "icons7": (2, 1), "icons8": (2, 1), "icons9": (3, 2), "icons10": (2, 1), "icons11": (2, 1), "icons12": (2, 1), "icons13": (2, 1), "icons14": (2, 1), "parts": (4, 3)}

src, kind, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
r, g, b = im[..., 0], im[..., 1], im[..., 2]
mag = np.clip((np.minimum(r, b) - g - 0.25) / 0.45, 0.0, 1.0)
alpha = 1.0 - mag
a3 = np.maximum(alpha[..., None], 1e-3)
fg = np.clip((im - (1.0 - a3) * np.array([1.0, 0.0, 1.0])) / a3, 0.0, 1.0)
rgba = np.dstack([fg, alpha])
H, W = alpha.shape
cols, rows = GRID[kind]
for i, name in enumerate(NAMES[kind]):
    cy, cx = divmod(i, cols)
    y0, y1 = cy * H // rows, (cy + 1) * H // rows
    x0, x1 = cx * W // cols, (cx + 1) * W // cols
    sub = rgba[y0:y1, x0:x1]
    m = sub[..., 3] > 0.06
    # drop specks: rows/columns with almost nothing in them at the cell's edges
    ys = np.nonzero(m.sum(1) > m.shape[1] * 0.004)[0]
    xs = np.nonzero(m.sum(0) > m.shape[0] * 0.004)[0]
    if len(ys) == 0:
        print("EMPTY", name); continue
    sub = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sub = np.pad(sub, ((3, 3), (3, 3), (0, 0)))
    Image.fromarray((sub * 255).astype(np.uint8), "RGBA").save(os.path.join(out, name + ".png"))
    print(name, sub.shape[1], sub.shape[0])
