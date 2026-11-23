-- Plays cues at known offsets and reads back what the audio engine got (position, pitch, volume).
local A = R("system.game.Audio")
local out = {}
local orig = A.createStaticSource
local last
local cases = { { -3, 0 }, { -1, 0 }, { 0, 0 }, { 1, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 }, { 2, -2 }, { 0, 1 }, { 0, 5 } }
for _, c in ipairs(cases) do
	local before = {}
	for _, id in ipairs(A.getActiveSources() or {}) do before[id] = true end
	M.Cues.play("enemy", c[1], c[2], 1)
	local id
	for _, s in ipairs(A.getActiveSources() or {}) do if not before[s] then id = s end end
	if id then
		local x, y, z = A.getPosition(id)
		out[#out + 1] = string.format("dx=%2d dy=%2d -> pos(%.2f, %.2f, %.2f) pitch %.2f vol %.2f playing %s",
			c[1], c[2], x or 0, y or 0, z or 0, A.getPitch(id) or 0, A.getVolume(id) or 0, tostring(A.isPlaying(id)))
	else
		out[#out + 1] = string.format("dx=%2d dy=%2d -> no new source", c[1], c[2])
	end
end
return table.concat(out, "\n")
