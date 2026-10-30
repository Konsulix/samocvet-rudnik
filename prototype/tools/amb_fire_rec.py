"""Fire Horizon's recorded sounds, in place of amb_fire.py's synthesized hammer, cicadas, burning, river, steam, sparks and
ring (its cold wind stays synthesized), plus the stream, the drip, the donkey and the goat it had none of:

    py prototype/tools/amb_fire_rec.py <scratch> godot/assets/audio/amb/fire

<scratch>: dl9/ — BigSoundBank (CC0): anvil #1 #2 (s3589 s3590), cicada 1 long (s2397), donkeys braying (s1548),
donkey #3 (s1551), forest and stream #2 (s2714), drops of water #1 (s1384), bleating goat #1 #2 (s0279 s0280);
dl5/fire.wav (PagDev), dl2/ steam hisses (bart) and bubbles (rubberduck), all CC0.
hammer_0..2 — the Cyclops' hammer far below: a smith's anvil strike slowed to a giant's (×0.45), dulled, a deep thud under
it; ring — the forge gate: one strike slowed less, ringing long; cicadas — a summer hill (loop); burn — the kilns'
sulphur burning (loop: low roar, crackle); river — molten sulphur seething at 400 m (loop: slow thick bubbles over a roar);
steam, sparks — the Cyclops' signs; stream — the acid stream down the gorge (loop); drip — a drop into the puddle at 50 m;
donkey_0..1 — a bray; goat_0..1 — a bleat.
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


def pitch(d, k):
    return np.interp(np.arange(0, len(d) - 1, k), np.arange(len(d)), d)


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def highpass(x, f):
    return x - lowpass(x, f)


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


def tile(d, n):
    return np.tile(d, int(np.ceil(n / len(d))))[:n]


def lay(n, parts):
    out = np.zeros(n)
    for x, at in parts:
        i = int(at * SR)
        x = x[: max(0, n - i)]
        out[i:i + len(x)] += x
    return out


def write(path, d):
    # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    d9, d5, d2 = (os.path.join(src, x) for x in ("dl9", "dl5", "dl2"))
    out = lambda n, d: write(os.path.join(dst, n + ".ogg"), d)
    rng = np.random.default_rng(4)
    a1, a2 = load(os.path.join(d9, "s3589.ogg")), load(os.path.join(d9, "s3590.ogg"))
    # the giant's hammer: a strike slowed and dulled, the room's boom under it (kept in 80-400 Hz, which a phone plays)
    for k, (src_a, at) in enumerate([(a1, 0.10), (a1, 2.40), (a2, 0.14)]):
        hit = pitch(cut(src_a, at, at + 1.3), 0.45)
        n = len(hit) + int(0.6 * SR)
        t = np.arange(n) / SR
        boom = lowpass(rng.standard_normal(n), 160) * np.exp(-t * 3.5) * 9.0
        body = norm(lowpass(hit, 1400), 0.8)
        out("hammer_%d" % k, norm(fade(lay(n, [(body, 0.0), (norm(boom, 0.6), 0.0)]), 0.003, 0.8), 0.85))
    # the forge gate's ring: a strike slowed a little less, long ring
    ring = pitch(cut(a2, 1.18, 3.2), 0.62)
    out("ring", norm(fade(lowpass(ring, 2500), 0.003, 1.2), 0.8))
    # cicadas over the hot hill
    out("cicadas", norm(seam(cut(load(os.path.join(d9, "s2397.ogg")), 10, 32), 2.0), 0.8))
    # the kilns: sulphur burning low and steady, a soft roar under the crackle
    fire = load(os.path.join(d5, "fire.wav"))
    m = 15 * SR + int(1.5 * SR)
    roar = lowpass(rng.standard_normal(m), 260) * (1.0 + 0.3 * np.sin(np.linspace(0, 2 * np.pi * 4, m)))
    out("burn", norm(seam(norm(roar, 0.5) + norm(cut(fire, 8, 8 + m / SR), 0.55), 1.5), 0.8))
    # the river of molten sulphur: thick slow bubbles (slowed) over a deep roar
    bub = pitch(tile(load(os.path.join(d2, "water-splash-slime-sfx", "loop_bubbles_02.ogg")), 12 * SR), 0.55)
    m = len(bub)
    deep = lowpass(rng.standard_normal(m), 180) * (1.0 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 6, m)))
    out("river", norm(seam(norm(lowpass(bub, 1600), 0.6) + norm(deep, 0.5), 1.5), 0.8))
    # a jet of steam out of a crack (real hiss, muffled a little), and sparks: the fire's crackle, bright and short
    h = load(os.path.join(d2, "steam_hisses", "steam hisses - Marker #4.wav"))
    i = int(np.argmax(np.abs(h) > 0.1 * np.abs(h).max()))
    out("steam", norm(fade(lowpass(h[i:i + int(2.2 * SR)], 4500), 0.02, 0.8), 0.8))
    cr = highpass(cut(fire, 3, 4.6), 1500)
    out("sparks", norm(fade(cr * np.exp(-np.arange(len(cr)) / SR * 1.5), 0.005, 0.4), 0.8))
    # the acid stream down the gorge
    out("stream", norm(seam(cut(load(os.path.join(d9, "s2714.ogg")), 30, 56), 2.0), 0.8))
    # one drop into the puddle
    out("drip", norm(fade(cut(load(os.path.join(d9, "s1384.ogg")), 0.1, 0.75), 0.002, 0.25), 0.8))
    # the donkey and the goat
    for k, (f, a, b) in enumerate([("s1548", 0.55, 3.9), ("s1551", 1.8, 5.6)]):
        out("donkey_%d" % k, norm(fade(cut(load(os.path.join(d9, f + ".ogg")), a, b), 0.02, 0.4), 0.8))
    for k, f in enumerate(["s0279", "s0280"]):
        out("goat_%d" % k, norm(fade(load(os.path.join(d9, f + ".ogg")), 0.01, 0.15), 0.8))


if __name__ == "__main__":
    main()
