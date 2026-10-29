"""Whalebone Cove's own sounds (SeaView via MineAmb, the muffled Amb bus), all synthesized here (no downloads):

    py prototype/tools/amb_sea.py godot/assets/audio/amb/sea

Makes: surf (loop: the sea breathing against the cliff - brown noise in slow swells, the hiss of the foam on top),
crash_0..2 (a big wave breaking on the rocks: a thump and a long hiss of spray), deep (a groan from far below: two low
detuned tones sliding down under rumble), squelch (something wet slipping in a crack), gull_0..2 (a herring gull's cry:
a falling, harsh, vibrato call, twice or three times).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
rng = np.random.default_rng(7)


def lowpass(x, f):
    # a one-pole low-pass applied in the frequency domain (fast, no scipy)
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def highpass(x, f):
    return x - lowpass(x, f)


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.01, b=0.2):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    d[:na] *= np.linspace(0, 1, na)
    d[-nb:] *= np.linspace(1, 0, nb)
    return d


def brown(n):
    w = rng.standard_normal(n)
    b = np.cumsum(w)
    b -= lowpass(b, 2.0)
    return b / np.abs(b).max()


def surf(sec=24.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    body = lowpass(brown(n), 500)
    hiss = highpass(lowpass(rng.standard_normal(n), 3500), 900)
    # swells: three slow waves of different lengths, whole numbers of periods in the loop so it wraps
    env = 0.55 + 0.25 * np.sin(2 * np.pi * t * 3 / sec) + 0.2 * np.sin(2 * np.pi * t * 5 / sec + 1.0)
    foam = np.clip(np.sin(2 * np.pi * t * 4 / sec + 0.4), 0, 1) ** 3
    d = body * env + hiss * (0.12 + 0.35 * foam)
    # make the loop seamless: cross-fade the end into the start
    m = int(1.5 * SR)
    d[:m] = d[:m] * np.linspace(0, 1, m) + d[-m:] * np.linspace(1, 0, m)
    return norm(d[:-m], 0.6)


def crash(seed):
    r = np.random.default_rng(seed)
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    thump = lowpass(r.standard_normal(n), 180) * np.exp(-t * 7)
    spray = highpass(lowpass(r.standard_normal(n), 5000 + seed * 300), 700) * (np.clip(t / 0.08, 0, 1) * np.exp(-t * 1.6))
    rumble = lowpass(r.standard_normal(n), 400) * np.exp(-t * 2.5)
    return fade(norm(thump * 3.0 + spray * 0.9 + rumble * 1.5), 0.005, 0.5)


def deep():
    n = int(4.0 * SR)
    t = np.arange(n) / SR
    f = 46 - 10 * t / 4.0
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.6 * np.sin(ph * 1.02 + 0.3) + 0.3 * np.sin(ph * 2.01)
    env = np.clip(t / 0.8, 0, 1) * np.clip((4.0 - t) / 1.5, 0, 1)
    rumble = lowpass(rng.standard_normal(n), 120)
    return fade(norm(tone * env * (1 + 0.3 * np.sin(2 * np.pi * 3 * t)) + rumble * env * 2.0, 0.85), 0.05, 0.6)


def squelch():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(5):
        at = 0.06 + k * 0.14 + rng.uniform(-0.03, 0.03)
        i = int(at * SR)
        m = int(0.12 * SR)
        tt = np.arange(m) / SR
        f = 900 * np.exp(-tt * 14) + 160
        g = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 30)
        g += lowpass(rng.standard_normal(m), 1500) * np.exp(-tt * 40) * 0.5
        out[i:i + m] += g[:max(0, min(m, n - i))]
    return fade(norm(out, 0.7), 0.002, 0.1)


def gull(seed):
    r = np.random.default_rng(seed)
    calls = []
    for k in range(2 + seed % 2):
        d = r.uniform(0.28, 0.42)
        n = int(d * SR)
        t = np.arange(n) / SR
        f0 = r.uniform(1150, 1350)
        f = f0 * (1.0 + 0.25 * np.exp(-t * 18)) * (1 - 0.35 * t / d) * (1 + 0.025 * np.sin(2 * np.pi * 28 * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        # harsh: odd harmonics and a little noise
        s = np.sin(ph) + 0.55 * np.sin(3 * ph) + 0.3 * np.sin(5 * ph) + 0.2 * np.sin(2 * ph)
        s += highpass(r.standard_normal(n), 1500) * 0.15
        env = np.clip(t / 0.03, 0, 1) * np.clip((d - t) / 0.12, 0, 1)
        calls.append(s * env)
        calls.append(np.zeros(int(r.uniform(0.08, 0.16) * SR)))
    return fade(norm(lowpass(np.concatenate(calls), 4500), 0.6), 0.005, 0.05)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)

    def w(name, d):
        # in small blocks: libsndfile's vorbis writer overflows the stack on one big write
        with sf.SoundFile(os.path.join(out, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(d), 4096):
                f.write(d[i:i + 4096].astype(np.float32))
        print(name, round(len(d) / SR, 2), "s")
    w("surf", surf())
    for i in range(3):
        w("crash_%d" % i, crash(11 + i))
        w("gull_%d" % i, gull(3 + i))
    w("deep", deep())
    w("squelch", squelch())


if __name__ == "__main__":
    main()
