"""The voices of the old seas' swimmers on a find's card (SpecReef.Swim's sea_call "song"): real whales — NOAA PMEL's
hydrophone recordings (US government work, public domain; https://www.pmel.noaa.gov/acoustics/whales/sounds/, the
whalewav/ files: an Alaska humpback, blue whales of four oceans sped up ten times, the "52 Hz" whale).
Each file is cut into its single calls by loudness; a call gets soft ends, a little of the sea's echo, an even level.
    py -I prototype/tools/amb_whale_rec.py <folder with the downloaded .wav> <godot/assets/audio/amb/sea> <ffmpeg.exe>
writes whale_0..N.ogg there (and prints what it took)."""
import sys, os, wave, subprocess, glob
import numpy as np

# how many calls to take from each file at most
TAKE = {'akhumphi1x': 3, 'nepblue24s10x': 1, 'wblue26s10x': 1, 'atlblue_512_64_0-50_10x': 1,
        'etpb3_10xc-BlueWhaleSouthPacific-10x': 1, 'ak52_10x': 1}

def read(path):
    with wave.open(path, 'rb') as w:
        sr, n, ch, sw = w.getframerate(), w.getnframes(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    if sw == 1:
        y = (np.frombuffer(raw, np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        y = np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0
    if ch > 1:
        y = y.reshape(-1, ch).mean(axis=1)
    return y - y.mean(), sr

def calls(y, sr):
    """the stretches louder than the water's own noise, with a little room either side: (start, end, loudness)"""
    hop = int(sr * 0.05)
    env = np.array([np.sqrt(np.mean(y[i:i + hop * 4] ** 2)) for i in range(0, len(y) - hop * 4, hop)])
    floor = np.percentile(env, 25)
    on = env > floor + 0.3 * (env.max() - floor)
    out, i = [], 0
    while i < len(on):
        if not on[i]:
            i += 1
            continue
        j = i
        gap = 0
        while j < len(on) and gap < 10:   # (a pause under half a second is the same call)
            gap = 0 if on[j] else gap + 1
            j += 1
        j -= gap
        a, b = max(0, i * hop - int(sr * 0.35)), min(len(y), j * hop + int(sr * 0.6))
        if 1.2 <= (b - a) / sr <= 9.0:
            out.append((a, b, float(env[i:j].mean())))
        i = j + 1
    return out

def main():
    src, out, ff = sys.argv[1], sys.argv[2], sys.argv[3]
    k = 0
    for path in sorted(glob.glob(os.path.join(src, '*.wav'))):
        name = os.path.splitext(os.path.basename(path))[0]
        y, sr = read(path)
        best = sorted(calls(y, sr), key=lambda c: -c[2])[:TAKE.get(name, 1)]
        for a, b, lv in sorted(best):
            seg = y[a:b].copy()
            f = int(sr * 0.25)
            seg[:f] *= np.linspace(0, 1, f)
            seg[-f * 2:] *= np.linspace(1, 0, f * 2)
            seg = seg / max(1e-6, np.abs(seg).max()) * 0.9
            tmp = os.path.join(out, '_w.wav')
            with wave.open(tmp, 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
                w.writeframes((seg * 32767).astype(np.int16).tobytes())
            # (the sea's echo, the top of the hiss off, an even level; a second and a half of tail for the echo)
            subprocess.run([ff, '-y', '-loglevel', 'error', '-i', tmp, '-af',
                            'apad=pad_dur=1.5,aecho=0.8:0.6:240|510:0.3|0.2,highpass=f=40,lowpass=f=2600,loudnorm=I=-20:TP=-2,afade=t=out:st=%.2f:d=1.2' % ((b - a) / sr + 0.3),
                            '-ar', '44100', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '4', os.path.join(out, 'whale_%d.ogg' % k)], check=True)
            os.remove(tmp)
            print('whale_%d.ogg' % k, name, '%.1f-%.1f s' % (a / sr, b / sr))
            k += 1
    print(k, 'calls')

main()
