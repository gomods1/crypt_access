local P = R("necro.game.character.Player")
local out = {}
for _, name in ipairs({ "Nocturna", "LaMuerte", "Klarinetta", "Tempo", "Chaunter", "Mary", "Suzu", "ShovelKnight", "Coldsteel_Coldsteel", "Cadence" }) do
	local ok, err = pcall(P.replacePlayer, M.World.player(), name)
	if not ok then
		out[#out + 1] = name .. ": replace failed " .. tostring(err)
	else
		local p = M.World.player()
		local okH, h = pcall(M.HUD.healthText, p)
		local okI, inv = pcall(M.HUD.inventoryLines)
		local okS, list = pcall(M.Scanner.build)
		local okC, c = pcall(M.ReviewCursor.describe, p.position.x + 1, p.position.y)
		local okK, keys = pcall(M.HUD.controlLines)
		out[#out + 1] = string.format("%s (%s): %s | %s | scan %s | right: %s | keys %s",
			name, p.name, tostring(okH and h or h), okI and table.concat(inv, "; ") or tostring(inv),
			okS and #list or tostring(list), okC and c or tostring(c), okK and #keys or tostring(keys))
	end
end
return table.concat(out, "\n")
