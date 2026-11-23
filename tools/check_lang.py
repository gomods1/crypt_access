"""Release check: every Lang*.lua has exactly LangEN's keys and the same {placeholders}.
python tools/check_lang.py   (exit code 1 on any problem)"""
import glob
import os
import re
import sys

root = os.path.join(os.path.dirname(__file__), "..", "mod", "CryptAccess", "scripts")
pat = re.compile(r'^\t\["([^"]+)"\] = "((?:[^"\\]|\\.)*)",\s*$')


def load(path):
    entries = {}
    for i, line in enumerate(open(path, encoding="utf-8").read().splitlines()):
        m = pat.match(line)
        if m:
            entries[m.group(1)] = m.group(2)
        elif line.strip() not in ("", "}", "return {") and not line.startswith("--"):
            print(f"{os.path.basename(path)}:{i + 1}: unparsed line: {line[:60]}")
    return entries


en = load(os.path.join(root, "LangEN.lua"))
bad = 0
for path in sorted(glob.glob(os.path.join(root, "Lang*.lua"))):
    d = load(path)
    missing = [k for k in en if k not in d]
    extra = [k for k in d if k not in en]
    ph = [k for k in en if k in d and sorted(re.findall(r"\{\w+\}", en[k])) != sorted(re.findall(r"\{\w+\}", d[k]))]
    if missing or extra or ph:
        bad += 1
    print(f"{os.path.basename(path)}: {len(d)} keys; missing {missing[:6]}; extra {extra[:3]}; placeholder mismatch {ph[:6]}")
sys.exit(1 if bad else 0)
