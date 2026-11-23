-- What a sighted player sees happen in a fight, spoken as it happens (setting "describe.combat"):
--   enemies that grab you and let go, freezing and confusion on you, charges, sleeping enemies and
--   mimics waking up, parries, the spells enemies cast (fire and ice breath, lightning, wind,
--   confusion, summons, explosions) and enemies that appear out of nowhere next to you.
-- Also the first-sight description: the first time a kind of enemy comes into view, its picture
-- description is spoken once (setting "describe.newEnemies"; remembered across launches).

local Entities = require("system.game.Entities")
local Timer = require("system.utils.Timer")

local Config = require("CryptAccess.Config")
local Describe = require("CryptAccess.Describe")
local Events = require("CryptAccess.Events")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Combat = {}

local function enabled()
	return Config.get("describeCombat") and World.playing()
end

local function visibleOther(entity)
	return type(entity) == "table" and entity.position and not World.isPlayer(entity) and World.isVisible(entity)
end

local function where(x, y)
	local px, py = World.playerPosition()
	if not px or type(x) ~= "number" then
		return ""
	end
	return World.direction(x - px, y - py)
end

local DIRECTION_KEYS = {
	[1] = "dirname.right", [2] = "dirname.upRight", [3] = "dirname.up", [4] = "dirname.upLeft",
	[5] = "dirname.left", [6] = "dirname.downLeft", [7] = "dirname.down", [8] = "dirname.downRight",
}

-- States the player is in, so the "free again" lines only follow a real grab, freeze or confusion
-- (the game also sends unfreeze and unconfuse when nothing was wrong, for example on a new level).
local held = { grab = false, freeze = false, confuse = false }

-- Grabs: monkeys, tar monsters, water balls, gorgons, cursed wraiths.
event.objectGrab.add("cryptAccessGrab", { order = "sound", sequence = 50 }, function(ev)
	if enabled() and World.isPlayer(ev.victim) and ev.entity then
		held.grab = true
		Events.say(Strings.get("combat.grabbed", { name = World.name(ev.entity) }))
	end
end)

event.objectUngrab.add("cryptAccessUngrab", { order = "drops", sequence = 50 }, function(ev)
	if held.grab and World.isPlayer(ev.victim) then
		held.grab = false
		if enabled() then
			Events.say(Strings.get("combat.released"))
		end
	end
end)

event.objectFreeze.add("cryptAccessFreeze", { order = "animation", sequence = 50 }, function(ev)
	if enabled() and World.isPlayer(ev.entity) then
		held.freeze = true
		Events.say(Strings.get("combat.frozen"))
	end
end)

event.objectUnfreeze.add("cryptAccessUnfreeze", { order = "attackability", sequence = 50 }, function(ev)
	if held.freeze and World.isPlayer(ev.entity) then
		held.freeze = false
		if enabled() then
			Events.say(Strings.get("combat.thawed"))
		end
	end
end)

event.objectConfuse.add("cryptAccessConfuse", { order = "voice", sequence = 50 }, function(ev)
	if enabled() and World.isPlayer(ev.entity) then
		held.confuse = true
		Events.say(Strings.get("combat.confused"))
	end
end)

event.objectUnconfuse.add("cryptAccessUnconfuse", { order = "deaggro", sequence = 50 }, function(ev)
	if held.confuse and World.isPlayer(ev.entity) then
		held.confuse = false
		if enabled() then
			Events.say(Strings.get("combat.unconfused"))
		end
	end
end)

-- Minotaurs, armadillos, headless skeletons and others that run at you in a straight line.
event.objectBeginCharge.add("cryptAccessCharge", { order = "sound", sequence = 50 }, function(ev)
	local e = ev.entity
	if enabled() and visibleOther(e) and e.enemy then
		Events.say(Strings.get("combat.charge", { name = World.name(e), where = where(e.position.x, e.position.y) }), true)
	end
end)

-- Mimics, fake walls, gargoyles, tar monsters and sleeping goblins coming to life.
event.objectProvoke.add("cryptAccessProvoke", { order = "voice", sequence = 50 }, function(ev)
	local e = ev.entity
	if enabled() and visibleOther(e) and (e.stasisUntilProvoked or e.sleepWhileUnprovoked) then
		Events.say(Strings.get("combat.wakes", { name = World.name(e), where = where(e.position.x, e.position.y) }), true)
	end
end)

event.objectParry.add("cryptAccessParry", { order = "flyaway", sequence = 50 }, function(ev)
	local e = ev.entity
	if enabled() and visibleOther(e) then
		Events.say(Strings.get("combat.parry", { name = World.name(e) }))
	end
end)

