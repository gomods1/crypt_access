-- Read-only model of the level around the player, built from game state:
-- the focused player entity, entity names and categories, visibility, tiles and relative directions.
-- Grid coordinates: x grows to the right, y grows downwards (screen down).

local Collision = require("necro.game.tile.Collision")
local Entities = require("system.game.Entities")
local Focus = require("necro.game.character.Focus")
local Inventory = require("necro.game.item.Inventory")
local Menu = require("necro.menu.Menu")
local ObjectMap = require("necro.game.object.Map")
local Player = require("necro.game.character.Player")
local Tile = require("necro.game.tile.Tile")
local Vision = require("necro.game.vision.Vision")

local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")

local World = {}

--- The player entity the HUD follows (handles spectating and replays), or the local player.
function World.player()
	local ok, entity = pcall(Focus.getFirst, Focus.Flag.HUD)
	if ok and entity and entity.position then
		return entity
	end
	ok, entity = pcall(Player.getPlayerEntity)
	if ok and entity and entity.position then
		return entity
	end
	return nil
end

--- True when entity is the player the HUD follows (entities are compared by id).
function World.isPlayer(entity)
	local p = World.player()
	return p ~= nil and type(entity) == "table" and entity.id ~= nil and entity.id == p.id
end

function World.playerPosition()
	local p = World.player()
	if p then
		return p.position.x, p.position.y
	end
end

--- True while a level is loaded and the player exists (dungeon, lobby, tutorial, training).
function World.inLevel()
	return World.player() ~= nil
end

--- True while the player is in a level with no menu in front (gameplay keys are live).
function World.playing()
	return World.player() ~= nil and not Menu.isOpen()
end

--- Splits a type name like "WeaponBroadsword" into words ("Weapon Broadsword").
local function cleanTypeName(name)
	name = tostring(name or "")
	name = name:gsub("^%u%l+_", ""):gsub("_", " ")
	name = name:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
	return name
end

