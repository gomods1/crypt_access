-- Rooms: names doors and explored rooms on generated floors, without spoiling unexplored ones.
-- The game keeps each room's type for the current floor (shop, stairs room, vault...):
-- PlacementUtils.getRoomAt(x, y), filled from the level's `rooms` at levelLoad (ProceduralLevel.lua
-- convertRoom: interior rectangle and RoomType). The starting room is not in that list; the mod treats
-- the 5x5 square around the spawn point (0, 0) as the starting room (HYPOTHESIS, matches 1-1 and 1-2).
--
-- A room counts as explored once the player has stood in it. Doors sit in a room's wall with a
-- corridor (or another room) on the other side. Seen from outside, a door is named after its room;
-- seen from inside, after the first room the player reached the last time they left through it.
-- Wooden doors turn into floor when opened (Dig.lua: no digType gives the tile's floor), so every door
-- on the floor is remembered and an opened one stays listed as a doorway.

local CurrentLevel = require("necro.game.level.CurrentLevel")
local PlacementUtils = require("necro.game.level.PlacementUtils")
local ProceduralLevel = require("necro.game.data.level.ProceduralLevel")
local Tile = require("necro.game.tile.Tile")

local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Rooms = {}

local RoomType = ProceduralLevel.RoomType
local START_RADIUS = 2

local levelID = false
local doors = {}        -- "x,y" -> { x, y, areas = { areaID, ... } }
local visited = {}      -- areaID -> visit number (order of first visit)
local visitCount = 0
local standardCount = 0
local areaInfo = {}     -- areaID -> { type, number, room }
local learned = {}      -- door key -> areaID reached after leaving its room through it
local lastDoor = false  -- door the player last stood on, until they reach a room
local prevX, prevY

local typeKeys = {
	[RoomType.SHOP] = "shop",
	[RoomType.SECRET_SHOP] = "secretShop",
	[RoomType.EXIT] = "exit",
	[RoomType.BOSS] = "boss",
	[RoomType.VAULT] = "vault",
	[RoomType.SECRET] = "secret",
}

local function key(x, y)
	return x .. "," .. y
end

local function isFloorTile(x, y)
	local ok, info = pcall(Tile.getInfo, x, y)
	return ok and type(info) == "table" and info.name and not info.isWall and not info.isDoor and not info.isLocked
end

--- The area (room) a tile belongs to: an ID string and the room record, or nil in corridors.
local function areaAt(x, y)
	local ok, room = pcall(PlacementUtils.getRoomAt, x, y)
	if ok and room then
		local id = "r" .. room.x .. "," .. room.y
		if not areaInfo[id] then
			areaInfo[id] = { type = room.type, room = room }
		end
		return id
	end
	if math.abs(x) <= START_RADIUS and math.abs(y) <= START_RADIUS and isFloorTile(x, y) then
		if not areaInfo.start then
			areaInfo.start = { type = "start", room = { x = -START_RADIUS, y = -START_RADIUS,
				width = START_RADIUS * 2 + 1, height = START_RADIUS * 2 + 1 } }
		end
		return "start"
	end
end

local function hasRooms()
	local okP, procedural = pcall(CurrentLevel.isProcedural)
	return okP and procedural
end

local function isDoorInfo(info)
	return type(info) == "table" and (info.isDoor or info.isLocked)
end

local function recordDoors()
	local ok, bx, by, bw, bh = pcall(Tile.getLevelBounds)
	if not ok or not bx then
		return
	end
	for x = bx, bx + bw - 1 do
		for y = by, by + bh - 1 do
			local okInfo, info = pcall(Tile.getInfo, x, y)
			if okInfo and isDoorInfo(info) and not tostring(info.name):find("Stairs") then
				local areas, seen = {}, {}
				for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
					local area = areaAt(x + d[1], y + d[2])
					if area and not seen[area] then
						seen[area] = true
						areas[#areas + 1] = area
					end
				end
				doors[key(x, y)] = { x = x, y = y, areas = areas }
			end
		end
	end
end

local function reset(id)
	levelID = id
	doors, visited, areaInfo, learned = {}, {}, {}, {}
	visitCount, standardCount = 0, 0
	lastDoor = false
	prevX, prevY = nil, nil
	if hasRooms() then
		recordDoors()
	end
end

--- Keeps the state on the current floor; true when this floor has room data.
local function ensure()
	local ok, id = pcall(CurrentLevel.getUniqueID)
	if not ok then
		return false
	end
	if id ~= levelID then
		reset(id)
	end
	return hasRooms()
end

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

local function visit(area)
	if visited[area] then
		return
	end
	visitCount = visitCount + 1
	visited[area] = visitCount
	local info = areaInfo[area]
	if info and info.type ~= "start" and not typeKeys[info.type] then
		standardCount = standardCount + 1
		info.number = standardCount
	end
end

--- Tracks the player: rooms stood in, and where leaving a room through a door led.
local function track()
	if not ensure() then
		return
	end
	local x, y = World.playerPosition()
	if not x or (x == prevX and y == prevY) then
		return
	end
	prevX, prevY = x, y
	local door = doors[key(x, y)]
	if door then
		lastDoor = door
		return
	end
	local area = areaAt(x, y)
	if area then
		visit(area)
		if lastDoor then
			if not contains(lastDoor.areas, area) then
				learned[key(lastDoor.x, lastDoor.y)] = area
			end
			lastDoor = false
		end
	end
end

event.tick.add("cryptAccessRooms", { order = "menu", sequence = 40 }, function()
	if World.playing() then
		pcall(track)
	end
end)

--- Name of an area: "the shop", "the stairs room", "room 2" (key suffix "to" for "Door to ...").
local function areaName(area, form)
	local info = areaInfo[area]
	if not info then
		return nil
	end
	local kind = info.type == "start" and "start" or typeKeys[info.type]
	if kind then
		return Strings.get("room." .. form .. "." .. kind)
	end
	return Strings.get("room." .. form .. ".standard", { n = info.number or "?" })
end

--- Where a door leads, seen from the player's side: an explored area ID or nil.
local function destination(door)
	local px, py = World.playerPosition()
	local here = px and areaAt(px, py)
	local target
	if #door.areas >= 2 then
		target = door.areas[1] == here and door.areas[2] or door.areas[1]
	elseif #door.areas == 1 then
		if door.areas[1] ~= here then
			target = door.areas[1]
		else
			target = learned[key(door.x, door.y)]
		end
	end
	if target and target ~= here and visited[target] then
		return target
	end
end

--- Spoken name for a remembered door tile, or nil when the tile is not a remembered door.
--- isOpen: the door has been opened (the tile is floor now).
function Rooms.doorName(x, y, isOpen)
	if not ensure() then
		return nil
	end
	local door = doors[key(x, y)]
	if not door then
		return nil
	end
	local target = destination(door)
	if target then
		return Strings.get(isOpen and "room.doorwayTo" or "room.doorTo", { room = areaName(target, "to") })
	end
	if isOpen then
		return Strings.get("room.doorway")
	end
	return nil
end

--- True when x, y held a door that has been opened since the floor started.
function Rooms.isOpenedDoor(x, y)
	if not ensure() then
		return false
	end
	if not doors[key(x, y)] then
		return false
	end
	local ok, info = pcall(Tile.getInfo, x, y)
	return ok and not isDoorInfo(info)
end

--- Scanner entries for opened doorways and explored rooms (category "exit").
function Rooms.scanEntries(list)
	if not ensure() then
		return
	end
	for k, door in pairs(doors) do
		if Rooms.isOpenedDoor(door.x, door.y) and World.isTileKnown(door.x, door.y) then
			list[#list + 1] = { key = "tile:" .. k, x = door.x, y = door.y,
				name = Rooms.doorName(door.x, door.y, true), category = "exit" }
		end
	end
	local px, py = World.playerPosition()
	if not px then
		return
	end
	local here = areaAt(px, py)
	for area in pairs(visited) do
		local info = areaInfo[area]
		if area ~= here and info and info.room then
			-- The room's floor tile nearest to the player, so N routes to its near side.
			local r, best, bestD = info.room, nil, nil
			for x = r.x, r.x + r.width - 1 do
				for y = r.y, r.y + r.height - 1 do
					if areaAt(x, y) == area and isFloorTile(x, y) then
						local d = math.abs(x - px) + math.abs(y - py)
						if not bestD or d < bestD then
							best, bestD = { x, y }, d
						end
					end
				end
			end
			if best then
				list[#list + 1] = { key = "room:" .. area, x = best[1], y = best[2],
					name = areaName(area, "name"), category = "exit" }
			end
		end
	end
end

--- The explored room the player stands in ("the shop"), or nil.
function Rooms.current()
	if not ensure() then
		return nil
	end
	local px, py = World.playerPosition()
	local area = px and areaAt(px, py)
	if area and visited[area] then
		return areaName(area, "name")
	end
end

return Rooms
