"""Menu crawl: opens each named menu, records what the mod says on open and after two Down presses,
then closes it. Never presses Enter, so nothing is chosen.

    python tools/menu_crawl.py name1 name2 ...
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import dev  # noqa: E402

SPEECH = os.path.join(dev.MOD, "CryptAccess_speech.log")


def speech_since(mark):
    with open(SPEECH, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    return [l[12:].strip() for l in lines[mark:] if "Say" in l]


def line_count():
    with open(SPEECH, encoding="utf-8", errors="replace") as f:
        return len(f.read().splitlines())


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    for name in sys.argv[1:]:
        dev.run("R('necro.menu.Menu').closeAll() return 1", 5)
        time.sleep(0.6)
        mark = line_count()
        result = dev.run(
            "local Mn=R('necro.menu.Menu') local ok,e=pcall(Mn.open,'%s') "
            "local c=Mn.getCurrent() return ok, tostring(e), c and c.name" % name, 5)
        time.sleep(1.2)
        dev.run("return key('down','wait','wait','down')", 5)
        time.sleep(1.5)
        said = speech_since(mark)
        print("== %s: %s" % (name, result.replace("\n", " ")))
        for line in said[:4]:
            print("   " + line[:170])
    dev.run("R('necro.menu.Menu').closeAll() return 1", 5)


if __name__ == "__main__":
    main()
