-- Picture descriptions: what characters, enemies, bosses and shopkeepers look like and how they behave,
-- the title screens, and the look of each zone. The texts live in the Desc*.lua tables under
-- "desc.<EntityType>" and "scene.<name>"; they were written from the game's own art (bestiary
-- portraits, boss splash screens, sprites, cutscene frames) and its entity data (AI, spells, components).
-- Variants share their family's text: "Skeleton2Headless" falls back to "Skeleton2", then "Skeleton".

local CurrentLevel = require("necro.game.level.CurrentLevel")
local Entities = require("system.game.Entities")

local Config = require("CryptAccess.Config")
local Strings = require("CryptAccess.Strings")

local Describe = {}

-- Variants whose text is another variant's (same look and behaviour).
local ALIAS = {
	Skeleton3 = "Skeleton2",
	Skeletonknight3 = "Skeletonknight2",
	Armoredskeleton3 = "Armoredskeleton2",
	Monkey2 = "Monkey",
	Trapchest2 = "Trapchest",
	Trapchest3 = "Trapchest",
	Golem2 = "Golem",
	Golem3Gooless = "Golem3",
	Necrodancer2Phase2 = "Necrodancer2",
	NecrodancerPhase2 = "Necrodancer",
	Swarmsarcophagus = "Sarcophagus",
	Toughsarcophagus = "Sarcophagus",
	Trainingsarcophagus = "Sarcophagus",
	ConductorSarcophagus = "Sarcophagus",
}

-- Suffixes of variant type names, tried in this order when a type has no text of its own.
local SUFFIXES = { "Dancer", "Headless", "Angry", "Unshelled", "Promoted", "Extracted", "Gooless", "Activated",
	"Fallen", "Phase%d+", "Red", "Yellow" }

local keyCache = {}

