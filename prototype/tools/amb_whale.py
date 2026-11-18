"""The voices of the old seas' swimmers on a find's card (SpecReef.Swim's sea_call "song"): whale-like calls,
synthesised (no free recording of a mosasaur is to be had) — a gliding tone with a few harmonics, a slow waver, a
rasp in the low ones, heard through a long watery echo.
    py prototype/tools/amb_whale.py <godot/assets/audio/amb/sea> <ffmpeg.exe>
writes whale_0..4.ogg there."""
import sys, os, wave, subprocess
import numpy as np

SR = 44100
rng = np.random.default_rng(7)

def glide(points, n):
    """a pitch curve through (time 0..1, Hz) points, smooth"""
    t = np.linspace(0.0, 1.0, n)
    xs = np.array([p[0] for p in points]); ys = np.log(np.array([p[1] for p in points]))
    f = np.interp(t, xs, ys)
    k = int(SR * 0.08)
    f = np.convolve(np.pad(f, k, mode='edge'), np.ones(k) / k, mode='same')[k:-k]
    return np.exp(f)

def voice(points, sec, harm=(1.0, 0.45, 0.22, 0.1), waver=0.012, waver_f=4.5, rasp=0.0, rasp_f=22.0, breath=0.03):
    n = int(SR * sec)
    t = np.arange(n) / SR
    f = glide(points, n) * (1.0 + waver * np.sin(2 * np.pi * waver_f * t + rng.random() * 6.28) * np.linspace(0.3, 1.0, n))
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = sum(a * np.sin(ph * (i + 1) + rng.random() * 6.28) for i, a in enumerate(harm))
    if rasp > 0.0:
        # (a throat's pulses: the tone chopped at a low rate)
        y *= 1.0 - rasp * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rasp_f * t)) * np.abs(np.sin(2 * np.pi * rasp_f * t)) ** 0.3)
    env = np.minimum(1.0, t / (sec * 0.22)) * np.minimum(1.0, (sec - t) / (sec * 0.35))
    env = env ** 1.5 * (1.0 + 0.15 * np.sin(2 * np.pi * 0.7 * t))
    y = y * env + breath * rng.standard_normal(n) * env
    return y

def echo(y, sec=3.2, wet=0.55):
    """the sea's long echo: the sound through a decaying burst of noise, dulled"""
    n = int(SR * sec)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * sec / 5.0))
    k = 40
    ir = np.convolve(ir, np.ones(k) / k, mode='same')
    ir[:int(SR * 0.03)] *= np.linspace(0, 1, int(SR * 0.03))
    m = len(y) + n
    w = np.fft.irfft(np.fft.rfft(y, m) * np.fft.rfft(ir, m), m)
    w /= max(1e-9, np.abs(w).max())
    d = np.concatenate([y, np.zeros(n)]) / max(1e-9, np.abs(y).max())
    return d * (1 - wet) + w * wet

def lowpass(y, hz):
    f = np.fft.rfft(y)
    fr = np.fft.rfftfreq(len(y), 1 / SR)
    return np.fft.irfft(f / (1.0 + (fr / hz) ** 4), len(y))

CALLS = [
    # a long moan, up and over
    lambda: voice([(0, 150), (0.35, 260), (0.6, 300), (1, 190)], 3.2),
    # two notes, the second lower
    lambda: np.concatenate([voice([(0, 240), (0.5, 330), (1, 310)], 1.5), np.zeros(int(SR * 0.25)), voice([(0, 210), (0.6, 170), (1, 120)], 2.2)]),
    # a deep groan with a rasp in it
    lambda: voice([(0, 62), (0.4, 84), (1, 55)], 3.6, harm=(1.0, 0.7, 0.5, 0.35, 0.2), rasp=0.55, rasp_f=19.0, waver=0.02),
    # a rising whoop
    lambda: voice([(0, 95), (0.5, 160), (0.85, 420), (1, 460)], 1.9, harm=(1.0, 0.3, 0.12)),
    # a slow falling cry
    lambda: voice([(0, 420), (0.25, 380), (0.7, 230), (1, 200)], 2.8, harm=(1.0, 0.35, 0.3, 0.08), waver=0.02, waver_f=5.5),
]

def main():
    out, ff = sys.argv[1], sys.argv[2]
    for i, c in enumerate(CALLS):
        y = lowpass(echo(c()), 1600.0)
        y = y / np.abs(y).max() * 0.8
        fade = int(SR * 0.4)
        y[-fade:] *= np.linspace(1, 0, fade)
        wav = os.path.join(out, 'whale_%d.wav' % i)
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((y * 32767).astype(np.int16).tobytes())
        subprocess.run([ff, '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', os.path.join(out, 'whale_%d.ogg' % i)], check=True)
        os.remove(wav)
        print('whale_%d.ogg' % i, round(len(y) / SR, 1), 's')

main()
