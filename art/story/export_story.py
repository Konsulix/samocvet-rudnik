# Story portraits (GPT, faceted style, on magenta) -> godot/assets/story/<who>_<mood>.png, cut out and trimmed.
# Usage: python export_story.py <godot dir>
import sys, os
import numpy as np
from PIL import Image

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

def cut(path, box=None):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((np.minimum(r, b) - g - 0.25) / 0.35, 0, 1)      # how magenta
    spill = np.clip(np.minimum(r, b) - g, 0, None) * m
    a[..., 0] -= spill * 0.6
    a[..., 2] -= spill * 0.9
    img = Image.fromarray((np.dstack([np.clip(a, 0, 1), 1 - m]) * 255).astype(np.uint8), "RGBA")
    if box is None:
        return img.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    # trimmed at the sides and top only: the bottom edge is where the figure is cut off, kept
    img = img.crop((box[0], box[1], box[2], img.height))
    return img.resize((round(img.width * H / img.height), H), Image.LANCZOS)

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
    a = np.asarray(Image.open(os.path.join(HERE, "props", name + ".png")).convert("RGB")).astype(np.float32) / 255
    # cut() keeps the bottom for portraits; a prop is trimmed on every side
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((np.minimum(r, b) - g - 0.25) / 0.35, 0, 1)
    spill = np.clip(np.minimum(r, b) - g, 0, None) * m
    a[..., 0] -= spill * 0.6
    a[..., 2] -= spill * 0.9
    rgba = Image.fromarray((np.dstack([np.clip(a, 0, 1), 1 - m]) * 255).astype(np.uint8), "RGBA")
    rgba = rgba.crop(rgba.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox())
    k = 640 / max(rgba.size)
    if k < 1: rgba = rgba.resize((round(rgba.width * k), round(rgba.height * k)), Image.LANCZOS)
    rgba.save(os.path.join(OUT, "prop_" + name + ".png"))
    print("prop", name, rgba.size)
