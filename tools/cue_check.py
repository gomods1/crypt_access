"""Objective check of the positional cues: records the default speaker output (WASAPI loopback) while
the game plays one cue at a known offset, then reports left/right energy and the dominant frequency.
Run with the game frozen (Space) so the music does not mask the cue.

    python tools/cue_check.py
"""
import os
import sys
import threading
import time

import numpy as np
import soundcard as sc

sys.path.insert(0, os.path.dirname(__file__))
import dev  # noqa: E402

RATE = 48000

CASES = [
    ("tick", 0, 0), ("tick", -3, 0), ("tick", 3, 0), ("tick", -1, 0), ("tick", 1, 0),
    ("tick", 0, -3), ("tick", 0, 3),
    ("enemy", -2, 0), ("enemy", 2, 0), ("enemy", 0, 1), ("enemy", 0, 4),
]


def record(seconds):
    speaker = sc.default_speaker()
    mic = sc.get_microphone(id=str(speaker.name), include_loopback=True)
    with mic.recorder(samplerate=RATE, channels=2) as rec:
        return rec.record(numframes=int(RATE * seconds))


def measure(name, dx, dy):
    result = {}

    def worker():
        result["data"] = record(0.9)

    t = threading.Thread(target=worker)
    t.start()
    time.sleep(0.25)
    dev.run('M.Cues.play("%s", %d, %d, 1) return 1' % (name, dx, dy), 5)
    t.join()
    data = result["data"]
    energy = (data ** 2).sum(axis=1)
    peak = int(np.argmax(energy))
    lo, hi = max(0, peak - int(0.05 * RATE)), min(len(data), peak + int(0.05 * RATE))
    seg = data[lo:hi]
    left = float(np.sqrt((seg[:, 0] ** 2).mean()))
    right = float(np.sqrt((seg[:, 1] ** 2).mean()))
    mono = seg.mean(axis=1) * np.hanning(len(seg))
    spectrum = np.abs(np.fft.rfft(mono))
    freqs = np.fft.rfftfreq(len(mono), 1 / RATE)
    f0 = float(freqs[int(np.argmax(spectrum[1:])) + 1])
    return left, right, f0


def main():
    print("case            left    right   balance  freq")
    for name, dx, dy in CASES:
        left, right, f0 = measure(name, dx, dy)
        total = left + right
        balance = (right - left) / total if total > 0 else 0.0
        print("%-6s dx=%2d dy=%2d  %.4f  %.4f  %+.2f   %6.0f Hz" % (name, dx, dy, left, right, balance, f0))
        time.sleep(0.3)


if __name__ == "__main__":
    main()
