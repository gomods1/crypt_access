"""Runs a Lua chunk inside the running game through the mod's DevConsole and prints the result.

    python tools/dev.py "return M.Speech.backendName()"
    python tools/dev.py -f script.lua
    python tools/dev.py --keys up,up,enter        (queue key presses)
    python tools/dev.py --speech 20               (last 20 spoken lines)

The console is on only while %LOCALAPPDATA%/NecroDancer/mods/CryptAccess/dev/enabled exists (created by --enable).
"""
import argparse
import os
import sys
import time

MOD = os.path.join(os.environ["LOCALAPPDATA"], "NecroDancer", "mods", "CryptAccess")
DEV = os.path.join(MOD, "dev")


def run(code, timeout=10.0):
    os.makedirs(DEV, exist_ok=True)
    cid = str(int(time.time() * 1000))
    out = os.path.join(DEV, "out.txt")
    with open(os.path.join(DEV, "cmd.lua"), "w", encoding="utf-8") as f:
        f.write("--id " + cid + "\n" + code + "\n")
    end = time.time() + timeout
    while time.time() < end:
        try:
            with open(out, encoding="utf-8", errors="replace") as f:
                text = f.read()
            if text.startswith("--id " + cid + "\n"):
                return text.split("\n", 1)[1].rstrip("\n")
        except OSError:
            pass
        time.sleep(0.05)
    return "TIMEOUT (is the game running with the dev console enabled?)"


def speech(n):
    path = os.path.join(MOD, "CryptAccess_speech.log")
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    return "\n".join(lines[-n:])


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("code", nargs="?")
    ap.add_argument("-f", "--file")
    ap.add_argument("--keys")
    ap.add_argument("--speech", type=int)
    ap.add_argument("--enable", action="store_true")
    ap.add_argument("-t", "--timeout", type=float, default=10.0)
    a = ap.parse_args()
    if a.enable:
        os.makedirs(DEV, exist_ok=True)
        open(os.path.join(DEV, "enabled"), "w").close()
        print("enabled (takes effect at the next game start)")
    if a.keys:
        names = ",".join('"%s"' % k.strip() for k in a.keys.split(","))
        print(run("return key(%s)" % names, a.timeout))
    code = a.code
    if a.file:
        with open(a.file, encoding="utf-8") as f:
            code = f.read()
    if code:
        print(run(code, a.timeout))
    if a.speech:
        sys.stdout.reconfigure(encoding="utf-8")
        print(speech(a.speech))


if __name__ == "__main__":
    main()
