-- Positional audio cues (template rule 19: each cue sounds where its thing is, relative to the player).
--   Left/right: stereo position from the horizontal offset.  Up/down: pitch (higher = above you,
--   lower = below you).  Distance: volume.
-- On every beat (or after every turn in no-beat mode): the nearest visible enemies in range, each with
-- the "enemy" sound, or "danger" when it is next to you and acts on the next beat; items in range
-- with the "item" sound. After each of the player's moves: walls on the four sides ("wall").
-- B toggles a beacon on the scanner's selected target (or the nearest exit) that sounds every beat.

local Audio = require("system.game.Audio")
local Beatmap = require("necro.audio.Beatmap")
local Entities = require("system.game.Entities")
local GameState = require("necro.client.GameState")

local Config = require("CryptAccess.Config")
local Native = require("CryptAccess.Native")
local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Cues = {}

local stats = { played = 0, last = "" }

--- Debug counters (DevConsole): how many cues played and the last one.
function Cues.stats()
	return stats
end

local SOUND_DIR = "mods/CryptAccess/sounds/"
local MAX_ENEMY_CUES = 3
local MAX_ITEM_CUES = 2

--- Plays a cue file for a thing at offset (dx, dy) from the player.
function Cues.play(name, dx, dy, volume)
	if not Native.available then
		return -- no speech setup on this machine: stay silent (see Keys.lua)
	end
	dx, dy = dx or 0, dy or 0
	local ok, id = pcall(Audio.createStaticSource, SOUND_DIR .. name .. ".ogg", false, 0)
	if not ok or not id then
		return
	end
	-- Horizontal position on a half circle in front of the listener: fully left at 3 tiles or more.
	local h = math.max(-1, math.min(1, dx / 3))
	local z = -math.sqrt(math.max(0, 1 - h * h))
	local pitch = 2 ^ (math.max(-4, math.min(4, -dy)) * 0.12)
	local distance = math.abs(dx) + math.abs(dy)
	local radius = Config.get("cueRadius") or 4
	-- Distance lowers the volume to at most half, so far cues still stand out from the music
	-- (measured with the per-application audio meter, tools/cue_meter.py).
	local falloff = 1 - math.min(0.5, math.max(0, distance - 1) / (radius + 1))
	pcall(Audio.setVolume, id, (volume or 1) * falloff * (Config.get("cueVolume") or 0.9))
	pcall(Audio.setPitch, id, pitch)
	pcall(Audio.setPosition, id, h, 0, z)
	pcall(Audio.setMinimumDistance, id, 1)
	pcall(Audio.setAttenuation, id, 0)
	pcall(Audio.play, id)
	stats.played = stats.played + 1
	stats.last = string.format("%s dx=%d dy=%d", name, dx, dy)
end

--- Plays a non-positional cue (freeze, metronome).
function Cues.playCentered(name, volume)
	Cues.play(name, 0, 0, volume)
end

local beacon = { active = false }

local function isPaused()
	local ok, paused = pcall(GameState.isPaused)
	return ok and paused
end

