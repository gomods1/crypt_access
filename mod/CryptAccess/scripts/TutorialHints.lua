-- Tutorial lessons for the mod itself. The game's tutorial (labels and Cadence's voice lines) teaches
-- the game; these lines teach Crypt Access's keys at the moment each one becomes useful, written for a
-- player who cannot see the screen. Each lesson is spoken once per tutorial, queued after the game's
-- own lines, and goes to the Events buffer. Setting: Options, Mod settings, Crypt Access, tutorial hints.

local CurrentLevel = require("necro.game.level.CurrentLevel")
local Entities = require("system.game.Entities")
local Tile = require("necro.game.tile.Tile")

local Buffers = require("CryptAccess.Buffers")
local Config = require("CryptAccess.Config")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local TutorialHints = {}

local state = { active = false, given = {}, start = false, enemiesAtFirstSight = nil, nextCheck = 0 }

local function inTutorial()
	local ok, name = pcall(CurrentLevel.getName)
	return ok and type(name) == "string" and name:lower():find("tutorial") ~= nil
end

-- Lessons wait in a queue and come out one at a time, at least 8 seconds apart, so they do not pile
-- up on top of each other or on Cadence's voice lines.
local queue = {}
local lastSpoken = -100
local GAP = 6
-- Lessons that matter for survival skip the queue.
local URGENT = { enemy = true }

local function give(id)
	if state.given[id] then
		return
	end
	state.given[id] = true
	if URGENT[id] then
		table.insert(queue, 1, id)
	else
		queue[#queue + 1] = id
	end
end

local function speakNext(now)
	if queue[1] and now - lastSpoken >= GAP then
		local id = table.remove(queue, 1)
		local text = Strings.get("tutorial." .. id)
		Buffers.addEvent(text)
		Speech.say(text, false)
		lastSpoken = now
	end
end

--- Visible entities of a category, counted.
local function countVisible(category)
	local n = 0
	for e in Entities.entitiesWithComponents({ "position" }) do
		if World.category(e) == category and World.isVisible(e) then
			n = n + 1
		end
	end
	return n
end

local function countAliveEnemies()
	local n = 0
	for e in Entities.entitiesWithComponents({ "enemy", "health" }) do
		if World.category(e) == "enemy" then
			n = n + 1
		end
	end
	return n
end

local function doorInSight(px, py)
	for x = px - 8, px + 8 do
		for y = py - 8, py + 8 do
			local ok, info = pcall(Tile.getInfo, x, y)
			if ok and type(info) == "table" and (info.isDoor or info.isLocked) and World.isTileKnown(x, y) then
				return true
			end
		end
	end
	return false
end

local function nearRunStart(px, py)
	for e in Entities.entitiesWithComponents({ "trapStartRun", "position" }) do
		if math.abs(e.position.x - px) + math.abs(e.position.y - py) <= 6 then
			return true
		end
	end
	return false
end

event.gameStateLevel.add("cryptAccessTutorialReset", { order = "levelLoadingDone", sequence = 70 }, function()
	state.active = false
	state.given = {}
	state.start = false
	state.enemiesAtFirstSight = nil
	queue = {}
end)

event.tick.add("cryptAccessTutorialHints", { order = "hud", sequence = 70 }, function()
	if not World.playing() or Config.get("tutorialHints") == false then
		return
	end
	local Timer = require("system.utils.Timer")
	local now = Timer.getGlobalTime()
	if now < state.nextCheck then
		return
	end
	state.nextCheck = now + 0.3
	speakNext(now)
	if not inTutorial() then
		state.active = false
		return
	end
	local px, py = World.playerPosition()
	if not px then
		return
	end
	if not state.active then
		state.active = true
		state.start = { x = px, y = py }
		give("start")
		speakNext(now)
		return
	end
	if state.start and (px ~= state.start.x or py ~= state.start.y) then
		give("moved")
	end
	if countVisible("item") > 0 then
		give("item")
	end
	if countVisible("container") > 0 then
		give("chest")
	end
	if countVisible("enemy") > 0 then
		give("enemy")
		if not state.enemiesAtFirstSight then
			state.enemiesAtFirstSight = countAliveEnemies()
		end
	end
	if state.enemiesAtFirstSight and countAliveEnemies() < state.enemiesAtFirstSight then
		give("kill")
	end
	if doorInSight(px, py) and state.given.moved then
		give("door")
	end
	if nearRunStart(px, py) then
		give("finish")
	end
end)

return TutorialHints
