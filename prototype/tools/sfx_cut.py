"""Cuts the CC0 recordings for the board sounds that replaced the synthesised ones.

    py prototype/tools/sfx_cut.py <download dir> godot/assets/audio/sfx
    py prototype/tools/sfx_cut.py - godot/assets/audio/sfx          (only the level-end sounds)

<download dir> (see godot/assets/audio/CREDITS.md): bowl_ogg (BigSoundBank #1109), steam_hisses/ (bart),
water-splash-slime-sfx/ (rubberduck), bubbles-single1..2.wav (BMacZero), RPGsounds_Kenney/OGG/.
Makes: bowl_ping (the resonator: the bowl's settled ring, soft attack, ~3 s decay),
gas_0..2 (a gurgle with a muffled hiss of gas under it), and copies Kenney's bookPlace/bookFlip.
Then the level's end, baked here so the game does not synthesise it at the moment it ends (half a second of
GDScript): win (a plucked lute up D dorian, the open fifth left ringing, over the singing bowl) and lose (a slow
fall to the low D over the heavy bell slowed to 0.55; godot/assets/audio/sfx/impactBell_heavy_000.ogg).
Loudness as the old saxophone jingles had in the game (win -21 dB, lose -23 dB RMS).
"""
import os
import shutil
import sys

import numpy as np
import soundfile as sf

SR = 44100


def load(path):
    d, sr = sf.read(path, always_2d=True)
    d = d.mean(axis=1)
    if sr != SR:
        n = int(len(d) * SR / sr)
        d = np.interp(np.linspace(0, len(d) - 1, n), np.arange(len(d)), d)
    return d


def lowpass(x, f):
    a = 1 - np.exp(-2 * np.pi * f / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a * (x[i] - s)
        y[i] = s
    return y


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def write(path, d):
    # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


def trim(d, thr=0.01):
    idx = np.nonzero(np.abs(d) > thr * np.abs(d).max())[0]
    return d[idx[0]:idx[-1] + 1]


SYN = 22050   # the lute keeps the timbre it had at the game's synth rate (its decay depends on it)


def pluck(buf, f, at, dur, vol, bright=0.5, rng=np.random.default_rng(3)):
    """Karplus-Strong: a burst of noise in a delay line that loses its highs each pass"""
    n = max(2, int(SYN / f))
    line = np.zeros(n)
    lp = 0.0
    for j in range(n):
        lp += bright * ((rng.random() * 2 - 1) - lp)
        line[j] = lp
    i0, ns = int(at * SYN), int(dur * SYN)
    p = 0
    for i in range(ns):
        if i0 + i >= len(buf): break
        s = line[p]
        line[p] = (s + line[(p + 1) % n]) * 0.4985
        p = (p + 1) % n
        buf[i0 + i] += s * vol * 3.0 * min(1.0, max(0.0, (ns - i) / (0.15 * SYN)))


def sine(buf, f, at, dur, vol):
    i0, ns = int(at * SYN), int(dur * SYN)
    t = np.arange(min(ns, len(buf) - i0)) / SYN
    env = np.where(t < 0.008, t / 0.008, 0.0001 ** ((t - 0.008) / (dur - 0.008)))
    buf[i0:i0 + len(t)] += np.sin(2 * np.pi * f * t) * vol * env


def up(x, k=SR / SYN):
    return np.interp(np.arange(int(len(x) * k)) / k, np.arange(len(x)), x)


def rms_to(d, db):
    e = np.abs(d)
    idx = np.nonzero(e > e.max() * 0.05)[0]
    r = np.sqrt((d[idx[0]:idx[-1] + 1] ** 2).mean())
    d = d * (10 ** (db / 20) / r)
    return d * min(1.0, 0.89 / np.abs(d).max())   # never past -1 dBFS


def endings(dst):
    win = np.zeros(int(SYN * 2.8))
    for i, f in enumerate([146.8, 220.0, 293.7, 349.2, 440.0]):
        pluck(win, f, i * 0.11, 1.4, 0.11)
    for f in [146.8, 220.0, 293.7, 440.0]:
        pluck(win, f, 0.68, 2.0, 0.08)
    sine(win, 73.4, 0.68, 1.6, 0.04)
    bowl = load(os.path.join(dst, "bowl_ping.ogg"))
    w = up(win * 2.2)
    n = max(len(w), len(bowl))
    mix = np.zeros(n)
    mix[:len(w)] += w
    mix[:len(bowl)] += bowl * 10 ** (-9 / 20)
    write(os.path.join(dst, "win_lute.ogg"), rms_to(mix, -21.0))
    lose = np.zeros(int(SYN * 2.8))
    for i, f in enumerate([220.0, 174.6, 164.8, 146.8]):
        pluck(lose, f, i * 0.26, 1.2 if i < 3 else 2.0, 0.1, 0.35 if i == 3 else 0.5)
    sine(lose, 73.4, 0.78, 1.8, 0.05)
    bell = load(os.path.join(dst, "impactBell_heavy_000.ogg"))
    bell = np.interp(np.arange(0, len(bell) - 1, 0.55), np.arange(len(bell)), bell)   # pitch 0.55: slower, lower
    l = up(lose * 2.2)
    mix = np.zeros(max(len(l), len(bell)))
    mix[:len(l)] += l
    mix[:len(bell)] += bell * 10 ** (-14 / 20)
    write(os.path.join(dst, "lose_lute.ogg"), rms_to(mix, -23.0))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    if src == "-":
        endings(dst)
        return
    # the resonator: 3 s of the bowl's full ring, eased in, dying away
    bowl = load(os.path.join(src, "bowl_ogg"))
    seg = bowl[int(6.0 * SR):int(9.0 * SR)].copy()
    t = np.arange(len(seg)) / SR
    env = np.minimum(1.0, t / 0.06) * np.exp(-t / 0.75)
    write(os.path.join(dst, "bowl_ping.ogg"), norm(seg * env, 0.8))
    # gas: a gurgle on top of a short hiss, taken muffled and low so it reads as gas, not steam
    bubbles = [os.path.join(src, "water-splash-slime-sfx", "bubble_01.ogg"), os.path.join(src, "water-splash-slime-sfx", "bubble_02.ogg"),
               os.path.join(src, "bubbles-single2.wav")]
    hisses = [os.path.join(src, "steam_hisses", "steam hisses - Marker #%d.wav" % i) for i in (1, 2, 3)]
    for i, (b, h) in enumerate(zip(bubbles, hisses)):
        bb = norm(trim(load(b)), 0.8)
        hh = trim(load(h))[: int(0.9 * SR)]
        hh = lowpass(lowpass(hh, 2500), 2500)
        hh = norm(hh, 0.22) * np.minimum(1.0, np.arange(len(hh)) / (0.08 * SR)) * np.linspace(1, 0, len(hh)) ** 1.5
        n = max(len(bb) + int(0.05 * SR), len(hh))
        out = np.zeros(n)
        out[:len(hh)] += hh
        out[int(0.05 * SR):int(0.05 * SR) + len(bb)] += bb
        write(os.path.join(dst, "gas_%d.ogg" % i), norm(out, 0.8))
    for f in ["bookPlace1", "bookPlace2", "bookPlace3", "bookFlip1"]:
        shutil.copy(os.path.join(src, "RPGsounds_Kenney", "OGG", f + ".ogg"), os.path.join(dst, f + ".ogg"))


if __name__ == "__main__":
    main()
