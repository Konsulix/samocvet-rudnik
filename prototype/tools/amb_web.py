"""Spider Hollow's sounds (mine 6, the Edo silver mine in the cedar valley; WebView / WebSounds), synthesized here (no
recordings needed; the waterfall, the furnace and the wheel's creak are Copper Mountain's own files, used as they are):

    py prototype/tools/amb_web.py godot/assets/audio/amb/web

rain        - a summer shower on cedars and tile roofs (loop; the view sets its volume by the shower)
higurashi   - the evening cicada's falling "ka-na-ka-na" (loop, almost all above 2 kHz: past the bus's filter)
frogs       - frogs in the stream at night (loop)
shishi      - the bamboo deer-scarer tipping over and knocking on its stone
bell        - the shrine's big bronze bell, struck once, a long hum
rin         - the nun's small hand bell
chisel_0..2 - a chisel struck by a hammer
bellows     - a box bellows breathing out
skitter     - many small legs running over rock
jingle      - the rings of a monk's staff
drone       - a low breath from deep below (the eight eyes)
groan       - the lair's rope pulled tight, the hollow shaking
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 32000
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(6)


def t_(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, f):
    n = len(x)
    X = np.fft.rfft(x, 2 * n)
    fr = np.fft.rfftfreq(2 * n, 1 / SR)
    return np.fft.irfft(X / (1 + 1j * fr / f), 2 * n)[:n]


def highpass(x, f):
    return x - lowpass(x, f)


def band(x, f0, f1):
    return lowpass(highpass(x, f0), f1)


def norm(d, peak=0.8):
    return d * (peak / max(1e-6, np.abs(d).max()))


def fade(d, a=0.005, b=0.1):
    d = d.copy()
    na, nb = int(a * SR), int(b * SR)
    if na: d[:na] *= np.linspace(0, 1, na)
    if nb: d[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return d


def loop(d, x=1.0):
    """the end crossfaded into the start: a seamless loop"""
    n = int(x * SR)
    out = d[n:].copy()
    w = np.linspace(0, 1, n)
    out[-n:] = out[-n:] * (1 - w) + d[:n] * w
    return out


def save(name, d, peak=0.8):
    sf.write(os.path.join(OUT, name + ".ogg"), norm(d, peak).astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("ok", name, round(len(d) / SR, 2), "s")


def ping(f, dur, decay, partials=((1, 1.0),)):
    t = t_(dur)
    out = np.zeros_like(t)
    for k, a in partials:
        out += a * np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6)) * np.exp(-t * decay * (0.6 + 0.4 * k))
    return out


# ---- rain: a hiss of fine drops, heavier ones on tiles and leaves, a little run-off
T = 14.0
n = int(T * SR)
hiss = band(rng.standard_normal(n), 900, 7000) * 0.5
pat = np.zeros(n)
for i in range(int(T * 160)):
    at = rng.integers(0, n - 2000)
    f = rng.uniform(1800, 5200)
    d = ping(f, 0.03, 140) * rng.uniform(0.2, 1.0)
    pat[at:at + len(d)] += d
for i in range(int(T * 25)):
    at = rng.integers(0, n - 4000)
    d = band(rng.standard_normal(1800), 500, 2500) * np.exp(-np.arange(1800) / 300) * rng.uniform(0.6, 1.6)
    pat[at:at + 1800] += d
run = lowpass(rng.standard_normal(n), 300) * 0.8
save("rain", loop(hiss + pat * 0.35 + run * 0.4, 1.5), 0.7)

# ---- higurashi: bursts of a trilled tone falling in pitch, kana-kana-kana, now near, now farther off
T = 16.0
n = int(T * SR)
hig = np.zeros(n)
for start, amp in ((0.6, 1.0), (6.4, 0.55), (11.2, 0.8)):
    t = t_(3.6)
    f = 4300 - 900 * (t / 3.6) ** 0.7                       # the whole phrase falls
    beat = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 7.2 * t))  # ka-na ka-na: the trill comes in short pulses
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 95 * t)            # the buzz inside each pulse
    env = np.minimum(1, t / 0.25) * np.exp(-t * 0.45)
    ph = np.cumsum(2 * np.pi * f / SR)
    s = (np.sin(ph) + 0.35 * np.sin(2 * ph)) * beat * trem * env * amp
    s = lowpass(s, 9000)
    i0 = int(start * SR)
    hig[i0:i0 + len(s)] += s[: n - i0]
save("higurashi", loop(hig, 0.6), 0.6)

# ---- frogs: low throaty croaks in two voices
T = 12.0
n = int(T * SR)
fr = np.zeros(n)
for voice, base, every in ((0, 210, 0.9), (1, 330, 1.4)):
    tt = rng.uniform(0, every)
    while tt < T - 1:
        k = rng.integers(2, 5)
        for j in range(k):
            t = t_(0.09)
            pul = np.sign(np.sin(2 * np.pi * base * t)) * 0.6 + np.sin(2 * np.pi * base * 2 * t) * 0.4
            env = np.sin(np.pi * t / 0.09) ** 2
            s = band(pul * env, 150, 1800) * (0.7 if voice else 1.0)
            i0 = int((tt + j * 0.13) * SR)
            fr[i0:i0 + len(s)] += s
        tt += every * rng.uniform(1.4, 3.0)
save("frogs", loop(fr, 0.5), 0.55)

# ---- shishi-odoshi: the bamboo tips (a hollow tok), water splashes off it
t = t_(1.2)
tok = ping(620, 1.2, 22, ((1, 1.0), (2.3, 0.5), (3.9, 0.25))) + ping(1450, 1.2, 40, ((1, 0.4),))
click = np.zeros_like(t); click[:200] = rng.standard_normal(200) * np.exp(-np.arange(200) / 40)
spl = np.zeros_like(t)
i0 = int(0.05 * SR)
sp = band(rng.standard_normal(int(0.35 * SR)), 800, 6000) * np.exp(-np.arange(int(0.35 * SR)) / (0.08 * SR))
spl[i0:i0 + len(sp)] = sp * 0.25
save("shishi", fade(tok + click * 0.5 + spl), 0.75)

# ---- the shrine bell: a deep bronze strike, inharmonic partials beating slowly, a long, long hum
t = t_(9.0)
f0 = 98.0
bell = np.zeros_like(t)
for k, a, dec in ((0.5, 0.6, 0.25), (1.0, 1.0, 0.35), (1.183, 0.5, 0.5), (1.506, 0.45, 0.6), (2.0, 0.4, 0.8), (2.74, 0.3, 1.2), (3.8, 0.2, 1.8), (5.4, 0.12, 2.6)):
    bell += a * np.sin(2 * np.pi * f0 * k * t) * (1 + 0.15 * np.sin(2 * np.pi * 0.7 * k * t)) * np.exp(-t * dec)
thud = lowpass(rng.standard_normal(len(t)), 200) * np.exp(-t * 18) * 2.0
save("bell", fade(bell + thud, 0.002, 1.5), 0.8)

# ---- rin: a small bell, clear and long
save("rin", fade(ping(1240, 2.5, 1.4, ((1, 1.0), (2.71, 0.45), (5.1, 0.2))), 0.001, 0.5), 0.6)

# ---- a chisel struck: the hammer's knock and the steel's short ring, three a little different
for i in range(3):
    f = 2300 + 380 * i
    s = ping(f, 0.35, 18, ((1, 1.0), (1.63, 0.6), (2.7, 0.35))) * 0.6
    k = np.zeros_like(s); k[:400] = band(rng.standard_normal(400), 300, 4000) * np.exp(-np.arange(400) / 70)
    save("chisel_%d" % i, fade(s + k, 0.0005, 0.05), 0.7)

# ---- bellows: a soft breath of air through a wooden box
t = t_(1.0)
br = lowpass(rng.standard_normal(len(t)), 900) * np.sin(np.pi * t / 1.0) ** 1.5
save("bellows", fade(br + lowpass(rng.standard_normal(len(t)), 180) * 0.6 * np.sin(np.pi * t) ** 2), 0.6)

# ---- skitter: tiny hard taps, fast and many, swelling and going
t = t_(1.6)
sk = np.zeros_like(t)
for i in range(110):
    at = int(rng.uniform(0, 1.55) * SR)
    d = band(rng.standard_normal(90), 2500, 9000) * np.exp(-np.arange(90) / 15)
    sk[at:at + 90] += d * np.sin(np.pi * at / len(t)) ** 0.7
save("skitter", sk, 0.5)

# ---- the shakujo's rings: small loose iron rings jingling together
t = t_(1.2)
jg = np.zeros_like(t)
for i in range(9):
    at = int(rng.uniform(0, 0.35) * SR)
    d = ping(rng.uniform(2600, 4800), 0.8, rng.uniform(5, 9), ((1, 1.0), (1.48, 0.5)))
    jg[at:at + len(d)] += d[: len(t) - at] * rng.uniform(0.4, 1.0)
save("jingle", fade(jg, 0.001, 0.2), 0.55)

# ---- the drone from below: a low breath with a slow beat
t = t_(5.0)
dr = (np.sin(2 * np.pi * 55 * t) + 0.7 * np.sin(2 * np.pi * 82.7 * t) + 0.35 * np.sin(2 * np.pi * 110.6 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.4 * t))
dr += lowpass(rng.standard_normal(len(t)), 260) * 0.8 * np.sin(np.pi * t / 5.0)
save("drone", fade(dr * np.sin(np.pi * t / 5.0) ** 0.6, 0.3, 1.2), 0.7)

# ---- the groan: a rope pulled tight (a slow creak) over a deep thud
t = t_(2.6)
cr = np.zeros_like(t)
for i in range(18):
    at = int((0.2 + i * 0.07 + rng.uniform(0, 0.02)) * SR)
    d = band(rng.standard_normal(500), 300, 1600) * np.exp(-np.arange(500) / 120)
    cr[at:at + 500] += d * (0.5 + 0.5 * np.sin(np.pi * i / 18))
th = lowpass(rng.standard_normal(len(t)), 120) * np.exp(-t * 2.5) * 2.5
save("groan", fade(cr + th, 0.002, 0.4), 0.8)
