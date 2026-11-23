-- Test autoplayer (Bard / no-beat): stairs if open and known, else the exit-guarding enemy,
-- else the nearest enemy within 3 tiles, else the unexplored edge. Sends up to MAXSTEPS moves.
local W, E, T, LE = M.World, R("system.game.Entities"), R("necro.game.tile.Tile"), R("necro.game.tile.LevelExit")
local px, py = W.playerPosition()
local function steps_to(x, y) return M.Path.find(x, y) end
local goal, steps, why
if LE.isUnlocked() then
	local bx, by, bw, bh = T.getLevelBounds()
	local best
	for x = bx, bx + bw - 1 do for y = by, by + bh - 1 do
		local i = T.getInfo(x, y)
		if i.name == "Stairs" and W.isTileKnown(x, y) then
			local d = math.abs(x - px) + math.abs(y - py)
			if not best or d < best.d then best = { x = x, y = y, d = d } end
		end
	end end
	if best then steps = steps_to(best.x, best.y) why = "stairs" end
end
if not steps then
	for e in E.entitiesWithComponents({ "stairLocker", "position" }) do
		if W.isVisible(e) and W.category(e) == "enemy" then steps = steps_to(e.position.x, e.position.y) why = "miniboss " .. e.name break end
	end
end
if not steps then
	for e in E.entitiesWithComponents({ "enemy", "position", "health" }) do
		local d = math.abs(e.position.x - px) + math.abs(e.position.y - py)
		if d <= 2 and W.isVisible(e) and W.category(e) == "enemy" then steps = steps_to(e.position.x, e.position.y) why = "enemy " .. e.name break end
	end
end
if not steps then local t = M.Path.frontierTarget() steps = t and t.steps why = "frontier" end
if not steps then return "stuck" end
local keys = {}
for i, s in ipairs(steps) do
	if i > (MAXSTEPS or 6) then break end
	local dx, dy = s.x - px, s.y - py
	local k = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
	keys[#keys + 1] = (BEAT and "beat:" or "") .. k keys[#keys + 1] = "wait"
	if s.dig then for _ = 1, 3 do keys[#keys + 1] = (BEAT and "beat:" or "") .. k keys[#keys + 1] = "wait" keys[#keys + 1] = "wait" end end
	px, py = s.x, s.y
end
key(unpack(keys))
return why .. " " .. #steps .. " lvl " .. R("necro.game.level.CurrentLevel").getNumber() .. " hp " .. M.World.player().health.health
