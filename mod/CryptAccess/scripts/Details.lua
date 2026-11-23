-- Detail lines (Ctrl+Up) for things the player focuses with the scanner or the review cursor.
-- Line 1 is what was just spoken; the rest are facts about that one thing only.

local Action = require("necro.game.system.Action")
local Entities = require("system.game.Entities")
local Health = require("necro.game.character.Health")
local LevelExit = require("necro.game.tile.LevelExit")
local PriceTag = require("necro.game.item.PriceTag")

local Describe = require("CryptAccess.Describe")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local Details = {}

local directionNames = {
	[1] = "dirname.right", [2] = "dirname.upRight", [3] = "dirname.up", [4] = "dirname.upLeft",
	[5] = "dirname.left", [6] = "dirname.downLeft", [7] = "dirname.down", [8] = "dirname.downRight",
}

local function add(lines, text)
	if type(text) == "string" and text ~= "" then
		lines[#lines + 1] = text
	end
end

--- Price line for an item for sale: "Price 25 gold, you can afford it".
function Details.price(entity)
	if not (entity.sale and entity.sale.priceTag and entity.sale.priceTag ~= 0) then
		return nil
	end
	local tag = Entities.getEntityByID(entity.sale.priceTag)
	local buyer = World.player()
	if not tag or not buyer then
		return nil
	end
	local ok, result = pcall(PriceTag.check, buyer, tag)
	if not ok or type(result) ~= "table" then
		return nil
	end
	local currencyKey = "price.gold"
	if tag.priceTagCostHealth then
		currencyKey = "price.health"
	elseif tag.priceTagCostCurrency and tostring(tag.priceTagCostCurrency.currency):lower():find("diamond") then
		currencyKey = "price.diamonds"
	end
	local line = Strings.get(currencyKey, { cost = result.effectiveCost or 0 })
	if result.affordable then
		return line .. ", " .. Strings.get("price.affordable")
	end
	return line .. ", " .. Strings.get("price.notAffordable")
end

function Details.health(entity)
	if not entity.health then
		return nil
	end
	local okCur, current = pcall(Health.getCurrentHealth, entity)
	local okMax, maximum = pcall(Health.getMaxHealth, entity)
	current = okCur and current or entity.health.health
	maximum = okMax and maximum or entity.health.maxHealth
	return Strings.get("detail.health", { current = current, max = maximum })
end

--- "Acts on the next beat" / "Acts in 2 beats".
function Details.nextMove(entity)
	if not entity.beatDelay then
		return nil
	end
	local counter = entity.beatDelay.counter or 0
	if entity.stun and (entity.stun.counter or 0) > 0 then
		return Strings.get("detail.stunned")
	end
	if counter <= 0 then
		return Strings.get("detail.actsNext")
	end
	return Strings.get("detail.actsIn", { n = counter + 1 })
end

function Details.facing(entity)
	local direction = entity.facingDirection and entity.facingDirection.direction
	local key = direction and directionNames[direction]
	if key then
		return Strings.get("detail.facing", { dir = Strings.get(key) })
	end
end

function Details.forEntity(entity)
	local lines = {}
	add(lines, Details.health(entity))
	-- Shopkeepers and caged or lobby people are enemies to the game, but their beat and facing mean nothing.
	local person = entity.shopkeeper or entity.greetable or entity.interactable or entity.npcUnlockable
	if (entity.enemy or entity.beatDelay) and not person then
		add(lines, Details.nextMove(entity))
		add(lines, Details.facing(entity))
	end
	if entity.stairLocker then
		add(lines, Strings.get("detail.stairLocker"))
	end
	add(lines, Details.price(entity))
	if entity.itemHintLabel and entity.itemHintLabel.text then
		add(lines, Text.clean(entity.itemHintLabel.text))
	end
	if entity.shrineHintLabel and entity.shrineHintLabel.text then
		add(lines, Text.clean(entity.shrineHintLabel.text))
	end
	if entity.worldLabel and entity.worldLabel.text and entity.friendlyName then
		add(lines, Text.clean(entity.worldLabel.text))
	end
	if entity.storage and entity.chestLike then
		add(lines, Strings.get("detail.chest"))
	end
	if entity.interactableToggleExtraMode then
		add(lines, Strings.get("detail.toggleMode"))
	end
	if entity.interactableSelectCharacter then
		add(lines, Strings.get("detail.selectCharacter"))
	end
	if entity.crateLike then
		add(lines, Strings.get("detail.crate"))
	end
	-- What it looks like and how it behaves (picture description), then damage and pace.
	local okDescribe, described = pcall(Describe.forEntity, entity)
	if okDescribe then
		for _, line in ipairs(described) do
			add(lines, line)
		end
	end
	return lines
end

function Details.forTile(x, y)
	local lines = {}
	local kind, phrase, info = World.describeTile(x, y)
	if kind == "exit" and info and info.transformOnMinibossDeath then
		local ok, unlocked = pcall(LevelExit.isUnlocked)
		if not (ok and unlocked) then
			add(lines, Strings.get("detail.exitLocked"))
		end
	end
	if info and info.isLocked then
		add(lines, Strings.get("detail.needsKey"))
	end
	if info and info.idleDamage then
		add(lines, Strings.get("detail.hotTile"))
	end
	if info and info.stepDamage then
		add(lines, Strings.get("detail.burnTile"))
	end
	if info and info.slippery then
		add(lines, Strings.get("detail.slippery"))
	end
	if info and info.sink then
		add(lines, Strings.get("detail.sink"))
	end
	return lines, phrase
end

--- Details buffer content for a scanner entry.
function Details.forScanEntry(entry, spoken)
	local lines = { spoken }
	local extra
	if entry.id then
		local e = Entities.getEntityByID(entry.id)
		extra = e and Details.forEntity(e) or {}
	else
		extra = Details.forTile(entry.x, entry.y)
	end
	for _, line in ipairs(extra) do
		lines[#lines + 1] = line
	end
	local px, py = World.playerPosition()
	if px then
		lines[#lines + 1] = Strings.get("detail.steps", { n = World.steps(entry.x - px, entry.y - py) })
	end
	return lines
end

return Details
