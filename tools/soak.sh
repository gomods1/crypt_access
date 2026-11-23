#!/bin/sh
# Soak test: for each character, start an all-zones run and autoplay a few rounds (on the beat).
cd "$(dirname "$0")/.." || exit 1
for c in "$@"; do
	python tools/dev.py "R('necro.menu.Menu').closeAll() R('necro.client.StateControl').enterLobby() return 1" >/dev/null; sleep 6
	python tools/dev.py "R('necro.client.CharacterSelector').setSelectedCharacter(nil,'$c') return key('enter','wait','wait','wait','enter')" >/dev/null; sleep 11
	echo "== $c: $(python tools/dev.py "return M.World.player() and M.World.player().name")"
	for i in 1 2 3 4 5 6; do
		python tools/dev.py "BEAT=true MAXSTEPS=5 $(cat tools/autoplay.lua)" -t 15 >/dev/null; sleep 5
		python tools/dev.py "return key('pagedown','wait','home','wait','c','wait','u','wait','n','wait','h','wait','i','wait','l','wait','m','wait','ctrl+up','wait','ctrl+right')" >/dev/null; sleep 3
	done
done
