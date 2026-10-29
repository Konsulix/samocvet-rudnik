"""Whalebone Cove's storm (SeaView._storm), synthesized here:

    py prototype/tools/amb_storm.py godot/assets/audio/amb/sea

Makes: thunder_near_0..1 (a bolt close by: a tearing crack, a slam, then a long rolling rumble), thunder_far_0..2 (far
out at sea: no crack, a low rumble rolling in and out), elmo (St. Elmo's fire: a thin electric buzz with crackles).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def highpass(x, f):
    return x - lowpass(x, f)


def norm(d, peak=0.85):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.005, b=0.4):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    d[:na] *= np.linspace(0, 1, na)
    d[-nb:] *= np.linspace(1, 0, nb)
    return d


def rumble(r, n, t, rolls, f=140):
    """a low rumble swelling in a few uneven rolls"""
    env = np.zeros(n)
    for at, w, k in rolls:
        env += k * np.exp(-((t - at) / w) ** 2)
    noise = lowpass(lowpass(r.standard_normal(n), f), f * 1.4)
    return noise * env


def near(seed):
    r = np.random.default_rng(seed)
    n = int(6.5 * SR)
    t = np.arange(n) / SR
    # the crack: a burst of bright noise torn into fragments
    frag = (r.random(n) < 0.004).astype(float)
    frag = lowpass(frag, 800) * 60
    crack = highpass(r.standard_normal(n), 1200) * np.exp(-t * 9) * (0.6 + np.clip(frag, 0, 1))
    slam = lowpass(r.standard_normal(n), 220) * np.exp(-t * 4.5)
    roll = rumble(r, n, t, [(0.6, 0.5, 1.0), (1.6, 0.8, 0.8), (3.0, 1.2, 0.6), (4.5, 1.0, 0.35)])
    return fade(norm(crack * 0.8 + slam * 3.0 + roll * 2.2), 0.002, 1.2)


def far(seed):
    r = np.random.default_rng(seed)
    n = int(7.0 * SR)
    t = np.arange(n) / SR
    rolls = [(1.2 + r.uniform(-0.3, 0.3), 0.9, 0.7), (2.6 + r.uniform(-0.3, 0.3), 1.1, 1.0), (4.4, 1.3, 0.6)]
    return fade(norm(rumble(r, n, t, rolls, 90), 0.75), 0.4, 1.5)


def elmo():
    r = np.random.default_rng(5)
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.3 + np.sin(2 * np.pi * 240 * t) * 0.3
    buzz = lowpass(buzz, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * t) ** 2)
    cr = (r.random(n) < 0.0015).astype(float)
    cr = highpass(lowpass(cr * 40, 6000), 1500)
    env = np.clip(t / 0.2, 0, 1) * np.clip((2.4 - t) / 0.6, 0, 1)
    return fade(norm((buzz * 0.6 + cr) * env, 0.6), 0.01, 0.3)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)

    def w(name, d):
        # in small blocks: libsndfile's vorbis writer overflows the stack on one big write
        with sf.SoundFile(os.path.join(out, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(d), 4096):
                f.write(d[i:i + 4096].astype(np.float32))
        print(name, round(len(d) / SR, 2), "s")
    for i in range(2):
        w("thunder_near_%d" % i, near(21 + i))
    for i in range(3):
        w("thunder_far_%d" % i, far(31 + i))
    w("elmo", elmo())


if __name__ == "__main__":
    main()
