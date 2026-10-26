"""Turns a Suno track into a seamless game loop.

    py prototype/tools/music_loop.py <in.mp3> <out.ogg> [end_from end_to start_from start_to]

Finds the pair (end E, start L) whose music sounds alike both before and after the cut (log-band spectra,
8 s back + 4 s ahead), keeps the intro once, cuts the outro, and cross-fades the last 1.5 s into what precedes L,
so playing on from L after E is seamless. Prints L: put it in the .import as loop_offset (and loop=true).
Defaults: E within the last 10..45 s before the fade-out, L within 8..60 s.
"""
import sys
import numpy as np
import soundfile as sf

HOP = 0.05
X = 1.5


def bands(m, sr):
    hop, win = int(HOP * sr), 4096
    nf = (len(m) - win) // hop
    out = []
    edges = np.unique(np.geomspace(2, win // 2, 48).astype(int))
    w = np.hanning(win)
    for s in range(0, nf, 2000):
        idx = np.arange(win)[None, :] + hop * np.arange(s, min(nf, s + 2000))[:, None]
        sp = np.abs(np.fft.rfft(m[idx] * w, axis=1))
        out.append(np.stack([sp[:, edges[i]:edges[i + 1]].sum(1) for i in range(len(edges) - 1)], 1))
    b = np.log(np.concatenate(out) + 1e-6)
    b -= b.mean(1, keepdims=True)
    return b / (np.linalg.norm(b, axis=1, keepdims=True) + 1e-9)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    a, sr = sf.read(src, always_2d=True)
    m = a.mean(1)
    dur = len(m) / sr
    if len(sys.argv) > 6:
        e0, e1, l0, l1 = map(float, sys.argv[3:7])
    else:
        # where the fade-out starts: last second louder than -24 dB
        rms = [20 * np.log10(np.sqrt((m[k:k + sr] ** 2).mean()) + 1e-9) for k in range(0, len(m) - sr, sr)]
        fade = max(i for i, r in enumerate(rms) if r > -24.0)
        e0, e1, l0, l1 = fade - 45.0, fade - 10.0, 8.0, 60.0
    B = bands(m, sr)
    f = lambda s: int(s / HOP)
    Es, Ls = np.arange(f(e0), f(e1)), np.arange(f(l0), f(l1))
    back = sum(B[Es - k] @ B[Ls - k].T for k in range(160)) / 160
    ahead = sum(B[Es + k] @ B[Ls + k].T for k in range(80)) / 80
    T = (back + ahead) / 2
    i, j = np.unravel_index(np.argmax(T), T.shape)
    E, L = int(Es[i] * HOP * sr), int(Ls[j] * HOP * sr)
    # nudge E so the waveforms line up best (±60 ms)
    n, r = 2 * sr, int(0.06 * sr)
    ref = m[L - n:L]
    E += max(range(-r, r + 1), key=lambda d: float(np.dot(m[E + d - n:E + d], ref)) / (np.linalg.norm(m[E + d - n:E + d]) + 1e-9))
    x = int(X * sr)
    out = a[:E].copy()
    w = np.sqrt(np.linspace(0, 1, x))[:, None]
    out[E - x:E] = a[E - x:E] * np.sqrt(1 - w ** 2) + a[L - x:L] * w
    with sf.SoundFile(dst, "w", sr, a.shape[1], format="OGG", subtype="VORBIS") as fo:
        for k in range(0, len(out), 4096):
            fo.write(out[k:k + 4096].astype(np.float32))
    print("track %.1f s, end %.3f, loop_offset %.3f, similarity %.3f (back %.3f, ahead %.3f)"
          % (dur, E / sr, L / sr, T[i, j], back[i, j], ahead[i, j]))


if __name__ == "__main__":
    main()
