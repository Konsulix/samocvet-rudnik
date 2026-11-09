"""The Fire Maiden's laugh (docs/fire-maiden.md): the girl's giggles cut from BigSoundBank #1660 «Laughter of children»
(Joseph Sardin, CC0) - the high bits (~800-900 Hz), not the boy's low ones - each faded at its ends and brought to one
level. The game plays them a little higher (Sfx mdn_laugh).
usage: python maiden_laugh.py <1660.ogg> <godot dir>"""
import os
import sys
import numpy as np
import soundfile as sf

src, godot = sys.argv[1], sys.argv[2]
x, sr = sf.read(src)
CUTS = [(0.10, 0.48), (2.76, 3.13)]   # (1.16-1.60 has the boy in it too)
out = os.path.join(godot, "assets", "audio", "sfx")
for i, (a, b) in enumerate(CUTS):
    y = x[int(a * sr):int(b * sr)].copy()
    n = int(0.015 * sr)
    y[:n] *= np.linspace(0, 1, n)
    y[-n * 3:] *= np.linspace(1, 0, n * 3)
    y *= 0.7 / max(1e-6, np.abs(y).max())
    p = os.path.join(out, "maiden_laugh_%d.ogg" % i)
    sf.write(p, y, sr, format="OGG", subtype="VORBIS")
    print(p, "%.2f s" % (len(y) / sr))
