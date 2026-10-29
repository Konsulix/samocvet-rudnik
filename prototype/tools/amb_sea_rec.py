"""Whalebone Cove's recorded sounds: real sea, gulls, foghorn and harbour in place of the first synthesized ones.
Writes over amb_sea.py's surf / crash / gull files and adds its own; deep and squelch (the Kraken) stay synthesized.

    py prototype/tools/amb_sea_rec.py <downloads> godot/assets/audio/amb/sea

<downloads> (see godot/assets/audio/CREDITS.md): dl7/ — BigSoundBank (CC0) s0266 "Sea: waves", s2570 "Cliff #1",
s2573 "Gulls on the harbor"; Wikimedia Commons Gull_1 (public domain), the East Brother Island lighthouse foghorn (CC0),
Boat_by_a_wharf_3 (public domain); dl2/ — rubberduck's bubbles (CC0); and Copper Mountain's furnace from amb/copper.
Makes: surf (loop), crash_0..2 (a wave on the cliff), gull_0..6, horn (the lighthouse's foghorn), lap (loop: water
slapping a moored boat, its timbers), under (loop: the sea in section, muffled, bubbling), bubble_0..2 (the diver's
air), tryworks (loop: fire under the try-pots and the oil seething).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000


def load(p):
    d, sr = sf.read(p, always_2d=True)
    d = d.mean(1)
    if sr != SR:
        d = np.interp(np.arange(0, len(d) - 1, sr / SR), np.arange(len(d)), d)
    return d


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.005, b=0.1):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    if na: d[:na] *= np.linspace(0, 1, na)
    if nb: d[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return d


def seam(d, x=1.5):
    n = int(x * SR)
    out = d[:-n].copy()
    w = np.linspace(0, 1, n)
    out[:n] = out[:n] * w + d[-n:] * (1 - w)
    return out


def cut(d, a, b):
    return d[int(a * SR):int(b * SR)]


def env(d, w=0.25):
    n = int(w * SR)
    return np.array([np.sqrt((d[k:k + n] ** 2).mean()) for k in range(0, len(d) - n, n)])


def write(path, d):
    # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    d7, d2 = os.path.join(src, "dl7"), os.path.join(src, "dl2")
    out = lambda n, d: write(os.path.join(dst, n + ".ogg"), d)
    # the surf: 40 s of moderate waves with the far roar, the seam cross-faded
    out("surf", norm(seam(cut(load(os.path.join(d7, "s0266.ogg")), 2, 44), 2.0), 0.8))
    # a wave on the cliff: the three loudest breaks of the cliff recording, 8 s apart at least
    cliff = load(os.path.join(d7, "s2570.ogg"))
    e = env(cliff)
    picks = []
    for i in np.argsort(-e):
        if all(abs(i - j) * 0.25 > 8 for j in picks):
            picks.append(i)
        if len(picks) == 3:
            break
    for k, i in enumerate(sorted(picks)):
        t0 = max(0.0, i * 0.25 - 0.8)
        out("crash_%d" % k, norm(fade(cut(cliff, t0, t0 + 4.0), 0.05, 1.5), 0.8))
    # gulls: a run of cries and four single ones (Gull_1), two far ones from the harbour
    g = load(os.path.join(d7, "Gull_1.mp3"))
    for k, (a, b) in enumerate([(0.1, 3.1), (6.25, 7.3), (7.75, 9.0), (10.55, 11.55), (12.15, 13.2)]):
        out("gull_%d" % k, norm(fade(cut(g, a, b), 0.02, 0.15), 0.8))
    h = load(os.path.join(d7, "s2573.ogg"))
    e = env(h, 0.1)
    loud = [i for i in np.argsort(-e)[:400]]
    took = []
    for i in loud:
        if all(abs(i - j) > 40 for j in took):
            took.append(i)
        if len(took) == 2:
            break
    for k, i in enumerate(took):
        t0 = max(0.0, i * 0.1 - 0.4)
        out("gull_%d" % (5 + k), norm(fade(lowpass(cut(h, t0, t0 + 1.6), 3000), 0.05, 0.4), 0.7))
    # the lighthouse's foghorn: one long low blast
    out("horn", norm(fade(cut(load(os.path.join(d7, "Original_foghorn_at_East_Brother_Island_Lighthouse.mp3")), 0.35, 4.75), 0.08, 0.6), 0.8))
    # a boat moored at the landing: water slapping its sides, its timbers giving
    out("lap", norm(seam(cut(load(os.path.join(d7, "Boat_by_a_wharf_3.mp3")), 1, 31), 1.5), 0.8))
    # the sea in section: the surf heard through water (very low) and slow bubbling
    bub = load(os.path.join(d2, "water-splash-slime-sfx", "loop_bubbles_02.ogg"))
    n = 21 * SR
    sea = lowpass(cut(load(os.path.join(d7, "s0266.ogg")), 10, 10 + n / SR), 350)
    under = norm(sea, 0.7) + norm(lowpass(np.tile(bub, 4)[:n], 1500), 0.35)
    out("under", norm(seam(under, 1.5), 0.8))
    for k, f in enumerate(["bubble_01", "bubble_02", "bubble_03"]):
        b = load(os.path.join(d2, "water-splash-slime-sfx", f + ".ogg"))
        out("bubble_%d" % k, norm(fade(lowpass(b, 2200), 0.005, 0.1), 0.8))
    # the tryworks: fire under the pots (Copper Mountain's furnace, quieter low end) and the oil seething
    fire = load(os.path.join(dst, "..", "copper", "furnace.ogg"))[: 16 * SR + int(1.5 * SR)]
    seethe = np.tile(load(os.path.join(d2, "water-splash-slime-sfx", "loop_bubbles_1.ogg")), 6)[: len(fire)]
    out("tryworks", norm(seam(norm(fire, 0.6) + norm(lowpass(seethe, 1800), 0.45), 1.5), 0.8))


if __name__ == "__main__":
    main()
