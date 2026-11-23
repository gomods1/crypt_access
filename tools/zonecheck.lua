local T, E, W = R("necro.game.tile.Tile"), R("system.game.Entities"), M.World
local L = R("necro.game.level.CurrentLevel")
local bx, by, bw, bh = T.getLevelBounds()
local tiles, ents = {}, {}
for x = bx, bx + bw - 1 do for y = by, by + bh - 1 do
	local i = T.getInfo(x, y)
	if i.name and not tiles[i.name] then local _, phrase = W.describeTile(x, y) tiles[i.name] = phrase end
end end
local tl = {}
for k, v in pairs(tiles) do tl[#tl + 1] = v end
for e in E.entitiesWithComponents({ "position" }) do
	local c = W.category(e)
	if c and c ~= "label" then local n = W.name(e) ents[n] = (ents[n] or 0) + 1 end
end
local el = {}
for k, v in pairs(ents) do el[#el + 1] = k end
table.sort(tl) table.sort(el)
return "zone " .. L.getZone() .. " level " .. L.getNumber() .. "\nTILES: " .. table.concat(tl, "; ") .. "\nTHINGS: " .. table.concat(el, "; ")
