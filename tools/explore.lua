-- Test helper: walks toward the nearest unexplored edge (or TARGET_KIND entity if visible).
local limit = MAXSTEPS or 8
local W = M.World
local E = R("system.game.Entities")
local goal
if WANT then
	for e in E.entitiesWithComponents({ "position" }) do
		if e[WANT] and W.isVisible(e) then goal = { x = e.position.x, y = e.position.y, name = e.name } break end
	end
end
local steps
if goal then
	steps = M.Path.find(goal.x, goal.y)
else
	local t = M.Path.frontierTarget()
	steps = t and t.steps
end
if not steps then return "stuck" end
local px, py = W.playerPosition()
local keys = {}
for i, s in ipairs(steps) do
	if i > limit then break end
	local dx, dy = s.x - px, s.y - py
	local k = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
	keys[#keys + 1] = k
	keys[#keys + 1] = "wait"
	keys[#keys + 1] = "wait"
	if s.dig then for _ = 1, 3 do keys[#keys + 1] = k keys[#keys + 1] = "wait" keys[#keys + 1] = "wait" end end
	px, py = s.x, s.y
end
key(unpack(keys))
return (goal and ("goal " .. goal.name) or "frontier") .. " " .. #steps .. " steps"
