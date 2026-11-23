-- Walks toward the scanner's selected target using the mod's route (test helper, Bard/no-beat).
-- Set MAXSTEPS before including to limit steps.
local target = M.Scanner.selected()
if not target then return "no target" end
local steps = M.Path.find(target.x, target.y)
if not steps then return "no route" end
local px, py = M.World.playerPosition()
local keys = {}
local limit = MAXSTEPS or 12
for i, s in ipairs(steps) do
	if i > limit then break end
	local dx, dy = s.x - px, s.y - py
	local k = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
	keys[#keys + 1] = k
	keys[#keys + 1] = "wait"
	if s.dig then
		keys[#keys + 1] = k
		keys[#keys + 1] = "wait"
		keys[#keys + 1] = k
		keys[#keys + 1] = "wait"
	end
	px, py = s.x, s.y
end
key(unpack(keys))
return target.name .. ": " .. #steps .. " steps, sent " .. #keys