-- Spells cast by enemies, keyed by spell type. "dir" spells say which way they go.
local SPELLS = {
	SpellcastFireballDragon = { key = "combat.spell.fireBreath", dir = true },
	SpellcastIceBlastDragon = { key = "combat.spell.iceBreath", dir = true },
	SpellcastFireballLute = { key = "combat.spell.fireBreath", dir = true },
	SpellcastElectricOrb = { key = "combat.spell.lightning", dir = true },
	SpellcastMageWind = { key = "combat.spell.wind" },
	SpellcastLichConfusion = { key = "combat.spell.confusion" },
	SpellcastReanimate = { key = "combat.spell.raise" },
	-- SpellcastSpawnMummy is left out: it is cast on every move even when the spawn cap is reached, and a
	-- real new mummy is announced with its position by the spawn watch below.
	SpellcastSpores = { key = "combat.spell.spores" },
	SpellcastSpores2 = { key = "combat.spell.spores" },
	SpellcastExplosion = { key = "combat.spell.explosion", at = true },
	SpellcastExplosionLarge = { key = "combat.spell.explosion", at = true },
	SpellcastExplosionPixie = { key = "combat.spell.explosion", at = true },
}

event.spellcast.add("cryptAccessSpells", { order = "sound", sequence = 50 }, function(ev)
	if not enabled() then
		return
	end
	local spellName = type(ev.entity) == "table" and ev.entity.name
	local spec = spellName and SPELLS[spellName]
	local caster = ev.caster
	if not spec or type(caster) ~= "table" or World.isPlayer(caster) then
		return
	end
	if spec.at then
		-- Explosions are about the place, whoever lit them (the player's bombs included).
		local okVisible, visible = pcall(function()
			return World.isTileVisible(ev.x, ev.y)
		end)
		if okVisible and visible then
			Events.say(Strings.get(spec.key, { where = where(ev.x, ev.y) }), true)
		end
		return
	end
	if not visibleOther(caster) then
		return
	end
	local text = Strings.get(spec.key, { name = World.name(caster) })
	if spec.dir and DIRECTION_KEYS[ev.direction] then
		text = text .. ", " .. Strings.get("combat.heading", { dir = Strings.get(DIRECTION_KEYS[ev.direction]) })
	end
	Events.say(text, true)
end)

-- Enemies that appear during play (apparitions, summons, eggs hatching): recorded at spawn and spoken
-- once they are visible (visibility is computed after the spawn event).
local levelStartedAt = 0
local pendingSpawns = {}

event.gameStateLevel.add("cryptAccessCombatLevel", { order = "levelLoadingDone", sequence = 51 }, function()
	levelStartedAt = Timer.getGlobalTime()
	pendingSpawns = {}
	held.grab, held.freeze, held.confuse = false, false, false
end)

local CurrentLevel = require("necro.game.level.CurrentLevel")

event.objectSpawn.add("cryptAccessSpawn", { order = "beatDelay", sequence = 50 }, function(ev)
	local e = ev.entity
	local okLoading, loading = pcall(CurrentLevel.isLoading)
	if okLoading and loading then
		return
	end
	if e and e.enemy and e.health and not e.boss and Timer.getGlobalTime() - levelStartedAt > 1.5 then
		pendingSpawns[#pendingSpawns + 1] = { id = e.id, at = Timer.getGlobalTime() }
	end
end)

local function flushSpawns()
	if #pendingSpawns == 0 then
		return
	end
	local now = Timer.getGlobalTime()
	local keep = {}
	local spoken = {}
	for _, spawn in ipairs(pendingSpawns) do
		local e = Entities.getEntityByID(spawn.id)
		if e and e.position and World.isVisible(e) then
			local name = World.name(e)
			if not spoken[name] and enabled() then
				spoken[name] = true
				Events.say(Strings.get("combat.appears", { name = name, where = where(e.position.x, e.position.y) }))
			end
		elseif e and now - spawn.at < 1 then
			keep[#keep + 1] = spawn
		end
	end
	pendingSpawns = keep
end

-- First sight of each kind of enemy (checked a few times a second).
local nextCheck = 0
local announcedThisRun = {}

local function firstSight()
	if not Config.get("describeNew") or not World.playing() then
		return
	end
	for e in Entities.entitiesWithComponents({ "enemy", "position" }) do
		local category = World.category(e)
		-- Bosses are described by their splash screen (ScreenText).
		if category == "enemy" and not e.boss and World.isVisible(e) then
			local key = Describe.keyFor(e.name)
			if key and not announcedThisRun[key] and not Config.wasSeen(key) then
				announcedThisRun[key] = true
				Config.markSeen(key)
				Events.say(Strings.get("describe.new", { name = World.name(e), desc = Strings.get("desc." .. key) }))
				return -- one at a time; the next one follows on a later check
			end
		end
	end
end

event.tick.add("cryptAccessCombatPoll", { order = "hud", sequence = 51 }, function()
	flushSpawns()
	local now = Timer.getGlobalTime()
	if now >= nextCheck then
		nextCheck = now + 0.25
		local ok, err = pcall(firstSight)
		if not ok then
			log.warn("Combat: first sight failed: %s", tostring(err))
		end
	end
end)

return Combat
