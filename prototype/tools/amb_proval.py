"""Proval's sounds (mine 5, the polar coal settlement over the funnel; IceView / IceSounds), cut from recordings in the
public domain or CC0 on Wikimedia Commons, plus a little synthesis:

    py prototype/tools/amb_proval.py <scratch> godot/assets/audio/amb/ice

<scratch>: wind.ogg - "Howling wind.ogg" (CC0); howl.mp3 - "Jem howls.ogg" (public domain, the transcoded mp3);
piano.oga - "Chopin Nocturne Op.27 No.1.oga" (public domain); ice.mp3 - "Bones breaking wood fire ice crackling.ogg"
(public domain); accordion.ogg - "Accordion registers.ogg" (public domain).
wind - the polar wind over the settlement (loop); gust_0..2 - a blizzard gust sweeping down into the funnel;
howl_0..1 - a sled dog howling; piano - the culture palace's piano heard through its walls (loop, muffled);
accordion - the old man's bayan by the barracks (loop); crack_0..2 - ice cracking (the frozen dwarf, the gate, the
funnel shaking); hum - the power station's generator (loop, 100-300 Hz, which a phone plays); heart - a double beat from
far below (the four-coloured heart); gate - a deep cold ring of the dwarven gate opening.
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


def rms(d, win=0.25):
    n = int(win * SR)
    m = len(d) // n
    return np.sqrt((d[:m * n].reshape(m, n) ** 2).mean(1)), win


def write(path, d):
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


def echo(d, delays=((0.11, 0.35), (0.23, 0.22), (0.41, 0.14))):
    """a hard cold room: a few early reflections"""
    out = np.concatenate([d, np.zeros(int(0.5 * SR))])
    for t, g in delays:
        i = int(t * SR)
        out[i:i + len(d)] += d * g
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    out = lambda n, d: write(os.path.join(dst, n + ".ogg"), d)
    rng = np.random.default_rng(5)
    # the wind: the steadiest 24 s of the recording as the loop; the three strongest swells as gusts
    w = load(os.path.join(src, "wind.ogg"))
    e, win = rms(w)
    n24 = int(24 / win)
    best = min(range(0, len(e) - n24), key=lambda i: np.std(e[i:i + n24]) / max(1e-6, np.mean(e[i:i + n24])))
    out("wind", norm(seam(cut(w, best * win, best * win + 25.5), 1.5), 0.75))
    sm = np.convolve(e, np.ones(8) / 8, "same")
    picks = []
    for i in np.argsort(-sm):
        if all(abs(i - j) > 24 for j in picks):
            picks.append(int(i))
        if len(picks) == 3: break
    for k, i in enumerate(sorted(picks)):
        g = cut(w, max(0.0, i * win - 2.2), i * win + 2.0)
        env = np.sin(np.linspace(0, np.pi, len(g))) ** 0.8
        out("gust_%d" % k, norm(fade(g * env, 0.2, 0.6), 0.85))
    # a sled dog's howl, and a second one lower and further off
    h = load(os.path.join(src, "howl.mp3"))
    out("howl_0", norm(fade(h, 0.02, 0.5), 0.8))
    out("howl_1", norm(fade(lowpass(pitch(h, 0.88), 2500), 0.02, 0.5), 0.7))
    # the piano through the culture palace's walls: muffled, a little room on it
    p = load(os.path.join(src, "piano.oga"))
    out("piano", norm(seam(echo(lowpass(p, 1800)), 2.5), 0.7))
    # the bayan: its chords, a little muffled
    a = load(os.path.join(src, "accordion.ogg"))
    out("accordion", norm(seam(lowpass(a, 3500), 1.5), 0.7))
    # ice cracking: the three sharpest snaps of the recording, each with a tail
    c = load(os.path.join(src, "ice.mp3"))
    hp = highpass(c, 1200)
    ce, cw = rms(hp, 0.05)
    snaps = []
    for i in np.argsort(-ce):
        if all(abs(i - j) > 30 for j in snaps):
            snaps.append(int(i))
        if len(snaps) == 3: break
    for k, i in enumerate(sorted(snaps)):
        s = cut(c, max(0.0, i * cw - 0.05), i * cw + 1.1)
        out("crack_%d" % k, norm(fade(echo(s, ((0.07, 0.3), (0.16, 0.18))), 0.004, 0.5), 0.85))
    # the generator: a low hum with its harmonics in 100-300 Hz and a little brush crackle
    n = 8 * SR
    t = np.arange(n) / SR
    hum = sum(np.sin(2 * np.pi * f * t + ph) * g for f, ph, g in ((100, 0.0, 0.6), (150, 1.0, 0.35), (200, 2.0, 0.45), (300, 0.5, 0.18)))
    hum *= 1.0 + 0.05 * np.sin(2 * np.pi * 0.5 * t)
    hum += highpass(rng.standard_normal(n), 3000) * 0.04
    out("hum", norm(hum, 0.6))
    # the heart far below: lub-dub, a deep thump (kept above 90 Hz) with a cold ring on it
    beat = np.zeros(int(1.6 * SR))
    for at, g in ((0.0, 1.0), (0.28, 0.7)):
        m = int(0.45 * SR)
        tt = np.arange(m) / SR
        th = np.sin(2 * np.pi * (140 - 50 * tt / 0.45) * tt) * np.exp(-tt * 9) * g
        th += lowpass(rng.standard_normal(m), 400) * np.exp(-tt * 14) * 0.5 * g
        i = int(at * SR)
        beat[i:i + m] += th
    tt = np.arange(len(beat)) / SR
    beat += np.sin(2 * np.pi * 523 * tt) * np.exp(-tt * 3) * 0.05 + np.sin(2 * np.pi * 784 * tt) * np.exp(-tt * 4) * 0.03
    out("heart", norm(fade(beat, 0.001, 0.4), 0.8))
    # the dwarven gate: a deep stone groan sliding down, with a ring of ice over it
    n = int(3.5 * SR)
    tt = np.arange(n) / SR
    f = 130 - 30 * tt / 3.5
    groan = np.sin(2 * np.pi * np.cumsum(f) / SR) * (1 - np.exp(-tt * 3)) * np.exp(-tt * 0.6)
    groan += lowpass(rng.standard_normal(n), 300) * np.exp(-tt * 0.8) * 0.5
    ring = sum(np.sin(2 * np.pi * fr * tt) * np.exp(-tt * d) * g for fr, d, g in ((880, 1.2, 0.08), (1320, 1.6, 0.05), (1975, 2.2, 0.03)))
    out("gate", norm(fade(groan + ring, 0.05, 0.8), 0.8))


if __name__ == "__main__":
    main()
