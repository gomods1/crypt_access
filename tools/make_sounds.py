"""Generates the mod's earcons as mono OGG files in mod/CryptAccess/sounds (needs numpy and ffmpeg).

    python tools/make_sounds.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "CryptAccess", "sounds")


def env(n, attack=0.005, release=0.04):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    r = np.clip((n / RATE - t) / release, 0, 1)
    return a * r


def tone(freq, dur, kind="sine", vol=0.6, attack=0.005, release=None):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(t)) / RATE
    else:
        phase = 2 * np.pi * freq * t
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.5 + np.sin(phase) * 0.3
    elif kind == "saw":
        w = 2 * ((phase / (2 * np.pi)) % 1) - 1
    elif kind == "tri":
        w = 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    else:
        raise ValueError(kind)
    return w * env(n, attack, release if release is not None else dur * 0.6) * vol


def noise(dur, vol=0.5, lowpass=0.2):
    n = int(dur * RATE)
    w = np.random.default_rng(1).uniform(-1, 1, n)
    out = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += lowpass * (w[i] - acc)
        out[i] = acc
    out /= max(1e-6, np.abs(out).max())
    return out * env(n, 0.002, dur * 0.8) * vol


def cat(*parts, gap=0.0):
    g = np.zeros(int(gap * RATE))
    res = []
    for i, p in enumerate(parts):
        if i:
            res.append(g)
        res.append(p)
    return np.concatenate(res)


SOUNDS = {
    # An enemy: low buzzy pulse.
    "enemy": lambda: tone(196, 0.09, "square", 0.5),
    # An enemy that acts on the next beat and is next to you: sharper, higher.
    "danger": lambda: tone(lambda t: 520 + 300 * t / 0.1, 0.1, "saw", 0.45),
    # An item or chest: bright chime.
    "item": lambda: tone(1318, 0.09, "sine", 0.5) + tone(1976, 0.09, "sine", 0.2),
    # The exit beacon: rising two-note figure.
    "exit": lambda: cat(tone(660, 0.07, "tri", 0.55), tone(990, 0.09, "tri", 0.55), gap=0.01),
    # Selected scanner target beacon.
    "beacon": lambda: tone(880, 0.06, "sine", 0.5),
    # Metronome tick.
    "tick": lambda: tone(1500, 0.025, "sine", 0.5, 0.001, 0.02),
    # Wall ahead / blocked.
    "wall": lambda: noise(0.07, 0.6, 0.08),
    # Trap.
    "trap": lambda: cat(tone(330, 0.05, "tri", 0.5), tone(330, 0.05, "tri", 0.5), gap=0.03),
    # Freeze on / off.
    "freeze": lambda: tone(lambda t: 900 - 500 * t / 0.15, 0.15, "sine", 0.5),
    "unfreeze": lambda: tone(lambda t: 400 + 500 * t / 0.15, 0.15, "sine", 0.5),
}


def write_wav(path, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    for name, make in SOUNDS.items():
        wav = os.path.join(tmp, name + ".wav")
        write_wav(wav, make())
        ogg = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
        print(ogg)


if __name__ == "__main__":
    main()
