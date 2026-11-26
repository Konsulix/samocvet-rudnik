# a dragonfly's wings: a dry papery whirr, the beat (~28 Hz) heard as a flutter; 2 s, loops seamlessly
import numpy as np, wave, subprocess
R = 44100
T = 2.0
n = int(R * T)
t = np.arange(n) / R
rng = np.random.default_rng(7)
x = rng.standard_normal(n)
# band 1.2–6 kHz (FFT mask; circular, so it loops)
X = np.fft.rfft(x)
f = np.fft.rfftfreq(n, 1 / R)
X *= np.exp(-((np.log(f + 1) - np.log(2600)) / 0.55) ** 2)
x = np.fft.irfft(X, n)
# the beat: 28 Hz (56 cycles in 2 s: loops), each stroke a sharp swish; fore and hind pairs a little apart
beat = 28.0
ph = 2 * np.pi * beat * t
env = np.abs(np.sin(ph)) ** 3 + 0.6 * np.abs(np.sin(ph + 1.1)) ** 3
# a slow wobble in strength (whole cycles in 2 s)
env *= 0.75 + 0.25 * np.sin(2 * np.pi * 1.5 * t)
lo = np.sin(ph) * 0.25  # a low flutter under it
y = x / np.abs(x).max() * env + lo * 0.15 * env
y /= np.abs(y).max()
y *= 0.7
out = 'C:/Users/2BA0~1/AppData/Local/Temp/claude/e0efa91a612e9205/25a54fff-efab-41bc-842c-a107a54460ae/scratchpad/cham_wings.wav'
with wave.open(out, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
    w.writeframes((y * 32767).astype(np.int16).tobytes())
print('ok')
