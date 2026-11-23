"""Add (or remove) the two Crypt Access entries in Necrodancer64/config.json.

- wos.game.mods.scriptWhitelist gets "core.StandardLibrary" (gives the mod LuaJIT ffi to load prism.dll).
- wos.game.mods.preload gets {"name": "CryptAccess"} so the mod loads even before the player can reach the Mods menu.

A backup config.json.cryptaccess.bak is written once, before the first change.
Usage: python tools/patch_config.py CONFIG_JSON [--remove]
"""
import json
import os
import shutil
import sys

WHITELIST_ENTRY = "core.StandardLibrary"
PRELOAD_ENTRY = {"name": "CryptAccess"}


def main():
    path = sys.argv[1]
    remove = "--remove" in sys.argv
    with open(path, encoding="utf-8") as f:
        config = json.load(f)
    mods = config["wos"]["game"]["mods"]
    whitelist = mods.setdefault("scriptWhitelist", [])
    preload = mods.setdefault("preload", [])
    before = json.dumps(config, sort_keys=True)

    if remove:
        mods["scriptWhitelist"] = [e for e in whitelist if e != WHITELIST_ENTRY]
        mods["preload"] = [e for e in preload if not (isinstance(e, dict) and e.get("name") == "CryptAccess")]
    else:
        if WHITELIST_ENTRY not in whitelist:
            whitelist.append(WHITELIST_ENTRY)
        if not any(isinstance(e, dict) and e.get("name") == "CryptAccess" for e in preload):
            preload.append(PRELOAD_ENTRY)

    if json.dumps(config, sort_keys=True) == before:
        print("config.json already", "clean" if remove else "patched")
        return
    backup = path + ".cryptaccess.bak"
    if not remove and not os.path.exists(backup):
        shutil.copy2(path, backup)
        print("backup:", backup)
    with open(path, "w", encoding="utf-8", newline="") as f:
        json.dump(config, f, separators=(",", ":"))
    print("config.json", "restored" if remove else "patched")


if __name__ == "__main__":
    main()
