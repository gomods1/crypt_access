local p = M.World.player()
local out = { "player " .. p.position.x .. "," .. p.position.y }
for _, e in ipairs(M.Scanner.build()) do
	out[#out + 1] = e.category .. " " .. e.name:sub(1, 30) .. " " .. e.x .. "," .. e.y
end
return table.concat(out, " | ")
