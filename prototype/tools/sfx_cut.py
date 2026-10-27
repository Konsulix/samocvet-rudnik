"""Cuts the CC0 recordings for the board sounds that replaced the synthesised ones.

    py prototype/tools/sfx_cut.py <download dir> godot/assets/audio/sfx

<download dir> (see godot/assets/audio/CREDITS.md): bowl_ogg (BigSoundBank #1109), steam_hisses/ (bart),
water-splash-slime-sfx/ (rubberduck), bubbles-single1..2.wav (BMacZero), RPGsounds_Kenney/OGG/.
Makes: bowl_ping (the resonator: the bowl's settled ring, soft attack, ~3 s decay),
gas_0..2 (a gurgle with a muffled hiss of gas under it), and copies Kenney's bookPlace/bookFlip.
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


def main():
    src, dst = sys.argv[1], sys.argv[2]
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
