-- Review cursor: a read-only cursor over the grid. It never moves the player.
--   Shift+arrows: move the cursor one tile and read it.  End: put the cursor back on the player.
-- A tile reads its things first, then the tile itself, then the offset from the player:
-- "Skeleton, Floor, 2 right". Ctrl+Up reads the details of the first thing (or the tile).

local Buffers = require("CryptAccess.Buffers")
local Details = require("CryptAccess.Details")
local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local ReviewCursor = {}

local cursor = { x = false, y = false }

local function ensure()
	local px, py = World.playerPosition()
	if not px then
		return false
	end
	if not cursor.x then
		cursor.x, cursor.y = px, py
	end
	return true
end

--- Short description of a tile for speech, and the detail lines for the buffer.
function ReviewCursor.describe(x, y)
	if not World.isTileKnown(x, y) then
		return Strings.get("tile.unknown"), {}
	end
	local parts, details = {}, {}
	for _, item in ipairs(World.entitiesAt(x, y)) do
		if not World.isPlayer(item.entity) then
			parts[#parts + 1] = World.name(item.entity)
			if #details == 0 then
				details = Details.forEntity(item.entity)
			end
		end
	end
	local tileLines, phrase = Details.forTile(x, y)
	parts[#parts + 1] = phrase
	for _, line in ipairs(tileLines) do
		details[#details + 1] = line
	end
	return table.concat(parts, ", "), details
end

function ReviewCursor.read()
	if not ensure() then
		return
	end
	local px, py = World.playerPosition()
	local text, details = ReviewCursor.describe(cursor.x, cursor.y)
	local where = World.direction(cursor.x - px, cursor.y - py)
	local line = text .. ", " .. where
	Speech.say(line, true)
	local lines = { line }
	for _, d in ipairs(details) do
		lines[#lines + 1] = d
	end
	Buffers.focus(lines)
end

function ReviewCursor.move(dx, dy)
	if not ensure() then
		return
	end
	cursor.x, cursor.y = cursor.x + dx, cursor.y + dy
	ReviewCursor.read()
end

function ReviewCursor.reset()
	cursor.x, cursor.y = false, false
	if ensure() then
		ReviewCursor.read()
	end
end

function ReviewCursor.position()
	return cursor.x, cursor.y
end

event.gameStateLevel.add("cryptAccessReviewReset", { order = "resetLevelVariables", sequence = 51 }, function()
	cursor.x, cursor.y = false, false
end)

local inGame = World.playing

Keys.bind({ key = "up", shift = true, id = "reviewUp", when = inGame, fn = function()
	ReviewCursor.move(0, -1)
end })
Keys.bind({ key = "down", shift = true, id = "reviewDown", when = inGame, fn = function()
	ReviewCursor.move(0, 1)
end })
Keys.bind({ key = "left", shift = true, id = "reviewLeft", when = inGame, fn = function()
	ReviewCursor.move(-1, 0)
end })
Keys.bind({ key = "right", shift = true, id = "reviewRight", when = inGame, fn = function()
	ReviewCursor.move(1, 0)
end })
Keys.bind({ key = "end", id = "reviewReset", when = inGame, fn = ReviewCursor.reset })

return ReviewCursor
