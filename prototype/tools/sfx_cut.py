"""Cuts the CC0 recordings for the board sounds that replaced the synthesised ones.

    py prototype/tools/sfx_cut.py <download dir> godot/assets/audio/sfx
    py prototype/tools/sfx_cut.py - godot/assets/audio/sfx          (only the level-end sounds)

<download dir> (see godot/assets/audio/CREDITS.md): bowl_ogg (BigSoundBank #1109), steam_hisses/ (bart),
water-splash-slime-sfx/ (rubberduck), bubbles-single1..2.wav (BMacZero), RPGsounds_Kenney/OGG/.
Makes: bowl_ping (the resonator: the bowl's settled ring, soft attack, ~3 s decay),
gas_0..2 (a gurgle with a muffled hiss of gas under it), and copies Kenney's bookPlace/bookFlip.
Then the level's end (`-` as the download dir: only these), built from sounds already in the game:
win_geode (a geode splits: the stone cracks, crystals ring up one after another, the singing bowl a fifth up hums
under them) and lose_rockfall (rock comes down, the bowl an octave down and muffled, the heavy bell at half speed).
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


def pitch(d, k):
    """resampled: k > 1 higher and shorter, k < 1 lower and longer"""
    return np.interp(np.arange(0, len(d) - 1, k), np.arange(len(d)), d)


def lay(parts):
    """sounds laid over each other: [(sound, start s, gain dB)]"""
    out = np.zeros(max(int(t * SR) + len(x) for x, t, g in parts))
    for x, t, g in parts:
        i = int(t * SR)
        out[i:i + len(x)] += x * 10 ** (g / 20)
    return out


def tail(d, sec):
    d = d.copy()
    n = int(sec * SR)
    d[-n:] *= np.linspace(1, 0, n) ** 1.5
    return d


def rms_to(d, db):
    e = np.abs(d)
    idx = np.nonzero(e > e.max() * 0.05)[0]
    r = np.sqrt((d[idx[0]:idx[-1] + 1] ** 2).mean())
    d = d * (10 ** (db / 20) / r)
    return d * min(1.0, 0.89 / np.abs(d).max())   # never past -1 dBFS


def endings(dst):
    snd = lambda f: load(os.path.join(dst, f + ".ogg"))
    glass = [snd("impactGlass_light_00%d" % i) for i in range(3)]
    bowl = snd("bowl_ping")
    win = lay([(snd("bfh1_rock_breaking_03"), 0.0, -2), (glass[0], 0.22, -6), (pitch(glass[1], 1.19), 0.34, -7),
               (pitch(glass[2], 1.5), 0.46, -8), (pitch(glass[0], 2.0), 0.58, -9), (snd("magical_5"), 0.25, -4),
               (pitch(bowl, 1.5), 0.25, -8)])
    write(os.path.join(dst, "win_geode.ogg"), rms_to(tail(win, 0.8), -21.0))
    lose = lay([(snd("bfh1_rock_falling_07"), 0.0, 0), (pitch(snd("bfh1_rock_falling_04"), 0.8), 0.18, -3),
                (lowpass(pitch(bowl, 0.5), 900), 0.3, -4), (pitch(snd("impactBell_heavy_000"), 0.5), 0.35, -12)])
    write(os.path.join(dst, "lose_rockfall.ogg"), rms_to(tail(lose, 1.2), -23.0))


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
