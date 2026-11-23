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
	-- Self-inflicted damage (Nocturna changing form, Tempo's curse on herself) has no "who".
	if type(attacker) == "table" and ev.entity and attacker.id == ev.entity.id then
		return nil
	end
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

event.itemConsume.add("cryptAccessItemUse", { order = "sound", sequence = 50 }, function(ev)
	if ev.holder and isLocalPlayer(ev.holder) and ev.item then
		say(Strings.get("event.used", { name = World.name(ev.item), health = HUD.healthText(ev.holder) }))
	end
end)

event.objectCurrency.add("cryptAccessCurrency", { order = "statistics", sequence = 50 }, function(ev)
	if not isLocalPlayer(ev.entity) or type(ev.difference) ~= "number" or ev.difference == 0 then
		return
	end
	local total = (ev.oldAmount or 0) + ev.difference
	local key = tostring(ev.currency) == "diamond" and "event.diamonds" or "event.gold"
	if ev.difference > 0 then
		say(Strings.get(key, { n = ev.difference, total = total }))
	else
		-- Spending (a purchase, a shrine): say what was paid and what is left.
		local spentKey = tostring(ev.currency) == "diamond" and "event.diamondsSpent" or "event.goldSpent"
		say(Strings.get(spentKey, { n = -ev.difference, total = total }))
	end
end)

local lastCharacter = false
local seenExplosives = {}
local lastWeaponID = false
local modeStates = {}

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
	if not levelAnnounced and World.inEditor() then
		levelAnnounced = true
		say(Strings.get("event.editor"))
	elseif not levelAnnounced and World.playing() then
		levelAnnounced = true
		say(HUD.levelText())
	end
	-- A thrown (or dropped) weapon: say where it landed, so it can be picked up again.
	local me = World.player()
	if me and me.inventory then
		local okW, weapons = pcall(function()
			return require("necro.game.item.Inventory").getItemsInSlot(me, "weapon")
		end)
		local current = okW and type(weapons) == "table" and weapons[1] or false
		if type(current) == "table" then
			current = current.id
		end
		if lastWeaponID and not current then
			local okE2, Ents2 = pcall(require, "system.game.Entities")
			local item = okE2 and Ents2.getEntityByID(lastWeaponID)
			local px, py = World.playerPosition()
			if item and item.position and px and not (item.item and item.item.holder and item.item.holder ~= 0) then
				say(Strings.get("event.weaponLanded", {
					name = World.name(item),
					where = World.direction(item.position.x - px, item.position.y - py),
				}))
			end
		end
		lastWeaponID = current or false
	end
	-- Lit bombs: say where they are and in how many beats they explode, once each.
	local okEnt, Ents = pcall(require, "system.game.Entities")
	if okEnt then
		local px, py = World.playerPosition()
		for e in Ents.entitiesWithComponents({ "explosive", "position" }) do
			if not seenExplosives[e.id] and px and World.isVisible(e) then
				seenExplosives[e.id] = true
				local beats = (e.beatDelay and e.beatDelay.counter or 2) + 1
				say(Strings.get("event.bomb", { where = World.direction(e.position.x - px, e.position.y - py), n = beats }), true)
			end
		end
	end
	-- Extra-mode altars in the lobby: say the mode and its new state when it is toggled.
	local okModes, Entities = pcall(require, "system.game.Entities")
	if okModes then
		for e in Entities.entitiesWithComponents({ "interactableToggleExtraMode" }) do
			local active = e.interactableToggleExtraMode.active and true or false
			local previous = modeStates[e.id]
			if previous ~= nil and previous ~= active then
				say(World.name(e), true)
			end
			modeStates[e.id] = active
		end
	end
	local player = World.player()
	-- Compare display names: Nocturna turning into a bat changes the entity type, not the character.
	local characterName = player and World.name(player)
	if characterName and characterName ~= lastCharacter then
		if lastCharacter and not World.inEditor() then
			say(Strings.get("event.character", { name = characterName }))
		end
		lastCharacter = characterName
	end
	local ok, unlocked = pcall(LevelExit.isUnlocked)
	-- The game announces the unlock with its own flyaway ("Exit stairs unlocked!"), spoken by ScreenText.
	exitWasUnlocked = ok and unlocked or exitWasUnlocked
end)

return Events
