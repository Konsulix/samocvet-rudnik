# Story portraits (GPT, faceted style, on magenta) -> godot/assets/story/<who>_<mood>.png, cut out and trimmed.
# Usage: python export_story.py <godot dir>
import sys, os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(sys.argv[1], "assets", "story")
H = 1200   # px tall: a portrait takes ~60% of a phone screen at 3 px a point

PICS = {
    "guide_calm": "adit/base.png",
    "guide_point": "adit/emo_point.png",
    "guide_worry": "adit/emo_worry.png",
    "guide_laugh": "adit/emo_laugh.png",
    "guide_sad": "adit/emo_sad.png",
    "guide_surprise": "adit/emo_surprise.png",
    "guide_angry": "adit/emo_angry.png",
    "rival_calm": "rival/s1_base.png",
    "rival_angry": "rival/emo_angry.png",
    "rival_mock": "rival/emo_mock.png",
    "rival_haunted": "rival/emo_haunted.png",
    "rival_offer": "rival/emo_offer.png",
    "sister_calm": "friend/base.png",
    "sister_worry": "friend/emo_worry.png",
    "sister_smile": "friend/emo_smile.png",
    "sister_shock": "friend/emo_shock.png",
    "sister_resolve": "friend/emo_resolve.png",
    "sister_sad": "friend/emo_sad.png",
    "sister_curious": "friend/emo_curious.png",
    # Proval: him with the four shards grown into him (rival5/), mirrored so he faces her across the screen
    "brother_calm": "rival5/s3_base.png",
    "brother_angry": "rival5/emo_angry.png",
    "brother_offer": "rival5/emo_offer.png",
    "brother_haunted": "rival5/emo_haunted.png",
}
FLIP = {"brother"}

BG = np.array([0.984, 0.016, 0.984], np.float32)   # GPT's magenta

def unmix(path):
    """the figure off the magenta, alpha and colour: an edge pixel is figure and magenta mixed, so its alpha is how
    much more magenta it is than green, and the magenta is taken back out of its colour (no purple rim)"""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = np.clip((np.minimum(r, b) - g) / float(min(BG[0], BG[2]) - BG[1]), 0, 1)
    al = np.clip((1 - bg - 0.06) / 0.94, 0, 1)            # a hair tighter: the last faint ring goes
    keep = np.maximum(al, 1e-3)[..., None]
    col = np.clip((a - (1 - keep) * BG) / keep, 0, 1)
    # what magenta tint is left on the rim, gone: the figure itself has none (its own reds and violets aren't both
    # over the green by much where it is solid)
    rim = (al < 0.98)[..., None]
    lo = np.minimum(col[..., 0], col[..., 2]) - col[..., 1]
    fix = np.clip(lo, 0, None)[..., None] * np.array([1.0, 0.0, 1.0], np.float32)
    col = np.where(rim, col - fix, col)
    # lone specks in the magenta (noise of the picture) out: they would widen the crop and float by the figure
    solid = Image.fromarray(((al > 0.08) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(9))
    al = al * (np.asarray(solid) > 0)
    img =Image.fromarray((np.dstack([np.clip(col, 0, 1), al]) * 255 + 0.5).astype(np.uint8), "RGBA")
    return img

def shrink(img, size):
    """scaled with the colour premultiplied: the clear pixels' colour never bleeds into the edge"""
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")

def cut(path, box=None):
    img = unmix(path)
    if box is None:
        return img.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    # trimmed at the sides and top only: the bottom edge is where the figure is cut off, kept
    img = img.crop((box[0], box[1], box[2], img.height))
    return shrink(img, (round(img.width * H / img.height), H))

os.makedirs(OUT, exist_ok=True)
# one crop for all the moods of a character, so they swap in place
boxes = {}
PICS = {k: v for k, v in PICS.items() if os.path.exists(os.path.join(HERE, v))}
for name, src in PICS.items():
    who = name.split("_")[0]
    b = cut(os.path.join(HERE, src))
    o = boxes.get(who, b)
    boxes[who] = (min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3]))
for name, src in PICS.items():
    im = cut(os.path.join(HERE, src), boxes[name.split("_")[0]])
    if name.split("_")[0] in FLIP: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im.save(os.path.join(OUT, name + ".png"))
    print(name, im.size)

# objects shown in the scenes (StoryScene "prop:<name>", gen_prop.sh): trimmed to the object, at most 640 px
PROPS = ["notebook", "scale", "bootprints", "letter", "rune"]
for name in PROPS:
    # cut() keeps the bottom for portraits; a prop is trimmed on every side
    rgba = unmix(os.path.join(HERE, "props", name + ".png"))
    rgba = rgba.crop(rgba.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox())
    k = 640 / max(rgba.size)
    if k < 1: rgba = shrink(rgba, (round(rgba.width * k), round(rgba.height * k)))
    rgba.save(os.path.join(OUT, "prop_" + name + ".png"))
    print("prop", name, rgba.size)