local function enemyCues(px, py)
	local radius = Config.get("cueRadius") or 4
	local found = {}
	for e in Entities.entitiesWithComponents({ "position", "health" }) do
		local category = World.category(e)
		if category == "enemy" and World.isVisible(e) then
			local dx, dy = e.position.x - px, e.position.y - py
			local d = math.abs(dx) + math.abs(dy)
			if d <= radius and d > 0 then
				found[#found + 1] = { e = e, dx = dx, dy = dy, d = d }
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(#found, MAX_ENEMY_CUES) do
		local f = found[i]
		local soon = f.e.beatDelay and (f.e.beatDelay.counter or 1) <= 0
		local name = (f.d == 1 and soon) and "danger" or "enemy"
		Cues.play(name, f.dx, f.dy, 1)
	end
end

local function itemCues(px, py)
	local radius = Config.get("cueRadius") or 4
	local found = {}
	for e in Entities.entitiesWithComponents({ "position", "item" }) do
		if World.category(e) == "item" and World.isVisible(e) then
			local dx, dy = e.position.x - px, e.position.y - py
			local d = math.abs(dx) + math.abs(dy)
			if d <= radius and d > 0 then
				found[#found + 1] = { dx = dx, dy = dy, d = d }
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(#found, MAX_ITEM_CUES) do
		Cues.play("item", found[i].dx, found[i].dy, 0.6)
	end
end

local function beaconCue(px, py)
	if not beacon.active then
		return
	end
	if beacon.id then
		local e = Entities.getEntityByID(beacon.id)
		if not e or not e.position then
			beacon.active = false
			Speech.say(Strings.get("beacon.lost"), false)
			return
		end
		beacon.x, beacon.y = e.position.x, e.position.y
	end
	local dx, dy = beacon.x - px, beacon.y - py
	if dx ~= 0 or dy ~= 0 then
		-- Sound from the next turning point of the walkable route, which is itself a place.
		local Path = require("CryptAccess.Path")
		local okW, wx, wy = pcall(Path.nextWaypoint, beacon.x, beacon.y)
		if okW and wx then
			Cues.play(beacon.sound or "beacon", wx - px, wy - py, 1.2)
			return
		end
	end
	if dx == 0 and dy == 0 then
		beacon.active = false
		Speech.say(Strings.get("beacon.arrived"), false)
		return
	end
	Cues.play(beacon.sound or "beacon", dx, dy, 1.2)
end

function Cues.onBeat()
	if not World.playing() or isPaused() then
		return
	end
	local px, py = World.playerPosition()
	if not px then
		return
	end
	if Config.get("metronome") then
		Cues.playCentered("tick", 0.6)
	end
	if Config.get("cueEnemies") then
		enemyCues(px, py)
	end
	-- Lit bombs sound the urgent cue from where they are until they explode.
	local radius = Config.get("cueRadius") or 4
	for e in Entities.entitiesWithComponents({ "explosive", "position" }) do
		local dx, dy = e.position.x - px, e.position.y - py
		if math.abs(dx) + math.abs(dy) <= radius and World.isVisible(e) then
			Cues.play("danger", dx, dy, 1)
		end
	end
	if Config.get("cueItems") then
		itemCues(px, py)
	end
	beaconCue(px, py)
end

local function wallCues()
	if not Config.get("cueWalls") then
		return
	end
	local px, py = World.playerPosition()
	if not px then
		return
	end
	for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
		if World.isBlocking(px + d[1], py + d[2]) then
			Cues.play("wall", d[1] * 3, d[2], 0.35)
		end
	end
end

local lastBeat = false
local lastPos = false

local function rhythmIgnored()
	local ok, map = pcall(Beatmap.getPrimary)
	if not ok or not map then
		return true
	end
	local okI, ignored = pcall(map.isRhythmEffectivelyIgnored)
	return okI and ignored
end

event.tick.add("cryptAccessCues", { order = "sound", sequence = 50 }, function()
	if not World.inLevel() then
		lastBeat, lastPos = false, false
		return
	end
	-- Walls: after the player's position changes.
	local px, py = World.playerPosition()
	local pos = px and (px .. "," .. py) or false
	if pos ~= lastPos then
		if lastPos and not isPaused() then
			wallCues()
			if rhythmIgnored() then
				Cues.onBeat()
			end
		end
		lastPos = pos
	end
	if rhythmIgnored() then
		return
	end
	local ok, map = pcall(Beatmap.getPrimary)
	if not ok or not map then
		return
	end
	local okB, beat = pcall(map.getMusicBeat)
	if okB and type(beat) == "number" then
		beat = math.floor(beat)
		if beat ~= lastBeat then
			lastBeat = beat
			Cues.onBeat()
		end
	end
end)

--- B: beacon on the scanner's selected thing, or on the nearest exit when nothing is selected.
function Cues.toggleBeacon()
	if beacon.active then
		beacon.active = false
		Speech.say(Strings.get("beacon.off"), true)
		return
	end
	local Scanner = require("CryptAccess.Scanner")
	local Path = require("CryptAccess.Path")
	local target = Scanner.selected()
	local unexplored = Path.lastFrontier()
	if unexplored and (not target or (unexplored.time or 0) > Scanner.selectedTime()) then
		target = unexplored
	end
	if not target then
		Speech.say(Strings.get("beacon.noTarget"), true)
		return
	end
	beacon.active = true
	beacon.id = target.id
	beacon.x, beacon.y = target.x, target.y
	beacon.sound = target.category == "exit" and "exit" or "beacon"
	Speech.say(Strings.get("beacon.on", { name = target.name }), true)
end

event.gameStateLevel.add("cryptAccessBeaconReset", { order = "resetLevelVariables", sequence = 52 }, function()
	beacon.active = false
end)

Keys.bind({ key = "b", id = "beacon", when = World.playing, fn = Cues.toggleBeacon })

return Cues
