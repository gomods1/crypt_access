#!/bin/sh
# Usage: tools/charrun.sh CharacterType  -> starts an all-zones run with that character and reports.
cd "$(dirname "$0")/.." || exit 1
python tools/dev.py "R('necro.client.StateControl').enterLobby() return 1" >/dev/null; sleep 6
python tools/dev.py "R('necro.client.CharacterSelector').setSelectedCharacter(nil,'$1') return 1" >/dev/null; sleep 1
python tools/dev.py "return key('enter','wait','wait','wait','enter')" >/dev/null; sleep 10
python tools/dev.py "local p=M.World.player() return p.name..' | '..M.HUD.healthText(p)..' | '..table.concat(M.HUD.inventoryLines(),'; ')..' | scan '..#M.Scanner.build()..' | '..M.HUD.levelText()"
for i in 1 2 3; do python tools/dev.py "MAXSTEPS=4 $(cat tools/autoplay.lua)" >/dev/null; sleep 4; done
python tools/dev.py --speech 8 | grep Say | grep -v "Elige tu personaje" | tail -5
