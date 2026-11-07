"""Deathless Barrow's own sounds (mine 7, Koschei's barrow in the steppe bog; BarrowView / KoscheiSounds), synthesized here.
Everything else the screen plays is another mine's file, used as it is (the wind and its gusts from Proval, crows, hooves,
the snort and the creak from Copper Mountain, the frogs and the drone from Spider Hollow, the squelch from the cove):

    py prototype/tools/amb_barrow.py godot/assets/audio/amb/barrow

gusli_0..3  - the blind singer's gusli: a few plucked strings, a falling phrase (Karplus-Strong, wooden body)
chain_0..2  - rusty chain links knocking and grinding
scurry      - a hare's quick thumps over earth
heart       - one slow double beat deep in the stone (the egg)
laugh       - a dry breathy rattle under the ground (the needle's chains drawn taut)
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def bandpass(x, lo, hi):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    X[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(X, 2 * n)[:n]


def norm(d, peak):
    m = np.max(np.abs(d)) or 1.0
    return d / m * peak


def save(name, d, peak=0.8):
    d = norm(d, peak)
    f = int(0.01 * SR)
    d[:f] *= np.linspace(0, 1, f)
    d[-f:] *= np.linspace(1, 0, f)
    sf.write(os.path.join(OUT, name + ".ogg"), d.astype(np.float32), SR, format="OGG", subtype="VORBIS")


def pluck(freq, sec, bright=0.5):
    """Karplus-Strong string"""
    n = int(sec * SR)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    buf = lowpass(np.concatenate([buf, buf]), 2000 + 5000 * bright)[:p]
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % p]
        out[i] = v
        buf[i % p] = 0.996 * 0.5 * (v + buf[(i + 1) % p])
    return out


# the gusli: a modal scale (Dorian on D), a short falling phrase of 4-6 plucks, the wooden body a soft low resonance
SCALE = [293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3, 587.3]
for k in range(4):
    sec = 3.6
    out = np.zeros(int(sec * SR))
    notes = sorted(rng.choice(len(SCALE), 5, replace=False), reverse=True)
    at = 0.0
    for j, ni in enumerate(notes):
        s = pluck(SCALE[ni] * (0.5 if k % 2 else 1.0), 2.4, 0.4 + 0.2 * rng.random())
        i0 = int(at * SR)
        out[i0:i0 + len(s)] += s[:len(out) - i0] * (1.0 - 0.1 * j)
        at += rng.uniform(0.22, 0.5)
    body = lowpass(out, 900) * 0.4
    save("gusli_%d" % k, out + body, 0.6)

# a chain: several metal clinks (decaying inharmonic partials) and a grinding scrape
for k in range(3):
    sec = 1.4
    out = np.zeros(int(sec * SR))
    at = 0.0
    for j in range(rng.integers(3, 6)):
        tt = t_(0.35)
        f0 = rng.uniform(1400, 2600)
        s = sum(np.sin(2 * np.pi * f0 * r * tt) * np.exp(-tt * (18 + 10 * r)) for r in (1.0, 1.47, 2.09, 2.76))
        s *= rng.uniform(0.4, 1.0)
        i0 = int(at * SR)
        out[i0:i0 + len(s)] += s[:len(out) - i0]
        at += rng.uniform(0.06, 0.22)
    scrape = bandpass(rng.normal(0, 1, len(out)), 600, 3000) * np.exp(-t_(sec) * 3) * 0.25
    save("chain_%d" % k, out + scrape, 0.7)

# a hare over earth: quick soft thumps, getting away
sec = 1.6
out = np.zeros(int(sec * SR))
at = 0.0
for j in range(9):
    tt = t_(0.12)
    s = lowpass(rng.normal(0, 1, len(tt)), 300) * np.exp(-tt * 40) + np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 30)
    i0 = int(at * SR)
    out[i0:i0 + len(s)] += s[:len(out) - i0] * (1.0 - j * 0.09)
    at += 0.14 if j % 2 else 0.05
save("scurry", out, 0.6)

# the egg's heart: lub-dub, very low, with a hollow ring
tt = t_(1.6)
beat = lambda at, a: np.where(tt >= at, np.sin(2 * np.pi * 48 * (tt - at)) * np.exp(-(tt - at) * 12) * a, 0)
h = beat(0.05, 1.0) + beat(0.33, 0.7)
ring = np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 3) * 0.08
save("heart", h + ring, 0.8)

# a laugh from under the ground: breathy noise pulses, falling, through a hollow low formant
sec = 2.6
tt = t_(sec)
env = np.zeros_like(tt)
for j in range(7):
    at = 0.15 + j * 0.28
    env += np.exp(-((tt - at) / 0.07) ** 2) * (1.0 - j * 0.1)
noise = rng.normal(0, 1, len(tt))
voice = bandpass(noise, 250, 900) + 0.4 * np.sin(2 * np.pi * (110 - 20 * tt / sec) * tt)
save("laugh", lowpass(voice * env, 1200), 0.7)
print("ok")
