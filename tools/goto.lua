-- Walks to the first visible-or-known label whose text contains GOTO (lobby, no rhythm). Test helper.
local E = R("system.game.Entities")
local best
local px, py = M.World.playerPosition()
for e in E.entitiesWithComponents({ "worldLabel", "position" }) do
	local n = M.World.name(e)
	if n:find(GOTO, 1, true) then
		local d = math.abs(e.position.x - px) + math.abs(e.position.y - py)
		if not best or d < best.d then best = { x = e.position.x, y = e.position.y, d = d, n = n } end
	end
end
if not best then return "no label " .. GOTO end
local steps = M.Path.find(best.x, best.y)
if not steps then return "no route to " .. best.n end
local keys = {}
for i, s in ipairs(steps) do
	if i > (MAXSTEPS or 40) then break end
	local dx, dy = s.x - px, s.y - py
	keys[#keys + 1] = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
	keys[#keys + 1] = "wait" keys[#keys + 1] = "wait"
	px, py = s.x, s.y
end
key(unpack(keys))
return best.n .. ": " .. #steps .. " steps"
