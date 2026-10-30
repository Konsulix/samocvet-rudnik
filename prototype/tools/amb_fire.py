"""Fire Horizon's own sounds (FireView via MineAmb, the muffled Amb bus), all synthesized here (no downloads):

    py prototype/tools/amb_fire.py godot/assets/audio/amb/fire

Makes: hammer_0..2 (the giant's hammer far below: a muffled blow of iron on iron through the rock - its weight in
100-400 Hz, where a phone still plays, a short ring of the anvil over it, a rumble after), cicadas (loop: a chorus of
cicadas in the heat, pulsing in waves; kept low in pitch, the bus cuts above 2.2 kHz), burn (loop: the sulphur kilns -
a soft roar and the crackle of burning sulphur), sparks (a spray of sparks spitting out of a crack), wind (the cold
draught of the herald: a hollow whistling gust), ring (the forge gate open: a long ring of struck bronze), steam (a hiss
of steam out of a hot wall), river (loop: molten sulphur seething and blopping in its channel).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
rng = np.random.default_rng(11)


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def highpass(x, f):
    return x - lowpass(x, f)


def band(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.01, b=0.2):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    d[:na] *= np.linspace(0, 1, na)
    d[-nb:] *= np.linspace(1, 0, nb)
    return d


def seamless(d, sec=1.5):
    m = int(sec * SR)
    d = d.copy()
    d[:m] = d[:m] * np.linspace(0, 1, m) + d[-m:] * np.linspace(1, 0, m)
    return d[:-m]


def hammer(seed):
    r = np.random.default_rng(seed)
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    # the blow: a thud with its body at 110-260 Hz (a low "dong" the phone can play)
    f0 = 118 + seed * 9
    body = sum(a * np.sin(2 * np.pi * f0 * m * t + r.uniform(0, 6)) * np.exp(-t * d)
               for m, a, d in ((1.0, 1.0, 5.0), (1.52, 0.55, 7.0), (2.11, 0.35, 9.0), (2.94, 0.22, 12.0)))
    hit = lowpass(r.standard_normal(n), 900) * np.exp(-t * 45)
    # the anvil's ring, muffled by the rock: inharmonic partials 380-900 Hz, quick to die
    ring = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * d)
               for f, a, d in ((392 + seed * 13, 0.35, 6.0), (611, 0.22, 8.0), (873, 0.14, 11.0)))
    rumble = lowpass(r.standard_normal(n), 220) * np.clip(t / 0.05, 0, 1) * np.exp(-t * 1.6)
    d = body * 1.0 + hit * 0.9 + ring * 0.7 + rumble * 1.4
    return fade(norm(lowpass(d, 1800)), 0.002, 0.6)


def cicadas(sec=20.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i in range(5):
        f = 1450 + i * 160
        # each insect: a buzz (noise in a narrow band) chopped by its own pulse rate, swelling and fading in waves
        nz = band(rng.standard_normal(n), f - 90, f + 90)
        pulse = (0.5 + 0.5 * np.sin(2 * np.pi * (70 + i * 11) * t)) ** 3
        k = rng.integers(2, 5)
        swell = np.clip(np.sin(2 * np.pi * t * k / sec + rng.uniform(0, 6)), 0, 1) ** 1.5
        out += nz * pulse * (0.25 + 0.75 * swell)
    return norm(seamless(out), 0.55)


def burn(sec=16.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    roar = lowpass(rng.standard_normal(n), 260) * (0.8 + 0.2 * np.sin(2 * np.pi * t * 3 / sec))
    cr = np.zeros(n)
    for _ in range(int(sec * 14)):
        i = rng.integers(0, n - 800)
        L = rng.integers(60, 500)
        cr[i:i + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * rng.uniform(0.3, 1.0)
    cr = band(cr, 500, 2600)
    return norm(seamless(roar * 1.2 + cr * 0.6), 0.6)


def sparks():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    d = np.zeros(n)
    for _ in range(120):
        i = int(rng.uniform(0, 0.9) ** 1.6 * n * 0.8)
        L = rng.integers(40, 240)
        d[i:i + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 5)) * rng.uniform(0.2, 1.0)
    hiss = band(rng.standard_normal(n), 800, 2400) * np.exp(-t * 3) * 0.25
    return fade(norm(band(d, 600, 2600) + hiss), 0.002, 0.3)


def wind():
    n = int(4.5 * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * t / t[-1]) ** 1.5
    nz = rng.standard_normal(n)
    # a hollow whistle: noise through a resonance that slides up and down
    f = 520 + 260 * np.sin(2 * np.pi * t / 3.1) + 120 * np.sin(2 * np.pi * t / 1.3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * band(nz, 300, 900) * 0.6
    air = band(nz, 200, 1600)
    return fade(norm((tone + air * 0.7) * env), 0.05, 0.6)


def ring():
    n = int(6.0 * SR)
    t = np.arange(n) / SR
    parts = ((174, 1.0, 0.5), (281, 0.7, 0.6), (437, 0.5, 0.8), (622, 0.35, 1.0), (889, 0.2, 1.4), (1183, 0.12, 1.9))
    d = sum(a * np.sin(2 * np.pi * f * t * (1 + 0.0015 * np.sin(2 * np.pi * 4.5 * t))) * np.exp(-t * k) for f, a, k in parts)
    hit = lowpass(rng.standard_normal(n), 1500) * np.exp(-t * 60)
    return fade(norm(d + hit * 0.6), 0.002, 1.0)


def steam():
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.08, 0, 1) * np.exp(-t * 1.1)
    return fade(norm(band(rng.standard_normal(n), 900, 2600) * env), 0.005, 0.4)


def river(sec=14.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    seethe = band(rng.standard_normal(n), 120, 700) * 0.5
    blops = np.zeros(n)
    for _ in range(int(sec * 3)):
        i = rng.integers(0, n - SR // 3)
        L = int(rng.uniform(0.06, 0.18) * SR)
        tt = np.arange(L) / SR
        f = rng.uniform(140, 320) * (1 + 1.5 * tt / tt[-1])
        blops[i:i + L] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 18) * rng.uniform(0.4, 1.0)
    return norm(seamless(seethe + blops), 0.6)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    def w(name, d):
        # in small blocks: libsndfile's vorbis writer overflows the stack on one big write
        with sf.SoundFile(os.path.join(out, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(d), 4096):
                f.write(d[i:i + 4096].astype(np.float32))
        print(name, round(len(d) / SR, 2), "s")
    for i in range(3):
        w("hammer_%d" % i, hammer(i))
    w("cicadas", cicadas())
    w("burn", burn())
    w("sparks", sparks())
    w("wind", wind())
    w("ring", ring())
    w("steam", steam())
    w("river", river())


if __name__ == "__main__":
    main()
