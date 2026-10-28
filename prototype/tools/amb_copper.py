"""Copper Mountain's own sounds (CopperView via MineAmb, the muffled Amb bus): the works over the mine.

    py prototype/tools/amb_copper.py <downloads> godot/assets/audio/amb/copper

<downloads> (all CC0, see godot/assets/audio/CREDITS.md): dl2/ (water-splash-slime-sfx, steam_hisses, RPGsounds_Kenney)
and dl5/ (crow_caw.wav, fire.wav, Meow.ogg), dl6/ (BigSoundBank s0284 s0287 s0289 s0840 s0863 s1542 s1543, dove_cooing.mp3). The game's own samples come from godot/assets/audio/sfx.
Makes: falls (loop: the mill race and the falling water), furnace (loop: the blast furnace's roar under crackling fire),
chuff_0..2 (the hoisting engine's steam), creak_0..2 (the water wheel), crow_0..2 (a crow's caw, three voices),
wings_0..2 (birds starting up), coo_0..2 (pigeons), neigh_0..2, snort_0..1, hoof_0..1 (the pony), meow, bell (the leaning tower's bell, far off), rivet_0..2 (a hammer on a rivet).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
SFX = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "assets", "audio", "sfx")


def load(p):
    d, sr = sf.read(p, always_2d=True)
    d = d.mean(1)
    if sr != SR:
        d = np.interp(np.arange(0, len(d) - 1, sr / SR), np.arange(len(d)), d)
    return d


def pitch(d, k):
    return np.interp(np.arange(0, len(d) - 1, k), np.arange(len(d)), d)


def lowpass(x, f):
    a = 1 - np.exp(-2 * np.pi * f / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a * (x[i] - s)
        y[i] = s
    return y


def highpass(x, f):
    return x - lowpass(x, f)


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def trim(d, thr=0.02):
    idx = np.nonzero(np.abs(d) > thr * np.abs(d).max())[0]
    return d[idx[0]:idx[-1] + 1]


def fade(d, a=0.005, b=0.1):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    if na: d[:na] *= np.linspace(0, 1, na)
    if nb: d[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return d


def seam(d, x=1.0):
    """the tail cross-faded into the head: a loop without a click"""
    n = int(x * SR)
    out = d[:-n].copy()
    w = np.linspace(0, 1, n)
    out[:n] = out[:n] * w + d[-n:] * (1 - w)
    return out


def tile(d, n):
    return np.tile(d, int(np.ceil(n / len(d))))[:n]


def write(path, d):
    # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    rng = np.random.default_rng(5)
    dl2, dl5 = os.path.join(src, "dl2"), os.path.join(src, "dl5")
    n = 12 * SR
    # the falls: the race's babble over the roar of water coming down (a broad noise, lower and slowly swelling)
    race = tile(load(os.path.join(dl2, "water-splash-slime-sfx", "loop_water_02.ogg")), n + SR)
    roar = lowpass(lowpass(rng.standard_normal(n + SR), 900), 900) - lowpass(rng.standard_normal(n + SR), 120) * 0.5
    swell = 1.0 + 0.25 * np.sin(np.linspace(0, 2 * np.pi * 3, n + SR))
    write(os.path.join(dst, "falls.ogg"), norm(seam(norm(race, 0.5) + norm(roar * swell, 0.6), 1.0), 0.8))
    # the furnace: a low roar of draught and flame, breathing, under the crackle of the fire
    fire = load(os.path.join(dl5, "fire.wav"))[: 20 * SR + SR]
    m = len(fire)
    body = lowpass(lowpass(rng.standard_normal(m), 220), 220)
    breath = 1.0 + 0.35 * np.sin(np.linspace(0, 2 * np.pi * 5, m)) + 0.15 * np.sin(np.linspace(0, 2 * np.pi * 13, m))
    write(os.path.join(dst, "furnace.ogg"), norm(seam(norm(body * breath, 0.7) + norm(fire, 0.5), 1.0), 0.8))
    # the engine's steam: short soft hisses, muffled
    for i in range(3):
        h = trim(load(os.path.join(dl2, "steam_hisses", "steam hisses - Marker #%d.wav" % (i + 1))))[: int(0.7 * SR)]
        h = lowpass(highpass(h, 300), 3000)
        write(os.path.join(dst, "chuff_%d.ogg" % i), norm(fade(h * np.linspace(1, 0.2, len(h)), 0.02, 0.25), 0.8))
    # the wheel: wooden creaks, lower (a big wheel)
    for i in range(3):
        c = load(os.path.join(dl2, "RPGsounds_Kenney", "OGG", "creak%d.ogg" % (i + 1)))
        write(os.path.join(dst, "creak_%d.ogg" % i), norm(fade(pitch(trim(c), 0.7), 0.005, 0.1), 0.8))
    # crows: one caw in three voices
    caw = trim(load(os.path.join(dl5, "crow_caw.wav")))
    for i, k in enumerate([0.88, 1.0, 1.12]):
        write(os.path.join(dst, "crow_%d.ogg" % i), norm(fade(pitch(caw, k), 0.005, 0.06), 0.8))
    # wings: cloth flutters made quick (birds off the belfry)
    for i, (f, k) in enumerate([("cloth1", 1.6), ("cloth3", 1.8)]):
        w = trim(load(os.path.join(dl2, "RPGsounds_Kenney", "OGG", f + ".ogg")))
        flap = pitch(w, k)
        out = np.zeros(int(0.9 * SR))
        for j in range(4):
            at = int(j * 0.17 * SR)
            seg = flap[: len(out) - at] * (0.9 ** j)
            out[at:at + len(seg)] += seg
        write(os.path.join(dst, "wings_%d.ogg" % i), norm(fade(out, 0.005, 0.2), 0.8))
    write(os.path.join(dst, "meow.ogg"), norm(fade(trim(load(os.path.join(dl5, "Meow.ogg"))), 0.005, 0.05), 0.7))
    # the tower's bell, far off: the heavy bell slowed and dulled, a long ring
    bell = pitch(load(os.path.join(SFX, "impactBell_heavy_000.ogg")), 0.6)
    write(os.path.join(dst, "bell.ogg"), norm(fade(lowpass(bell, 1800), 0.002, 0.4), 0.8))
    # pigeons on the incline's roof: three coos of one recording (Wikimedia Commons "Dove cooing", public domain)
    dl6 = os.path.join(src, "dl6")
    coo = load(os.path.join(dl6, "dove_cooing.mp3"))
    for i, (a, b) in enumerate([(0.85, 2.75), (3.25, 4.95), (5.45, 7.2)]):
        write(os.path.join(dst, "coo_%d.ogg" % i), norm(fade(coo[int(a * SR):int(b * SR)], 0.03, 0.2), 0.8))
    # the groom's pony (BigSoundBank, CC0): neighs #1 #3 #5, breaths #3 #4 (a snort), two single hoof stamps
    for i, f in enumerate(["s0284", "s0863", "s1542"]):
        write(os.path.join(dst, "neigh_%d.ogg" % i), norm(fade(trim(load(os.path.join(dl6, f + ".ogg"))), 0.01, 0.2), 0.8))
    for i, f in enumerate(["s0287", "s1543"]):
        write(os.path.join(dst, "snort_%d.ogg" % i), norm(fade(trim(load(os.path.join(dl6, f + ".ogg"))), 0.01, 0.1), 0.8))
    hooves = load(os.path.join(dl6, "s0289.ogg"))
    for i, at in enumerate([1.43, 2.88]):
        write(os.path.join(dst, "hoof_%d.ogg" % i), norm(fade(hooves[int(at * SR):int((at + 0.32) * SR)], 0.003, 0.12), 0.8))
    # a pigeon taking off (BigSoundBank #0840): real wings for the birds off the belfry, beside the cloth ones
    write(os.path.join(dst, "wings_2.ogg"), norm(fade(trim(load(os.path.join(dl6, "s0840.ogg"))), 0.005, 0.3), 0.8))
    # the riveter's hammer: the first ring of a pot strike, short and higher
    for i in range(3):
        p = trim(load(os.path.join(dl2, "RPGsounds_Kenney", "OGG", "metalPot%d.ogg" % (i + 1))))[: int(0.35 * SR)]
        write(os.path.join(dst, "rivet_%d.ogg" % i), norm(fade(pitch(p, 1.25), 0.002, 0.12), 0.8))


if __name__ == "__main__":
    main()
