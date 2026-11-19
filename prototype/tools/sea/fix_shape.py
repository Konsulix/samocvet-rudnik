"""Set right, after sea_prep.py, a scan laid out the way it was on the scanner's table, not as it swims — on the light
mesh (.obj) alone: its textures are already baked, its relief is in the surface's own frame, so it bends with it.

    py prototype/tools/sea/fix_shape.py <godot/assets/specimen/sea> [fish_stingray] [fish_squid]

fish_stingray: its long whip of a tail lay curled round in a loop beside it — straightened out behind, along the line
    it left the body by (each cross-section of the tail turned with it, so it stays round).
fish_squid: its two long hunting tentacles lay back along its sides, their clubs by the fins, as if reaching forward
    — folded back to trail with the arms (mirrored about where they leave the head, drawn in to the arms).
"""
import os
import sys
import heapq
import numpy as np


def read(path):
    lines = open(path, encoding="utf-8").read().splitlines()
    v = np.array([[float(x) for x in l.split()[1:4]] for l in lines if l.startswith("v ")])
    vn = np.array([[float(x) for x in l.split()[1:4]] for l in lines if l.startswith("vn ")])
    faces = [[tuple(int(q) - 1 if q else -1 for q in c.split("/")) for c in l.split()[1:]] for l in lines if l.startswith("f ")]
    return lines, v, vn, faces


def write(path, lines, v, vn):
    out, iv, ivn = [], 0, 0
    for l in lines:
        if l.startswith("v "):
            out.append("v %.6f %.6f %.6f" % tuple(v[iv]))
            iv += 1
        elif l.startswith("vn "):
            n = vn[ivn] / max(1e-9, np.linalg.norm(vn[ivn]))
            out.append("vn %.4f %.4f %.4f" % tuple(n))
            ivn += 1
        else:
            out.append(l)
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")


def vn_of(faces, nv):
    # which normals belong to which vertex (an .obj gives each corner its own)
    m = [set() for _ in range(nv)]
    for f in faces:
        for c in f:
            if len(c) > 2 and c[2] >= 0:
                m[c[0]].add(c[2])
    return m


def rot_to(a, b):
    # the rotation taking unit a onto unit b
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    c = np.cross(a, b)
    d = float(np.dot(a, b))
    if d < -0.9999:
        ax = np.cross(a, [0, 1, 0])
        ax /= np.linalg.norm(ax)
        return 2 * np.outer(ax, ax) - np.eye(3)
    k = np.array([[0, -c[2], c[1]], [c[2], 0, -c[0]], [-c[1], c[0], 0]])
    return np.eye(3) + k + k @ k / (1 + d)


def stingray(path):
    lines, v, vn, faces = read(path)
    # (vertices at the same point are one: the bake's seams split them)
    key = {}
    idx = np.array([key.setdefault(tuple(np.round(p, 5)), len(key)) for p in v])
    nb = [set() for _ in range(len(key))]
    for f in faces:
        for i in range(len(f)):
            a, b = idx[f[i][0]], idx[f[(i + 1) % len(f)][0]]
            nb[a].add(b)
            nb[b].add(a)
    pos = np.zeros((len(key), 3))
    for i, p in enumerate(v):
        pos[idx[i]] = p
    # the tail: its far end the point furthest from the disc's middle; walked back along the mesh, it is the thin part —
    # the part where the walk's front is narrow. Its root: where the front widens into the disc
    def walk(start):
        dist = np.full(len(key), np.inf)
        dist[start] = 0.0
        hp = [(0.0, start)]
        while hp:
            d, a = heapq.heappop(hp)
            if d > dist[a]:
                continue
            for b in nb[a]:
                nd = d + float(np.linalg.norm(pos[a] - pos[b]))
                if nd < dist[b]:
                    dist[b] = nd
                    heapq.heappush(hp, (nd, b))
        return dist
    # (the tip: the point furthest along the mesh from the disc's middle — the loop's far side is nearer by the walk)
    mid = int(np.argmin(np.linalg.norm(pos - [0.05, pos[:, 1].mean(), 0.0], axis=1)))
    d0 = walk(mid)
    far = int(np.argmax(np.where(np.isfinite(d0), d0, -1)))
    dist = walk(far)
    # how wide the tail is at each distance from its tip: the spread of the vertices in a band of it
    step = 0.01
    root_s = None
    cen = []
    for k in range(200):
        band = (dist >= k * step) & (dist < (k + 1) * step)
        if band.sum() < 2:
            cen.append(cen[-1] if cen else pos[far])
            continue
        p = pos[band]
        c = p.mean(axis=0)
        w = float(np.linalg.norm(p - c, axis=1).max())
        if w > 0.035 and k > 10:
            root_s = k * step
            break
        cen.append(c)
    print("stingray tail: %.3f long (%d bands)" % (root_s, len(cen)))
    cen = np.array(cen)
    # (the centre line smoothed: a band's mean wobbles)
    sm = cen.copy()
    for i in range(2, len(cen) - 2):
        sm[i] = cen[i - 2:i + 3].mean(axis=0)
    cen = sm
    n = len(cen)
    # (its direction at each band, over a few bands: where a band was empty its centre repeats, and the step there is nil)
    tang = np.array([cen[min(n - 1, k + 3)] - cen[max(0, k - 3)] for k in range(n)])
    tang /= np.maximum(1e-9, np.linalg.norm(tang, axis=1))[:, None]
    # (the tail runs from the root, the last band, out to the tip, the first: straight out behind the disc, along its line)
    root = cen[-1]
    out_dir = np.array([-1.0, 0.0, 0.0])
    tail = dist < root_s
    nmap = vn_of(faces, len(v))
    for i in range(len(v)):
        g = idx[i]
        if not tail[g]:
            continue
        s = dist[g]
        k = min(n - 1, int(s / step))
        # the tail's own length from the root to this point, and the turn of its line here to the straight line
        along = root_s - s
        r = rot_to(-tang[k], out_dir)
        off = v[i] - cen[k]
        # (blended in over the tail's first few bands: no kink at the root)
        bl = min(1.0, along / 0.05)
        v[i] = (1 - bl) * v[i] + bl * (root + out_dir * along + r @ off)
        for j in nmap[i]:
            vn[j] = (1 - bl) * vn[j] + bl * (r @ vn[j])
    write(path, lines, v, vn)


def squid(path):
    lines, v, vn, faces = read(path)
    # the two tentacles: out to the side of the mantle and the head, between where they leave the head and the fins
    x_root = -0.33
    sel = (np.abs(v[:, 2]) > 0.066) & (v[:, 0] > x_root) & (v[:, 0] < 0.1)
    print("squid tentacles: %d vertices" % sel.sum())
    nmap = vn_of(faces, len(v))
    for i in np.nonzero(sel)[0]:
        x, y, z = v[i]
        # mirrored about the root, drawn in towards the arms, the further back the more
        t = (x - x_root) / 0.43
        v[i] = [x_root - (x - x_root) * 0.55, y, z * (1.0 - 0.45 * min(1.0, t * 2.0))]
        for j in nmap[i]:
            vn[j] = vn[j] * [-1, 1, 1]
    write(path, lines, v, vn)


if __name__ == "__main__":
    d = sys.argv[1]
    names = sys.argv[2:] or ["fish_stingray", "fish_squid"]
    for n in names:
        {"fish_stingray": stingray, "fish_squid": squid}[n](os.path.join(d, n + ".obj"))
