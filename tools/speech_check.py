"""Scans the speech log for glitches: raw string keys, nil, unfilled {placeholders}, engine key names,
English words while the game is in another language, and lines repeated back to back.

    python tools/speech_check.py
"""
import collections
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
path = os.path.join(os.path.dirname(__file__), "..", "mod", "CryptAccess", "CryptAccess_speech.log")
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
says = []
for line in lines:
    m = re.match(r"\[\s*([\d.]+)\] Say!? +(.*)", line)
    if m:
        says.append((float(m.group(1)), m.group(2)))
print(len(says), "spoken lines")

raw = re.compile(r"\bnil\b|\{\w+\}|\bkey_\d|%[sd]|\b(?:scan|hud|event|tile|detail|menu|help|dir|path|slot|price|setting|tutorial|summary|charSelect|text|buffer|beacon|freeze)\.[a-zA-Z]")
bad = [s for _, s in says if raw.search(s)]
print("raw keys or placeholders:", len(bad))
for b in bad[:12]:
    print("   ", b[:160])

english = re.compile(r"\b(?:the|left|right|steps|enemy|enemies|items|unknown|press|health|hearts|gold)\b")
eng = [s for _, s in says if english.search(s)]
print("English-looking lines:", len(eng))
for e in eng[:10]:
    print("   ", e[:160])

doubles = []
for (t1, a), (t2, b) in zip(says, says[1:]):
    if a == b and t2 - t1 < 0.2:
        doubles.append(a)
print("same line twice within 0.2 s:", len(doubles))
for d in collections.Counter(doubles).most_common(6):
    print("   ", d[1], d[0][:140])
