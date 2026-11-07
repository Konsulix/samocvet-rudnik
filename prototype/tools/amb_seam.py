"""Whispering Seam's own sounds (mine 8, the coal mine under the chalk, Shubin and the canary; SeamView / SeamSounds).
The canaries are RECORDINGS: songs of one domestic canary (M1) from Giraudon, Trouvain, Cazala, Del Negro & Hinaut,
"Labeled songs of domestic canary M1 (Serinus canaria)", Zenodo 2021, doi:10.5281/zenodo.4736597, CC BY 4.0 (credited
in godot/assets/audio/CREDITS.md). The rest is synthesized here; other mines' files are used as they are (the furnace's
roar and the cat from Copper Mountain, the river lapping at the pier from the cove, the carts and the winch, the cave).

    py prototype/tools/amb_seam.py godot/assets/audio/amb/seam <dir with the canary's wav files>

canary_0..5 - a canary's song phrase (the recordings: trimmed to a phrase, the chamber's hum cut off)
cough_0..2 and knock are RECORDINGS too when their sources are given (7.11, polishing: the synthesized ones sounded false):
  the cough - "old man cough" by AntumDeluge, OpenGameArt, CC0 (a coughing fit, the start of it, the small coughs after),
  lower, through a gallery's echo; the knock - Kenney's impactPlank_medium_000 (CC0, already in the game) three times
    py prototype/tools/amb_seam.py <out> <canary wav dir> <old-man-cough.flac> <impactPlank_medium_000.ogg>
cheep       - the silenced canary's one small call
cough_0..2  - Shubin's cough out of the dark: a hoarse old man's cough deep in a gallery
knock       - three knocks on a timber prop (Shubin's warning)
hiss        - firedamp seeping from the coal: a soft "shu-shu" loop
flame       - the gas lit under the roof: a soft blue whoomp running along
bell        - the pit bottom's signal bell (one ring)
whistle     - the steamer's whistle on the river, far off
"""
import glob
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
OUT = sys.argv[1]
SRC = sys.argv[2] if len(sys.argv) > 2 else ""
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(8)


def t_(sec):
    return np.arange(int(sec * SR)) / SR


def bandpass(x, lo, hi):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    X[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(X, 2 * n)[:n]


def lowpass(x, f):
    return bandpass(x, 0, f)


def norm(d, peak):
    m = np.max(np.abs(d)) or 1.0
    return d / m * peak


def fade(d, a=0.01, b=0.01):
    fa, fb = int(a * SR), int(b * SR)
    d[:fa] *= np.linspace(0, 1, fa)
    d[-fb:] *= np.linspace(1, 0, fb)
    return d


def save(name, d, peak=0.8, a=0.01, b=0.01):
    d = fade(norm(d, peak), a, b)
    sf.write(os.path.join(OUT, name + ".ogg"), d.astype(np.float32), SR, format="OGG", subtype="VORBIS")


def resample(x, sr0):
    n = int(len(x) * SR / sr0)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


# ---------------------------------------------------------------- the canary (recordings)
if SRC:
    files = sorted(glob.glob(os.path.join(SRC, "*.wav")))
    k = 0
    for f in files:
        x, sr0 = sf.read(f)
        if x.ndim > 1: x = x.mean(1)
        x = bandpass(resample(x, sr0), 1400, 12000)
        # the loudest stretch of song: an envelope, the longest run over a threshold, 3..7 s of it
        env = np.convolve(np.abs(x), np.ones(int(0.05 * SR)) / (0.05 * SR), "same")
        on = env > env.max() * 0.12
        best, cur, start, bs = 0, 0, 0, 0
        for i in range(0, len(on), 160):
            if on[i]:
                if cur == 0: start = i
                cur += 160
                if cur > best: best, bs = cur, start
            elif cur and not on[min(len(on) - 1, i + int(0.25 * SR))]:
                cur = 0
        seg = x[max(0, bs - int(0.05 * SR)): bs + min(best, int(7 * SR)) + int(0.15 * SR)]
        if len(seg) < 1.5 * SR:
            continue
        save("canary_%d" % k, seg, 0.7, 0.03, 0.25)
        print("canary_%d" % k, os.path.basename(f), round(len(seg) / SR, 1))
        k += 1
        if k == 6: break
    # one small call, cut from the start of a song (the first syllable), softened
    x, sr0 = sf.read(files[0])
    if x.ndim > 1: x = x.mean(1)
    x = bandpass(resample(x, sr0), 1400, 10000)
    env = np.convolve(np.abs(x), np.ones(int(0.02 * SR)) / (0.02 * SR), "same")
    i0 = int(np.argmax(env > env.max() * 0.2))
    save("cheep", x[max(0, i0 - 400): i0 + int(0.18 * SR)] * np.hanning(int(0.18 * SR) + min(400, i0))[:len(x[max(0, i0 - 400): i0 + int(0.18 * SR)])], 0.5)

# ---------------------------------------------------------------- Shubin's cough: hoarse bursts through a chest formant
for k in range(3):
    sec = 2.2
    tt = t_(sec)
    out = np.zeros_like(tt)
    at = 0.08
    n = rng.integers(2, 5)
    for j in range(n):
        ln = rng.uniform(0.18, 0.32)
        e = np.where((tt >= at) & (tt < at + ln), 1.0, 0.0) * np.exp(-np.maximum(tt - at, 0) * rng.uniform(7, 11))
        e *= np.minimum(1, np.maximum(tt - at, 0) / 0.012)
        noise = rng.normal(0, 1, len(tt))
        rasp = 1 + 0.6 * np.sin(2 * np.pi * rng.uniform(28, 40) * tt)      # the rattle in the chest
        f0 = rng.uniform(95, 125) * (1 - 0.25 * np.maximum(tt - at, 0))
        voiced = np.sin(2 * np.pi * np.cumsum(f0) / SR) * 0.35
        out += e * (bandpass(noise, 300, 1800) * rasp + voiced) * (1.0 - 0.15 * j)
        at += ln + rng.uniform(0.05, 0.22)
    out = lowpass(out, 2200)
    # a gallery's echo
    echo = np.zeros_like(out)
    for d, g in ((0.11, 0.35), (0.23, 0.2), (0.41, 0.1)):
        i = int(d * SR); echo[i:] += out[:-i] * g
    save("cough_%d" % k, out + echo, 0.7)

# ---------------------------------------------------------------- three knocks on a prop
sec = 2.0
tt = t_(sec)
out = np.zeros_like(tt)
for j, at in enumerate((0.05, 0.62, 1.19)):
    s = np.maximum(tt - at, 0)
    m = tt >= at
    out += m * (np.sin(2 * np.pi * 180 * s) * np.exp(-s * 30) + np.sin(2 * np.pi * 410 * s) * np.exp(-s * 45) * 0.5
                + lowpass(rng.normal(0, 1, len(tt)), 2500) * np.exp(-s * 90) * 0.6)
echo = np.zeros_like(out)
for d, g in ((0.09, 0.4), (0.2, 0.22)):
    i = int(d * SR); echo[i:] += out[:-i] * g
save("knock", out + echo, 0.75)

# ---------------------------------------------------------------- firedamp: a soft hiss loop, breathing "shu-shu"
sec = 6.0
tt = t_(sec)
noise = rng.normal(0, 1, len(tt))
breath = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 3.0) ** 2          # two breaths in the loop: it loops seamlessly
hiss = bandpass(noise, 2500, 7000) * breath
save("hiss", hiss, 0.5, 0.002, 0.002)