function World.name(entity)
	if not entity then
		return ""
	end
	local name = entity.friendlyName and entity.friendlyName.name
	if type(name) == "string" and name ~= "" then
		return Text.clean(name)
	end
	if entity.worldLabel and entity.worldLabel.text ~= "" then
		-- Line breaks inside a label: a wrapped phrase continues in lower case, otherwise a new item.
		local lines = {}
		for line in tostring(entity.worldLabel.text):gmatch("[^" .. string.char(10) .. "]+") do
			line = Text.clean(line)
			if line ~= "" then
				lines[#lines + 1] = line
			end
		end
		return Text.joinWrapped(lines)
	end
	if entity.name == "CharacterSelectorLobbyRandom" then
		return Strings.get("npc.randomCharacter")
	end
	return cleanTypeName(entity.name)
end

--- Category of an entity, or nil when the player has no use for it (torches, triggers, effects).
function World.category(entity)
	if not entity or not entity.position then
		return nil
	end
	if entity.controllable and entity.controllable.playerID ~= 0 then
		if World.isPlayer(entity) then
			return nil
		end
		return "player"
	end
	if entity.shopkeeper then
		return "npc"
	end
	if entity.enemy and entity.health then
		return "enemy"
	end
	if entity.crateLike or entity.chestLike then
		return "container"
	end
	if entity.item then
		-- Items held by someone have no tile of their own.
		if entity.item.holder and entity.item.holder ~= 0 then
			return nil
		end
		return "item"
	end
	if entity.shrine then
		return "shrine"
	end
	if entity.interactableSelectCharacter or entity.interactable or entity.npcUnlockable then
		return "npc"
	end
	if entity.trap then
		-- Invisible triggers (start run, voice lines, lobby triggers) have no visibility.
		if entity.sprite and entity.visibility and not tostring(entity.name):find("^Trigger") then
			return "trap"
		end
		return nil
	end
	if entity.health and entity.attackable then
		return "enemy"
	end
	if entity.worldLabel then
		if Text.clean(entity.worldLabel.text) == "" then
			return nil
		end
		-- A label standing on stairs names them (lobby: "Zone 1", "Tutorial").
		local ok, info = pcall(Tile.getInfo, entity.position.x, entity.position.y)
		if ok and type(info) == "table" and info.name and tostring(info.name):find("Stairs") then
			return "exit"
		end
		return "label"
	end
	return nil
end

--- Whether a sighted player can see the entity right now.
function World.isVisible(entity)
	if entity.gameObject and entity.gameObject.tangible == false then
		return false
	end
	if entity.visibility then
		return entity.visibility.visible and true or false
	end
	-- Labels and triggers have no visibility component: use the tile's.
	local ok, revealed = pcall(Vision.isVisuallyRevealed, entity.position.x, entity.position.y)
	return ok and revealed or false
end

function World.isTileKnown(x, y)
	local ok, revealed = pcall(Vision.isVisuallyRevealed, x, y)
	return ok and revealed or false
end

function World.isTileVisible(x, y)
	local ok, visible = pcall(Vision.isVisible, x, y)
	return ok and visible or false
end

--- The player's dig strength: the best shovel's strength, else the entity's own.
function World.digStrength()
	local p = World.player()
	if not p then
		return 0
	end
	local best
	local ok, shovels = pcall(Inventory.getItemsInSlot, p, "shovel")
	if ok and type(shovels) == "table" then
		for _, item in ipairs(shovels) do
			if type(item) == "number" then
				item = Entities.getEntityByID(item)
			end
			if item and item.shovel and item.shovel.strength then
				best = math.max(best or -99, item.shovel.strength)
			end
		end
	end
	if not best and p.dig and p.dig.strength then
		best = p.dig.strength
	end
	return best or 0
end

local function hasBit(value, bitValue)
	return value and bitValue and bit.band(value, bitValue) ~= 0
end

--- Describes the tile at x, y: returns kind ("wall", "door", "floor", "exit", "empty"), and a phrase.
function World.describeTile(x, y)
	local ok, info = pcall(Tile.getInfo, x, y)
	if not ok or type(info) ~= "table" or not info.name then
		return "empty", Strings.get("tile.nothing")
	end
	local name = Text.clean(info.friendlyName or info.name)
	-- Decorative floor variants ("Dirt floor", "Grass floor") have no translation in the game.
	if info.isFloor and name:find(" floor$") then
		name = Strings.get("tile.floor")
	end
	local parts = { name }
	local kind = "floor"
	local collisionType = Collision.Type
	if info.isDoor then
		kind = "door"
	elseif info.isLocked then
		kind = "door"
		parts[#parts + 1] = Strings.get("tile.locked")
	elseif info.isWall then
		kind = "wall"
		local resistance = info.digResistance
		if resistance == nil or resistance == false or hasBit(info.collision, collisionType.BORDER) then
			parts[#parts + 1] = Strings.get("tile.unbreakable")
		elseif resistance <= World.digStrength() then
			parts[#parts + 1] = Strings.get("tile.diggable")
		else
			parts[#parts + 1] = Strings.get("tile.tooHard")
		end
	elseif info.descent or hasBit(info.collision, collisionType.EXIT) or tostring(info.name):find("Stairs") then
		kind = "exit"
		-- LockedStairs' own name already says locked; other stairs only get the word when needed.
		if (info.transformOnMinibossDeath or tostring(info.name):find("Locked")) and not tostring(info.name):find("^LockedStairs") then
			parts[#parts + 1] = Strings.get("tile.locked")
		end
	end
	return kind, table.concat(parts, ", "), info
end

--- True when the tile blocks walking (walls, level border, closed locked doors).
function World.isBlocking(x, y)
	local ok, info = pcall(Tile.getInfo, x, y)
	if not ok or type(info) ~= "table" or not info.name then
		return true
	end
	if info.isDoor then
		return false
	end
	return info.isWall or info.isLocked or false
end

--- Entities on a tile that the player cares about, with their categories.
function World.entitiesAt(x, y)
	local list = {}
	local ok, ids = pcall(ObjectMap.getAll, x, y)
	if not ok or type(ids) ~= "table" then
		return list
	end
	for _, id in ipairs(ids) do
		local e = Entities.getEntityByID(id)
		local category = e and World.category(e)
		if category and World.isVisible(e) then
			list[#list + 1] = { entity = e, category = category }
		end
	end
	return list
end

--- "2 left, 1 up" relative to the player. Empty offset gives "here".
function World.direction(dx, dy)
	local parts = {}
	if dx < 0 then
		parts[#parts + 1] = Strings.get("dir.left", { n = -dx })
	elseif dx > 0 then
		parts[#parts + 1] = Strings.get("dir.right", { n = dx })
	end
	if dy < 0 then
		parts[#parts + 1] = Strings.get("dir.up", { n = -dy })
	elseif dy > 0 then
		parts[#parts + 1] = Strings.get("dir.down", { n = dy })
	end
	if #parts == 0 then
		return Strings.get("dir.here")
	end
	return table.concat(parts, ", ")
end

--- Steps needed to reach a tile (diagonals do not exist in normal movement).
function World.steps(dx, dy)
	return math.abs(dx) + math.abs(dy)
end

return World
