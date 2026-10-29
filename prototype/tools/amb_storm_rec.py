"""Whalebone Cove's thunder from recordings (writes over amb_storm.py's synthesized thunder; elmo stays synthesized):

    py prototype/tools/amb_storm_rec.py <dl8> godot/assets/audio/amb/sea

<dl8>: BigSoundBank (CC0) single thunderclaps without rain, sNNNN.ogg: #1 2718, #3 3114, #4 3115, #5 3116, #7 3180.
Why: the synthesized thunder had half its energy under 100 Hz, which a phone's speaker does not play - a near strike came
out as a faint hiss. Real thunder sits mostly at 100-400 Hz.
thunder_near_0..1 — a strike close by: the recording from its sharp onset, with a short torn crack on top (the
recordings were taken from afar and have no crack); thunder_far_0..2 — far out at sea: slow rolls swelling in and out.
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
    if na: d[:na] *= np.linspace(0, 1, na)
    if nb: d[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return d


def onset(d):
    """the first moment within 0.3 s of the loudest 0.1 s - where the strike begins"""
    w = SR // 100
    e = np.array([np.sqrt((d[k:k + w] ** 2).mean()) for k in range(0, len(d) - w, w)])
    top = int(np.argmax(e))
    lo = max(0, top - 30)
    thr = e[top] * 0.25
    i = lo + int(np.argmax(e[lo:top + 1] > thr))
    return max(0, i * w - SR // 50)


def crack(seed, n):
    """a torn crack: bright noise in fragments, over in a quarter of a second"""
    r = np.random.default_rng(seed)
    t = np.arange(n) / SR
    frag = np.clip(lowpass(r.standard_normal(n), 300) * 40, 0, 1)
    return highpass(r.standard_normal(n), 900) * np.exp(-t * 14) * (0.4 + frag)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    s = lambda i: load(os.path.join(src, "s%04d.ogg" % i))
    for k, (i, length) in enumerate([(3180, 7.0), (2718, 7.0)]):
        d = s(i)
        d = d[onset(d):][: int(length * SR)]
        d = norm(d, 0.85)
        c = crack(11 + k, int(0.4 * SR))
        d[: len(c)] += norm(c, 0.45)
        write(os.path.join(dst, "thunder_near_%d.ogg" % k), norm(fade(d, 0.002, 1.8), 0.85))
    for k, (i, a, b) in enumerate([(3114, 0.0, 9.0), (3116, 0.3, 9.3), (3115, 0.0, 9.0)]):
        d = s(i)[int(a * SR):int(b * SR)]
        write(os.path.join(dst, "thunder_far_%d.ogg" % k), norm(fade(d, 0.6, 2.2), 0.8))


def write(path, d):
    # libsndfile's Vorbis encoder crashes on one big write: feed it in blocks
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(d), 4096):
            f.write(d[i:i + 4096].astype(np.float32))


if __name__ == "__main__":
    main()
