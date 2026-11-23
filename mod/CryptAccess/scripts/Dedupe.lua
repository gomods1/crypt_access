-- Suppresses repeated announcements from re-simulated turns. The game rolls back and replays turns
-- (late input, instant replay after death), which fires the same events again. An announcement made
-- during a turn is keyed by turn ID and text, and spoken only the first time.

local Turn = require("necro.cycles.Turn")

local Dedupe = {}

local seen = {}
local order = {}
local MAX = 400

--- True when this text was not yet spoken for the current turn (and records it).
function Dedupe.first(text, turnID)
	if turnID == nil then
		local ok, id = pcall(Turn.getActiveTurnID)
		turnID = ok and id or nil
	end
	if not turnID then
		return true
	end
	local key = tostring(turnID) .. "|" .. text
	if seen[key] then
		return false
	end
	seen[key] = true
	order[#order + 1] = key
	if #order > MAX then
		seen[table.remove(order, 1)] = nil
	end
	return true
end

--- True while the game replays turns for an instant replay (nothing new happens).
function Dedupe.replaying()
	local ok, active = pcall(function()
		return require("necro.client.replay.InstantReplay").isActive()
	end)
	return ok and active
end

return Dedupe
