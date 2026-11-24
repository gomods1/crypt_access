"""Builds the mod's earcons: renders tools/cues/batch.json with genny-reloaded, then converts each WAV to
a mono OGG in mod/CryptAccess/sounds (needs genny-reloaded and ffmpeg on PATH).

    python tools/make_sounds.py

Each cue has its own family of sound so they stay apart when several play on one beat:
enemy short beast snarl, danger high double beep, trap mechanical clack, item glockenspiel, exit wind
gust, beacon sonar ping, tick woodblock, wall gravel crunch (diggable), wallsolid hard knock
(not diggable: walking into it drops the coin multiplier), freeze/unfreeze falling/rising sweeps.
Edit batch.json, re-run, and check `genny-reloaded info tools/cues/*.wav` (loudness about -7 to -12).
"""
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CUES = os.path.join(HERE, "cues")
OUT = os.path.join(HERE, "..", "mod", "CryptAccess", "sounds")


def main():
    batch = os.path.join(CUES, "batch.json")
    subprocess.run(["genny-reloaded", "render", batch, "--out-dir", CUES, "--quiet"], check=True, shell=os.name == "nt")
    os.makedirs(OUT, exist_ok=True)
    for spec in json.load(open(batch, encoding="utf-8"))["sounds"]:
        name = os.path.splitext(spec["out"])[0]
        wav = os.path.join(CUES, spec["out"])
        ogg = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", ogg],
                       check=True)
        print(ogg)


if __name__ == "__main__":
    main()
