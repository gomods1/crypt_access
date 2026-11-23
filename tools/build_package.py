r"""Builds the packaged mod CryptAccess-<version>.necromod that online sessions need, with the game's own
packer (bridge.res.compiler.createPackage, the function system.mod.ModLoader.compile uses).

Needs the game running with the dev console (tools/dev.py). It never touches the game's mods folder:
  1. stages mod.json, scripts\ (without DevConsole.lua) and sounds\ in dist\pkgstage\CryptAccess;
  2. asks the running game to pack that folder into dist\CryptAccess-<version>.necromod;
  3. checks the package's file list against the staging folder (tools/wsp_extract.py);
  4. copies the package to mod\CryptAccess\package\ (where Package.lua and the installers expect it).

Every player in an online session must have byte-identical packages, so build once per version and ship
that file; bump the version in mod.json whenever scripts change.

python tools/build_package.py
"""
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dev  # noqa: E402
import wsp_extract  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MOD = os.path.join(ROOT, "mod", "CryptAccess")
STAGE = os.path.join(ROOT, "dist", "pkgstage", "CryptAccess")


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    version = json.load(open(os.path.join(MOD, "mod.json"), encoding="utf-8"))["version"]
    name = "CryptAccess-%s.necromod" % version
    out = os.path.abspath(os.path.join(ROOT, "dist", name))

    shutil.rmtree(os.path.dirname(STAGE), ignore_errors=True)
    os.makedirs(STAGE)
    shutil.copy(os.path.join(MOD, "mod.json"), STAGE)
    shutil.copytree(os.path.join(MOD, "scripts"), os.path.join(STAGE, "scripts"),
                    ignore=shutil.ignore_patterns("DevConsole.lua"))
    shutil.copytree(os.path.join(MOD, "sounds"), os.path.join(STAGE, "sounds"))
    files = []
    for folder, _, names in os.walk(STAGE):
        for n in sorted(names):
            rel = os.path.relpath(os.path.join(folder, n), STAGE).replace("\\", "/")
            files.append(rel)
    files.sort()
    if os.path.exists(out):
        os.remove(out)

    source = os.path.abspath(STAGE)
    chunk = """
local ML = M.Native.engineModule("system.mod.ModLoader")
local bridge = M.Native.lib.getfenv(ML.compile).bridge
local files = { %s }
bridge.res.compiler.createPackage(%s, %s, files)
return "started " .. #files
""" % (", ".join(lua_string(f) for f in files), lua_string(source), lua_string(out))
    print(dev.run(chunk, 20))

    status_chunk = """
local bridge = M.Native.lib.getfenv(M.Native.engineModule("system.mod.ModLoader").compile).bridge
local path = %s
local status = bridge.res.compiler.getStatus(path)
local log = {}
repeat
	local level, message = bridge.res.compiler.pollLogOutput(path)
	if level then log[#log + 1] = tostring(level) .. " " .. tostring(message) end
until level == nil
if status ~= 1 then bridge.res.compiler.release(path) end
return tostring(status) .. " " .. table.concat(log, " | ")
""" % lua_string(out)
    status = "1"
    for _ in range(120):
        time.sleep(0.5)
        status = dev.run(status_chunk, 10).strip('"')
        if not status.startswith("1"):
            break
    print("packer status:", status)
    if not status.startswith("2") or not os.path.exists(out):
        sys.exit("package build failed")

    entries = wsp_extract.read_package(out)
    packed = sorted(e[0] if isinstance(e, tuple) else e for e in entries)
    missing = [f for f in files if f not in packed]
    print("package %s: %d bytes, %d files" % (name, os.path.getsize(out), len(packed)))
    if missing:
        sys.exit("files missing from the package: %s" % missing[:10])

    target = os.path.join(MOD, "package")
    if os.path.isdir(target):
        for old in os.listdir(target):
            if old.endswith(".necromod"):
                os.remove(os.path.join(target, old))
    os.makedirs(target, exist_ok=True)
    shutil.copy(out, target)
    print("copied to", os.path.join("mod", "CryptAccess", "package", name))


if __name__ == "__main__":
    main()
