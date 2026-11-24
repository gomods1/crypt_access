-- Scanner: lists visible things around the player, nearest first.
--   PageDown / PageUp: next / previous entry.   Home: repeat the current entry with a fresh offset.
--   Shift+PageDown / Shift+PageUp: next / previous category.
-- An entry speaks "name, offset, position in list", e.g. "Skeleton, 2 left, 1 up, 1 of 5".
-- Ctrl+Up then reads its details (health, next move, price, description).
-- Exits are tiles (Stairs, LockedStairs, lobby stairs): found by scanning revealed tiles.

local Entities = require("system.game.Entities")
local Tile = require("necro.game.tile.Tile")

local Buffers = require("CryptAccess.Buffers")
local Details = require("CryptAccess.Details")
local Help = require("CryptAccess.Help")
local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local Scanner = {}

Scanner.categories = { "all", "enemy", "item", "exit", "npc", "trap", "label" }
local categoryIndex = 1
local entries = {}
local currentKey = false

local function categoryMatches(category, entryCategory)
	if category == "all" then
		return true
	elseif category == "item" then
		return entryCategory == "item" or entryCategory == "container"
	elseif category == "npc" then
		return entryCategory == "npc" or entryCategory == "shrine" or entryCategory == "player"
	end
	return category == entryCategory
end

