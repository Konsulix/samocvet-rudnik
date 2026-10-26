"""Home-screen ambience: cuts the CC0 recordings to mono Ogg and synthesises the mine cart.

    python prototype/tools/amb_kit.py <download dir> godot/assets/audio/amb

<download dir> holds the OpenGameArt files (see godot/assets/audio/CREDITS.md):
dungeon_ambient_1_0.ogg, crickets_1.mp3, winch/ (from winch.zip).
Muffling and reverb are not baked in: the game sends all of these through its "Amb" bus.
"""
import sys, os
import numpy as np
import soundfile as sf

SR = 32000


def load(path):
    d, sr = sf.read(path, always_2d=True)
    d = d.mean(axis=1)
    if sr != SR:
        n = int(len(d) * SR / sr)
        d = np.interp(np.linspace(0, len(d) - 1, n), np.arange(len(d)), d)
    return d


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.01, b=0.05):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    if na: d[:na] *= np.linspace(0, 1, na)
    if nb: d[-nb:] *= np.linspace(1, 0, nb)
    return d


def loop_seam(d, x=1.0):
    """cross-fades the tail into the head so the loop has no click"""
    n = int(x * SR)
    out = d[:-n].copy()
    w = np.linspace(0, 1, n)
    out[:n] = out[:n] * w + d[-n:] * (1 - w)
    return out


def lowpass(x, f):
    a = 1 - np.exp(-2 * np.pi * f / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a * (x[i] - s)
        y[i] = s
    return y


def cart(seed, dur=4.0):
    """a loaded cart rolling a few metres on wooden-sleepered rails: rumble, rail-joint clacks, a faint squeal"""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # speed: eases up and down like the drawn cart (cubic in-out over the run)
    p = t / dur
    v = np.sin(np.pi * p) ** 1.5
    rumble = lowpass(rng.standard_normal(n), 140) * 6.0
    grit = lowpass(rng.standard_normal(n), 900) - lowpass(rng.standard_normal(n), 300)
    out = (rumble + grit * 0.25) * v
    # clacks: wheels over joints, two axles, spacing shrinks with speed
    pos = np.cumsum(v) / SR * 2.6
    joints = np.floor(pos)
    hits = np.nonzero(np.diff(joints) > 0)[0]
    for h in hits:
        for lag in (0, int(0.11 * SR / max(0.3, v[h]))):
            k = h + lag
            m = min(n - k, int(0.06 * SR))
            if m <= 0: continue
            e = np.exp(-np.arange(m) / (0.008 * SR))
            out[k:k + m] += rng.standard_normal(m) * e * 0.9 * v[h]
            out[k:k + m] += np.sin(2 * np.pi * 180 * np.arange(m) / SR) * e * 0.6 * v[h]
    # squeal: a thin wavering tone at the start and the stop
    sq = np.sin(2 * np.pi * (2300 + 120 * np.sin(2 * np.pi * 3 * t)) * t)
    out += sq * 0.03 * (np.exp(-((p - 0.12) / 0.06) ** 2) + np.exp(-((p - 0.88) / 0.06) ** 2))
    return fade(norm(out, 0.7), 0.05, 0.3)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    def w(name, d):
        # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
        with sf.SoundFile(os.path.join(dst, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(d), 4096):
                f.write(d[i:i + 4096].astype(np.float32))
    cave = load(os.path.join(src, "dungeon_ambient_1_0.ogg"))
    w("cave", norm(loop_seam(cave[: SR * 60], 2.0), 0.7))
    cr = load(os.path.join(src, "crickets_1.mp3"))
    w("crickets", norm(loop_seam(cr, 1.0), 0.7))
    for i, f in enumerate(["winch - Marker 2.wav", "winch - Marker #8.wav"]):
        w("winch_%d" % i, fade(norm(load(os.path.join(src, "winch", f)), 0.8), 0.02, 0.4))
    for i in range(2):
        w("cart_%d" % i, cart(7 + i))


if __name__ == "__main__":
    main()
