-- Gameplay events spoken as they happen (queued, never interrupting) and kept in the Events buffer:
--   damage taken by the player (who hit, hearts left), hits and kills on enemies,
--   the player's death, each new level (depth, floor, boss, exit state), the exit unlocking.
-- Pickups, "Missed!", groove chain drops and gold come from the game's own flyaways (ScreenText).

local Character = require("necro.game.character.Character")
local CurrentLevel = require("necro.game.level.CurrentLevel")
local LevelExit = require("necro.game.tile.LevelExit")

local Buffers = require("CryptAccess.Buffers")
local Config = require("CryptAccess.Config")
local HUD = require("CryptAccess.HUD")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Events = {}

local Dedupe = require("CryptAccess.Dedupe")

local function say(text, interrupt)
	if text and text ~= "" and not Dedupe.replaying() and Dedupe.first(text) then
		Buffers.addEvent(text)
		Speech.say(text, interrupt or false)
	end
end
Events.say = say

local function isLocalPlayer(entity)
	return World.isPlayer(entity)
end

local function attackerName(ev)
	local attacker = ev.attacker
	if type(attacker) == "table" and attacker.name then
		return World.name(attacker)
	end
	if type(ev.killerName) == "string" and ev.killerName ~= "" then
		return ev.killerName
	end
	return nil
end

event.objectTakeDamage.add("cryptAccessDamage", { order = "statistics", sequence = 50 }, function(ev)
	if ev.suppressed or not ev.entity or (ev.damage or 0) <= 0 then
		return
	end
	local victim = ev.entity
	if isLocalPlayer(victim) then
		local alive = Character.isAlive(victim)
		if not alive then
			return -- the death line says it
		end
		local who = attackerName(ev)
		local text
		if who then
			text = Strings.get("event.hurtBy", { who = who, damage = HUD.hearts(ev.damage), health = HUD.healthText(victim) })
		else
			text = Strings.get("event.hurt", { damage = HUD.hearts(ev.damage), health = HUD.healthText(victim) })
		end
		say(text)
	elseif isLocalPlayer(ev.attacker) and victim.health and Config.get("speakHits") then
		local name = World.name(victim)
		if Character.isAlive(victim) then
			say(Strings.get("event.hit", { name = name, health = victim.health.health }))
		else
			say(Strings.get("event.killed", { name = name }))
		end
	end
end)

-- The player's death is spoken with the run summary prompt (ScreenText), which names the killer.

event.objectCurrency.add("cryptAccessCurrency", { order = "statistics", sequence = 50 }, function(ev)
	if not isLocalPlayer(ev.entity) or type(ev.difference) ~= "number" or ev.difference == 0 then
		return
	end
	local total = (ev.oldAmount or 0) + ev.difference
	local key = tostring(ev.currency) == "diamond" and "event.diamonds" or "event.gold"
	if ev.difference > 0 then
		say(Strings.get(key, { n = ev.difference, total = total }))
	end
end)

local lastCharacter = false

local exitWasUnlocked = true
local levelAnnounced = false

event.gameStateLevel.add("cryptAccessLevelStart", { order = "levelLoadingDone", sequence = 50 }, function()
	levelAnnounced = false
	local ok, unlocked = pcall(LevelExit.isUnlocked)
	exitWasUnlocked = ok and unlocked or false
end)

event.tick.add("cryptAccessEventsPoll", { order = "hud", sequence = 50 }, function()
	if not World.inLevel() then
		return
	end
	if not levelAnnounced and World.playing() then
		levelAnnounced = true
		say(HUD.levelText())
	end
	local player = World.player()
	if player and player.name ~= lastCharacter then
		if lastCharacter then
			say(Strings.get("event.character", { name = World.name(player) }))
		end
		lastCharacter = player.name
	end
	local ok, unlocked = pcall(LevelExit.isUnlocked)
	-- The game announces the unlock with its own flyaway ("Exit stairs unlocked!"), spoken by ScreenText.
	exitWasUnlocked = ok and unlocked or exitWasUnlocked
end)

return Events
