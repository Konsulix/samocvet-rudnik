# Shared bits for the animation previews: magenta keying and cutting a cycle sheet into frames along silhouettes.
import numpy as np
from PIL import Image

def key(im):
    """magenta -> transparent, with the magenta taken out of soft edges (as in art/malachite/parts_cut.py)"""
    a = np.asarray(im.convert("RGB")).astype(float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    al = 1 - np.clip((np.minimum(r, b) - g - 0.25) / 0.45, 0, 1)
    fg = np.clip((a - (1 - al[..., None]) * np.array([1, 0, 1])) / np.maximum(al[..., None], 1e-3), 0, 1)
    return Image.fromarray((np.dstack([fg, al]) * 255).astype(np.uint8))

def fit_h(im, h):
    return im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)

def label(mask):
    lab = np.zeros(mask.shape, np.int32); n = 0
    h, w = mask.shape
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]: continue
        n += 1; stack = [(y0, x0)]; lab[y0, x0] = n
        while stack:
            y, x = stack.pop()
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; stack.append((yy, xx))
    return lab, n

def by_shape(im, n, rows=1, align="center", ahead=False):
    """n frames cut along the figures' silhouettes (the n biggest regions; small loose bits - a pick, spray - join the
    nearest one), ordered by rows then left to right, on one canvas size with the bottoms aligned. With `ahead` (people
    facing right) a loose bit joins the nearest figure it is IN FRONT of: a thrown stone or a spark flies out of its own
    cell towards the next drawing, and by plain nearness it hung behind the next man's back"""
    S = 4
    al = np.asarray(im)[..., 3]
    h, w = al.shape
    small = al[: h // S * S, : w // S * S].reshape(h // S, S, w // S, S).max(axis=(1, 3)) > 128
    lab, k = label(small)
    sizes = np.bincount(lab.ravel())[1:]
    big = list(np.argsort(sizes)[::-1][:n] + 1)
    cen = {i: (np.nonzero(lab == i)[0].mean(), np.nonzero(lab == i)[1].mean()) for i in range(1, k + 1)}
    by_y = sorted(big, key=lambda i: cen[i][0])
    # rows split at the widest gaps between the drawings' middles, not by equal counts: GPT sometimes puts 4 drawings in a
    # row and 8 in the next (the bailer), and equal counts then mixed the rows up
    gaps = sorted(range(1, len(by_y)), key=lambda j: cen[by_y[j]][0] - cen[by_y[j - 1]][0])[::-1][:rows - 1]
    cuts = [0] + sorted(gaps) + [len(by_y)]
    order = []
    for r in range(rows):
        order += sorted(by_y[cuts[r]:cuts[r + 1]], key=lambda i: cen[i][1])
    owner = {}
    for i in range(1, k + 1):
        near = lambda j: (cen[i][0] - cen[j][0]) ** 2 + (cen[i][1] - cen[j][1]) ** 2
        behind = [j for j in big if cen[j][1] < cen[i][1] and abs(cen[j][0] - cen[i][0]) < h / S / rows / 2] if ahead else []
        owner[i] = i if i in big else min(behind or big, key=near)
    lut = np.zeros(k + 1, np.int32)
    for i, o in owner.items():
        lut[i] = o
    own = np.repeat(np.repeat(lut[lab], S, 0), S, 1)
    own = np.pad(own, ((0, h - own.shape[0]), (0, w - own.shape[1])))
    arr = np.asarray(im)
    out = []
    for i in order:
        msk = own == i
        ys, xs = np.nonzero(msk)
        a = arr.copy(); a[..., 3] = (a[..., 3] * msk).astype(np.uint8)
        out.append(Image.fromarray(a).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
    # horizontal registration: a walker by the hips (the bbox jumps with every stride), a planted figure by the feet
    def ax(f):
        a = np.asarray(f)[..., 3] > 128
        ys, xs = np.nonzero(a)
        top, bot = ys.min(), ys.max()
        if align == "hips":
            band = (ys > top + (bot - top) * 0.40) & (ys < top + (bot - top) * 0.58)
        elif align == "feet":
            band = ys > bot - (bot - top) * 0.12
        else:
            return f.width / 2
        return xs[band].mean()
    anchors = [ax(f) for f in out]
    left = max(anchors); right = max(f.width - a for f, a in zip(out, anchors))
    W = int(left + right) + 2; H = max(f.height for f in out)
    res = []
    for f, a in zip(out, anchors):
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0)); g.alpha_composite(f, (int(left - a), H - f.height)); res.append(g)
    return res

def smooth_order(fr):
    """GPT numbers the drawings of a loop, but they do not always follow each other: neighbours on the sheet can be poses
    far apart, and the loop jumps. Find the order through all drawings with the least change from one to the next
    (a closed tour: nearest neighbour, then 2-opt), starting from the sheet's first drawing and keeping its direction."""
    sz = (48, 48)
    def vec(f):
        g = Image.new("RGBA", f.size, (0, 0, 0, 0)); g.alpha_composite(f)
        a = np.asarray(g.resize(sz, Image.BILINEAR)).astype(float) / 255
        return np.concatenate([a[..., 3].ravel() * 2, (a[..., :3].mean(2) * a[..., 3]).ravel()])
    v = np.array([vec(f) for f in fr])
    D = np.sqrt(((v[:, None] - v[None]) ** 2).sum(-1))
    n = len(fr)
    tour, left = [0], set(range(1, n))
    while left:
        j = min(left, key=lambda k: D[tour[-1], k]); tour.append(j); left.discard(j)
    better = True
    while better:
        better = False
        for i in range(1, n - 1):
            for j in range(i + 1, n):
                a, b, c, d = tour[i - 1], tour[i], tour[j], tour[(j + 1) % n]
                if D[a, c] + D[b, d] < D[a, b] + D[c, d] - 1e-9:
                    tour[i:j + 1] = tour[i:j + 1][::-1]; better = True
    if tour[1] > tour[-1]:            # the sheet's own direction: frame 1 is followed by an early drawing
        tour = [tour[0]] + tour[1:][::-1]
    return tour
