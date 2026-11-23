#!/bin/sh
# From a run: pause menu, "Salir al vestíbulo", confirm.
cd "$(dirname "$0")/.." || exit 1
python tools/dev.py "return key('escape')" >/dev/null; sleep 2
python tools/dev.py "local c=R('necro.menu.Menu').getCurrent() for i,e in ipairs(c.entries) do local l=e.label if type(l)=='function' then l=l(false) end if tostring(l):find('vestíbulo') then c.selection=i end end return c.selection" >/dev/null
python tools/dev.py "return key('enter','wait','wait','wait','enter')" >/dev/null; sleep 10
python tools/dev.py "return R('necro.game.level.CurrentLevel').isLobby()"