# ---------------------------------------------------------------- the gas lit: a low soft whoomp and a rushing flame
sec = 2.4
tt = t_(sec)
env = np.minimum(1, tt / 0.08) * np.exp(-tt * 1.6)
whoomp = np.sin(2 * np.pi * (70 - 25 * tt) * tt) * np.exp(-tt * 4)
rush = bandpass(rng.normal(0, 1, len(tt)), 200, 1600) * env
save("flame", whoomp * 0.8 + rush, 0.75)

# ---------------------------------------------------------------- the signal bell: one ring, brass, a few partials
sec = 2.5
tt = t_(sec)
bell = sum(a * np.sin(2 * np.pi * 820 * r * tt) * np.exp(-tt * dk) for r, a, dk in
           ((1.0, 1.0, 1.6), (2.32, 0.5, 2.4), (2.98, 0.35, 3.0), (4.16, 0.2, 4.5), (0.5, 0.3, 1.2)))
bell += bandpass(rng.normal(0, 1, len(tt)), 2000, 6000) * np.exp(-tt * 60) * 0.3
save("bell", bell, 0.7)

# ---------------------------------------------------------------- the steamer's whistle far off on the river
sec = 3.4
tt = t_(sec)
env = np.minimum(1, tt / 0.25) * np.minimum(1, (sec - 0.15 - tt) / 0.8).clip(0, 1)
f = 290 * (1 + 0.004 * np.sin(2 * np.pi * 5 * tt))
tone = sum(a * np.sin(2 * np.pi * f * r * tt) for r, a in ((1, 1), (1.26, 0.8), (1.5, 0.6), (2, 0.3), (3, 0.12)))
air = bandpass(rng.normal(0, 1, len(tt)), 500, 3000) * 0.12
far = lowpass((tone + air) * env, 1800)
echo = np.zeros_like(far)
for d, g in ((0.6, 0.3), (1.3, 0.15)):
    i = int(d * SR); echo[i:] += far[:-i] * g
save("whistle", far + echo, 0.6)

# ---------------------------------------------------------------- the recorded cough and knocks (they replace the synthesized)
def echo(x, taps=((0.11, 0.35), (0.23, 0.2), (0.41, 0.1))):
    out = np.concatenate([x, np.zeros(int(0.6 * SR))])
    y = out.copy()
    for dl, g in taps:
        i = int(dl * SR); y[i:] += out[:-i] * g
    return y

if len(sys.argv) > 4:
    x, sr0 = sf.read(sys.argv[3])
    if x.ndim > 1: x = x.mean(1)
    x = resample(x, sr0 * 1.08)          # a little lower: an old man, far down a gallery
    for k, (a, b) in enumerate(((0.0, 2.25), (0.0, 1.25), (2.4, 4.0))):
        seg = lowpass(x[int(a * SR): int(b * SR)], 3200)
        save("cough_%d" % k, echo(seg), 0.75, 0.005, 0.3)
    p_, sr1 = sf.read(sys.argv[4])
    if p_.ndim > 1: p_ = p_.mean(1)
    p_ = lowpass(resample(p_, sr1 * 1.15), 2600)
    out = np.zeros(int(2.0 * SR))
    for j, at in enumerate((0.05, 0.62, 1.19)):
        i = int(at * SR); n = min(len(p_), len(out) - i)
        out[i:i + n] += p_[:n] * (1.0 - 0.1 * j)
    save("knock", echo(out, ((0.09, 0.4), (0.2, 0.22), (0.37, 0.1))), 0.75)
print("ok")