--- Exit tiles the player has seen. A label already standing on the tile takes the tile's words.
local function exitTiles(list)
	local labelled = {}
	for _, entry in ipairs(list) do
		if entry.category == "exit" and entry.id then
			labelled[entry.x .. "," .. entry.y] = entry
		end
	end
	local ok, bx, by, bw, bh = pcall(Tile.getLevelBounds)
	if not ok or not bx then
		return
	end
	for x = bx, bx + bw - 1 do
		for y = by, by + bh - 1 do
			local okInfo, info = pcall(Tile.getInfo, x, y)
			local isExit = okInfo and type(info) == "table" and info.name
				and (info.descent or info.isDoor or info.isLocked or info.name:find("Stairs"))
			if isExit then
				if World.isTileKnown(x, y) then
					local _, phrase, tileInfo = World.describeTile(x, y)
					local label = labelled[x .. "," .. y]
					if label then
						local locked = tileInfo and tostring(tileInfo.name):find("Locked")
						label.suffix = ", " .. Strings.get(locked and "tile.stairsLocked" or "tile.stairs")
						label.name = label.name .. label.suffix
					else
						list[#list + 1] = { key = "tile:" .. x .. "," .. y, x = x, y = y, name = phrase, category = "exit" }
					end
				end
			end
		end
	end
end

--- Builds the list for the current category (or the one given), nearest first.
function Scanner.build(categoryOverride)
	local px, py = World.playerPosition()
	if not px then
		return {}
	end
	local category = categoryOverride or Scanner.categories[categoryIndex]
	local list = {}
	for e in Entities.entitiesWithComponents({ "position" }) do
		local entryCategory = World.category(e)
		if entryCategory and categoryMatches(category, entryCategory) and World.isVisible(e) then
			local name = World.name(e)
			local suffix = nil
			if e.stairLocker and entryCategory == "enemy" then
				suffix = ", " .. Strings.get("scan.miniboss")
			end
			if e.sale then
				local okPrice, price = pcall(Details.price, e)
				if okPrice and price then
					suffix = ", " .. price
				end
			end
			-- Secret shopkeepers: their offer and cost is the only explanation of what they do.
			if e.secretShopLabel then
				local okShop, offer = pcall(Details.secretShop, e)
				if okShop and offer and offer ~= "" then
					suffix = (suffix or "") .. ", " .. offer
				end
			end
			if name ~= "" then
				name = name .. (suffix or "")
				list[#list + 1] = {
					suffix = suffix,
					key = "e:" .. e.id,
					id = e.id,
					x = e.position.x,
					y = e.position.y,
					name = name,
					category = entryCategory,
				}
			end
		end
	end
	if category == "all" or category == "exit" then
		exitTiles(list)
	end
	for _, entry in ipairs(list) do
		local dx, dy = entry.x - px, entry.y - py
		entry.distance = math.abs(dx) + math.abs(dy) + (dx ~= 0 and dy ~= 0 and 0.01 or 0)
	end
	table.sort(list, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.key < b.key
	end)
	return list
end

--- What the scanner can list right now, counted per category: "12 exits and doors, 3 characters and
--- shrines". Built from the same list as PageDown, so anything new in a room is counted too. Nil when empty.
function Scanner.summary()
	local counts = {}
	for _, entry in ipairs(Scanner.build("all")) do
		for i = 2, #Scanner.categories do
			local category = Scanner.categories[i]
			if categoryMatches(category, entry.category) then
				counts[category] = (counts[category] or 0) + 1
				break
			end
		end
	end
	local parts = {}
	for i = 2, #Scanner.categories do
		local category = Scanner.categories[i]
		if counts[category] then
			parts[#parts + 1] = Strings.get("scan.count", { count = counts[category], category = Strings.get("scan.cat." .. category) })
		end
	end
	return parts[1] and table.concat(parts, ", ") or nil
end

--- Re-reads a live entry: entities may have moved or died.
local function refresh(entry)
	if entry.id then
		local e = Entities.getEntityByID(entry.id)
		if not e or not e.position or not World.isVisible(e) then
			return nil
		end
		entry.x, entry.y = e.position.x, e.position.y
		entry.name = World.name(e) .. (entry.suffix or "")
		entry.entity = e
	end
	return entry
end

local selectedAt = 0

--- When the scanner last spoke an entry (the beacon follows the newest of scanner and U).
function Scanner.selectedTime()
	return selectedAt
end

local function speak(entry, index, count)
	selectedAt = require("system.utils.Timer").getGlobalTime()
	local px, py = World.playerPosition()
	local line = Strings.get("scan.entry", {
		name = entry.name,
		where = World.direction(entry.x - px, entry.y - py),
		index = index,
		count = count,
	})
	Speech.say(line, true)
	Speech.debug("scan " .. tostring(entry.key))
	Buffers.focus(Details.forScanEntry(entry, line))
end

local function indexOf(list, key)
	for i, entry in ipairs(list) do
		if entry.key == key then
			return i
		end
	end
	return nil
end

function Scanner.step(delta)
	if not World.inLevel() then
		return
	end
	entries = Scanner.build()
	if #entries == 0 then
		currentKey = false
		Speech.say(Strings.get("scan.nothing", { category = Strings.get("scan.cat." .. Scanner.categories[categoryIndex]) }), true)
		return
	end
	local index = currentKey and indexOf(entries, currentKey)
	if not index then
		index = delta >= 0 and 1 or #entries
	else
		index = ((index - 1 + delta) % #entries) + 1
	end
	local entry = refresh(entries[index]) or entries[index]
	currentKey = entry.key
	speak(entry, index, #entries)
end

function Scanner.repeatCurrent()
	if not World.inLevel() then
		return
	end
	entries = Scanner.build()
	local index = currentKey and indexOf(entries, currentKey)
	if not index then
		if currentKey then
			Speech.say(Strings.get("scan.gone"), true)
			currentKey = false
			return
		end
		return Scanner.step(1)
	end
	speak(refresh(entries[index]) or entries[index], index, #entries)
end

function Scanner.cycleCategory(delta)
	categoryIndex = ((categoryIndex - 1 + delta) % #Scanner.categories) + 1
	currentKey = false
	local category = Scanner.categories[categoryIndex]
	entries = World.inLevel() and Scanner.build() or {}
	Speech.say(Strings.get("scan.category", {
		category = Strings.get("scan.cat." .. category),
		count = #entries,
	}), true)
end

--- The selected entry's position, for the beacon and the review cursor.
function Scanner.selected()
	if not currentKey then
		return nil
	end
	for _, entry in ipairs(entries) do
		if entry.key == currentKey then
			return refresh(entry)
		end
	end
end

event.gameStateLevel.add("cryptAccessScannerReset", { order = "resetLevelVariables", sequence = 50 }, function()
	currentKey = false
	entries = {}
end)

local inGame = World.playing

Keys.bind({ key = "pagedown", id = "scanNext", when = inGame, fn = function()
	Scanner.step(1)
end })
Keys.bind({ key = "pageup", id = "scanPrevious", when = inGame, fn = function()
	Scanner.step(-1)
end })
Keys.bind({ key = "home", id = "scanRepeat", when = inGame, fn = Scanner.repeatCurrent })
Keys.bind({ key = "pagedown", shift = true, id = "scanCategoryNext", when = inGame, fn = function()
	Scanner.cycleCategory(1)
end })
Keys.bind({ key = "pageup", shift = true, id = "scanCategoryPrevious", when = inGame, fn = function()
	Scanner.cycleCategory(-1)
end })

return Scanner
