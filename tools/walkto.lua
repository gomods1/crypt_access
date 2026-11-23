-- Walks (on the beat when BEAT) to tile TX,TY by the mod's route. Test helper.
local st = M.Path.find(TX, TY)
if not st then return "no route" end
local px, py = M.World.playerPosition()
local keys = {}
for _, s in ipairs(st) do
	local dx, dy = s.x - px, s.y - py
	local k = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
	keys[#keys + 1] = (BEAT and "beat:" or "") .. k
	if s.dig then for _ = 1, 3 do keys[#keys + 1] = (BEAT and "beat:" or "") .. k end end
	px, py = s.x, s.y
end
key(unpack(keys))
return #st .. " steps"