--- The description key for an entity type (its own, a variant's or its family's), or nil.
function Describe.keyFor(typeName)
	if type(typeName) ~= "string" or typeName == "" then
		return nil
	end
	local cached = keyCache[typeName]
	if cached ~= nil then
		return cached or nil
	end
	local candidates = {}
	local function add(name)
		if name and name ~= "" then
			candidates[#candidates + 1] = ALIAS[name] or name
		end
	end
	add(typeName)
	local base = typeName
	for _, suffix in ipairs(SUFFIXES) do
		local stripped = base:gsub(suffix .. "$", "")
		if stripped ~= base and stripped ~= "" then
			base = stripped
			add(base)
		end
	end
	-- Synchrony's co-op enemies are versions of the classic ones ("Sync_CoopGhost").
	if base:find("^Sync_Coop") then
		base = base:gsub("^Sync_Coop", "")
		add(base)
	end
	add((base:gsub("%d+$", "")))
	local found = false
	for _, name in ipairs(candidates) do
		if Strings.maybe("desc." .. name) then
			found = name
			break
		end
	end
	keyCache[typeName] = found
	return found or nil
end

--- The picture description of an entity type, or nil.
function Describe.forType(typeName)
	local key = Describe.keyFor(typeName)
	return key and Strings.get("desc." .. key) or nil
end

local imageTypes = false

--- The entity type whose bestiary portrait or boss splash is this image file, or nil.
function Describe.typeForImage(image)
	if type(image) ~= "string" or image == "" then
		return nil
	end
	if not imageTypes then
		imageTypes = {}
		local ok = pcall(function()
			for _, proto in Entities.prototypesWithComponents({ "bestiary" }) do
				local okImage, path = pcall(function()
					return proto.bestiary.image
				end)
				-- The first type with an image wins: the base type comes before its variants.
				if okImage and type(path) == "string" and not imageTypes[path] then
					imageTypes[path] = proto.name
				end
			end
		end)
		if not ok then
			imageTypes = {}
		end
	end
	return imageTypes[image]
end

--- Description for an image shown by the game (bestiary dialogs), or nil.
function Describe.forImage(image)
	return Describe.forType(Describe.typeForImage(image))
end

local function hearts(halves)
	halves = math.floor((halves or 0) + 0.5)
	local whole = math.floor(halves / 2)
	if halves % 2 == 0 then
		return tostring(whole)
	elseif whole == 0 then
		return Strings.get("num.half")
	end
	return Strings.get("num.andHalf", { n = whole })
end

local function field(entity, component, name)
	local ok, value = pcall(function()
		return entity[component][name]
	end)
	if ok then
		return value
	end
end

--- Live facts about an enemy: how hard it hits and how often it moves.
function Describe.facts(entity)
	local lines = {}
	-- Shopkeepers and lobby people are enemies to the game, but their attack is a punishment, not a fact
	-- the player needs.
	if not entity or not entity.enemy or entity.shopkeeper or entity.greetable or entity.interactable then
		return lines
	end
	local damage = field(entity, "innateAttack", "damage")
	-- Harmless things carry placeholder values (a green slime "hits" for 100); leave those out.
	if type(damage) == "number" and damage > 0 and damage <= 40 then
		lines[#lines + 1] = Strings.get("detail.damage", { hearts = hearts(damage) })
	end
	local interval = field(entity, "beatDelay", "interval")
	local aiType = field(entity, "ai", "id")
	local okIdle, idle = pcall(function()
		return require("necro.game.enemy.ai.AI").Type.IDLE
	end)
	if type(interval) == "number" and interval >= 1 and aiType ~= nil and not (okIdle and aiType == idle) then
		if interval == 1 then
			lines[#lines + 1] = Strings.get("detail.movesEveryBeat")
		else
			lines[#lines + 1] = Strings.get("detail.movesEvery", { n = interval })
		end
	end
	return lines
end

--- Description lines for an entity in the world: its picture, then its live facts.
function Describe.forEntity(entity)
	local lines = {}
	if not entity then
		return lines
	end
	local typeName = entity.name
	if entity.interactableSelectCharacter then
		typeName = field(entity, "interactableSelectCharacter", "characterType") or typeName
	end
	local text = Describe.forType(typeName)
	if text then
		lines[#lines + 1] = text
	end
	for _, line in ipairs(Describe.facts(entity)) do
		lines[#lines + 1] = line
	end
	return lines
end

--- Remembers that a kind of thing was described, so the first-sight announcement skips it.
function Describe.markSeen(typeName)
	local key = Describe.keyFor(typeName)
	if key then
		Config.markSeen(key)
	end
end

-- Title and splash images (cutscene SPLASH scenes) and their description keys.
local TITLE_IMAGES = {
	{ "mainmenu%.png", "scene.title.necrodancer" },
	{ "amplified_titlescreen", "scene.title.amplified" },
	{ "Synchrony_LoadingPage", "scene.title.synchrony" },
	{ "Halloween", "scene.title.halloween" },
	{ "Christmas", "scene.title.christmas" },
}

function Describe.forSplash(image)
	image = tostring(image or "")
	for _, entry in ipairs(TITLE_IMAGES) do
		if image:find(entry[1]) then
			return Strings.get(entry[2])
		end
	end
end

local lastZone = false

--- The look of the level just entered: said once per zone in a run, and on boss floors.
function Describe.sceneForLevel()
	if not Config.get("describeScenes") then
		return nil
	end
	local okLobby, lobby = pcall(CurrentLevel.isLobby)
	if okLobby and lobby then
		lastZone = false
		return nil
	end
	local okBoss, boss = pcall(CurrentLevel.isBoss)
	if okBoss and boss then
		lastZone = false
		local okType, bossType = pcall(CurrentLevel.getBossType)
		local okName, bossName = pcall(function()
			return require("necro.game.level.Boss").Type.names[bossType]
		end)
		if okType and okName and type(bossName) == "string" then
			local special = Strings.maybe("scene.boss." .. bossName)
			if special then
				return special
			end
		end
		return Strings.get("scene.boss")
	end
	-- A new run (first floor) always gets its zone described, even straight after the tutorial.
	local okDepth, depth = pcall(CurrentLevel.getDepth)
	local okFloor, floor = pcall(CurrentLevel.getFloor)
	local okName, levelName = pcall(CurrentLevel.getName)
	if okName and type(levelName) == "string" and levelName:lower():find("tutorial") then
		lastZone = false
	elseif okDepth and okFloor and depth == 1 and floor == 1 then
		lastZone = false
	end
	local okZone, zone = pcall(CurrentLevel.getZone)
	if not okZone or type(zone) ~= "number" or zone == lastZone then
		return nil
	end
	lastZone = zone
	return Strings.maybe("scene.zone" .. zone)
end

return Describe
