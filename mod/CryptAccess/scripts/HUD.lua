-- HUD keys: the standing state a sighted player reads off the screen.
--   H health   G gold and diamonds   I inventory (fills the Inventory buffer)
--   L level, song time left and exit state   M groove chain (coin multiplier)
--   C close surroundings: the four tiles next to the player

local CurrentLevel = require("necro.game.level.CurrentLevel")
local Currency = require("necro.game.item.Currency")
local Entities = require("system.game.Entities")
local GrooveChain = require("necro.game.character.GrooveChain")
local Health = require("necro.game.character.Health")
local Inventory = require("necro.game.item.Inventory")
local LevelExit = require("necro.game.tile.LevelExit")
local Music = require("necro.audio.Music")
local Action = require("necro.game.system.Action")
local Controls = require("necro.config.Controls")
local Text = require("CryptAccess.Text")

local Buffers = require("CryptAccess.Buffers")
local Help = require("CryptAccess.Help")
local Keys = require("CryptAccess.Keys")
local ReviewCursor = require("CryptAccess.ReviewCursor")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")
local Status = require("CryptAccess.Status")

local HUD = {}

--- A count of half hearts as words: 5 -> "2 and a half", 1 -> "half".
function HUD.hearts(halves)
	halves = math.floor((halves or 0) + 0.5)
	local whole = math.floor(halves / 2)
	if halves % 2 == 0 then
		return tostring(whole)
	elseif whole == 0 then
		return Strings.get("num.half")
	end
	return Strings.get("num.andHalf", { n = whole })
end

--- Hearts as spoken text. Player health counts half hearts.
function HUD.healthText(entity)
	entity = entity or World.player()
	if not entity or not entity.health then
		return ""
	end
	local okCur, current = pcall(Health.getCurrentHealth, entity)
	local okMax, maximum = pcall(Health.getMaxHealth, entity)
	current = okCur and current or entity.health.health
	maximum = okMax and maximum or entity.health.maxHealth
	-- Health counts half hearts when the health bar shows half hearts (most characters); characters
	-- with a whole-heart bar (Chaunter) count whole hearts.
	if entity.healthBarHalfHearts and not entity.healthBarFullHearts then
		return Strings.get("hud.hearts", { current = HUD.hearts(current), max = HUD.hearts(maximum) })
	elseif entity.controllable then
		return Strings.get("hud.hearts", { current = current, max = maximum })
	end
	return Strings.get("hud.health", { current = current, max = maximum })
end

function HUD.health()
	local lines = { HUD.healthText() }
	for _, line in ipairs(Status.healthExtras()) do
		lines[#lines + 1] = line
	end
	Speech.say(table.concat(lines, ". "), true)
end

function HUD.currencyText()
	local p = World.player()
	if not p then
		return ""
	end
	local okG, gold = pcall(Currency.get, p, Currency.Type.GOLD)
	local okD, diamonds = pcall(Currency.get, p, Currency.Type.DIAMOND)
	return Strings.get("hud.currency", { gold = okG and gold or 0, diamonds = okD and diamonds or 0 })
end

function HUD.currency()
	Speech.say(HUD.currencyText(), true)
end

local SLOTS = { "weapon", "shovel", "body", "head", "feet", "torch", "ring", "spell", "action", "bomb", "misc", "shield" }

local function itemName(item)
	if type(item) == "number" then
		item = Entities.getEntityByID(item)
	end
	if not item then
		return nil
	end
	local name = World.name(item)
	-- Huge stacks mean "infinite" (Eli's bombs): the name already says so.
	if item.itemStack and (item.itemStack.quantity or 1) > 1 and (item.itemStack.quantity or 1) < 100000 then
		name = Strings.get("hud.stack", { name = name, count = item.itemStack.quantity })
	end
	-- What the game shows on the slot: spell cooldown, ammo, kill counter, combo (Status.lua).
	local label = Status.slotLabel(item.id)
	if label then
		name = name .. " (" .. label .. ")"
	end
	return name
end

--- One line per filled slot: "Weapon: Dagger".
function HUD.inventoryLines()
	local p = World.player()
	local lines = {}
	if not p then
		return lines
	end
	local known = {}
	for _, slot in ipairs(SLOTS) do
		local ok, items = pcall(Inventory.getItemsInSlot, p, slot)
		if ok and type(items) == "table" and #items > 0 then
			local names = {}
			for _, item in ipairs(items) do
				known[type(item) == "number" and item or (type(item) == "table" and item.id) or 0] = true
				local name = itemName(item)
				if name then
					names[#names + 1] = name
				end
			end
			if #names > 0 then
				lines[#lines + 1] = Strings.get("slot." .. slot) .. ": " .. Strings.join(names)
			end
		end
	end
	for _, line in ipairs(Status.otherSlotLines(known)) do
		lines[#lines + 1] = line
	end
	return lines
end

local ACTIONS = { "ITEM_1", "ITEM_2", "BOMB", "THROW", "SPELL_1", "SPELL_2" }

--- Key bindings of the item actions, as the game's HUD shows them under each slot.
function HUD.controlLines()
	local lines = {}
	-- Characters such as Klarinetta and Suzu remap item actions (component actionRemap), as the game's
	-- HUD does, unless the player turned remapping off in the controls (Preference IGNORE_REMAP).
	local p = World.player()
	local remap = p and p.actionRemap and p.actionRemap.map
	local okPref, ignoreRemap = pcall(Controls.getPreference, 1, Controls.Preference.IGNORE_REMAP)
	if okPref and ignoreRemap then
		remap = nil
	end
	for _, name in ipairs(ACTIONS) do
		local id = Action.Special[name]
		if remap and remap[id] then
			id = remap[id]
		end
		local ok, bind = pcall(Controls.getActionKeyBind, id)
		if ok and bind and bind ~= Controls.NONE then
			local okName, friendly = pcall(Controls.getFriendlyName, bind)
			local text = Text.clean(okName and friendly or bind)
			if text ~= "" then
				lines[#lines + 1] = Strings.get("action." .. name) .. ": " .. text
			end
		end
	end
	return lines
end

function HUD.inventory()
	local lines = HUD.inventoryLines()
	local slotCount = #lines
	for _, line in ipairs(HUD.controlLines()) do
		lines[#lines + 1] = line
	end
	if slotCount == 0 then
		-- No items (the tutorial): the item key combinations are still one Ctrl+Up away.
		Buffers.set("inventory", { Strings.get("hud.noItems"), unpack(lines) }, true)
		Speech.say(Strings.get("hud.noItems"), true)
		return
	end
	Buffers.set("inventory", lines, true)
	Speech.say(Strings.get("hud.inventory", { count = slotCount }) .. " " .. lines[1], true)
end

function HUD.levelText()
	local parts = {}
	local ok, lobby = pcall(CurrentLevel.isLobby)
	local okName, levelName = pcall(CurrentLevel.getName)
	if ok and lobby then
		parts[#parts + 1] = Strings.get("hud.lobby")
		-- What is here, from the scanner's own list (PageDown browses it, N walks there).
		local okSum, summary = pcall(function()
			return require("CryptAccess.Scanner").summary()
		end)
		if okSum and summary then
			parts[#parts + 1] = Strings.get("hud.lobbyHere", { summary = summary })
		end
	elseif okName and type(levelName) == "string" and levelName:lower():find("tutorial") then
		parts[#parts + 1] = Strings.get("hud.tutorial")
	else
		local okD, depth = pcall(CurrentLevel.getDepth)
		local okF, floor = pcall(CurrentLevel.getFloor)
		if okD and depth then
			parts[#parts + 1] = Strings.get("hud.level", { depth = depth, floor = okF and floor or "?" })
		end
		local okB, isBoss = pcall(CurrentLevel.isBoss)
		if okB and isBoss then
			parts[#parts + 1] = Strings.get("hud.bossFloor")
		end
		local okRoom, room = pcall(function()
			return require("CryptAccess.Rooms").current()
		end)
		if okRoom and room then
			parts[#parts + 1] = Strings.get("hud.inRoom", { room = room })
		end
		local okT, timeLeft = pcall(function()
			if Music.isMusicLooping() then
				return nil
			end
			return Music.getMusicLength() - Music.getMusicTime()
		end)
		if okT and type(timeLeft) == "number" and timeLeft > 0 then
			local minutes = math.floor(timeLeft / 60)
			local seconds = math.floor(timeLeft % 60)
			parts[#parts + 1] = Strings.get("hud.songLeft", { minutes = minutes, seconds = seconds })
		end
		local okU, unlocked = pcall(LevelExit.isUnlocked)
		if okU and not unlocked then
			parts[#parts + 1] = Strings.get("hud.exitLocked")
		end
	end
	-- Win streak, Deathless win count, speedrun timer (Overlays.lua).
	local okExtra, extras = pcall(function()
		return require("CryptAccess.Overlays").levelExtras()
	end)
	if okExtra and type(extras) == "table" then
		for _, line in ipairs(extras) do
			parts[#parts + 1] = line
		end
	end
	return table.concat(parts, ". ")
end

function HUD.level()
	Speech.say(HUD.levelText(), true)
end

function HUD.grooveText()
	local p = World.player()
	if not p then
		return ""
	end
	local ok, multiplier = pcall(GrooveChain.getCoinMultiplier, p)
	if not ok then
		multiplier = 1
	end
	return Strings.get("hud.multiplier", { n = multiplier })
end

function HUD.groove()
	Speech.say(HUD.grooveText(), true)
end

--- The four neighbouring tiles, in the order up, right, down, left.
function HUD.surroundings()
	local px, py = World.playerPosition()
	if not px then
		return
	end
	local lines = {}
	local dirs = {
		{ 0, -1, "dirname.up" }, { 1, 0, "dirname.right" }, { 0, 1, "dirname.down" }, { -1, 0, "dirname.left" },
	}
	for _, d in ipairs(dirs) do
		local text = ReviewCursor.describe(px + d[1], py + d[2])
		lines[#lines + 1] = Strings.get(d[3]) .. ": " .. text
	end
	local here = ReviewCursor.describe(px, py)
	Buffers.set("surroundings", lines, true)
	Speech.say(table.concat(lines, ". ") .. ". " .. Strings.get("hud.here", { tile = here }), true)
end

local inGame = World.playing

Keys.bind({ key = "h", id = "hudHealth", when = inGame, fn = HUD.health })
Keys.bind({ key = "g", id = "hudCurrency", when = inGame, fn = HUD.currency })
Keys.bind({ key = "i", id = "hudInventory", when = inGame, fn = HUD.inventory })
Keys.bind({ key = "l", id = "hudLevel", when = inGame, fn = HUD.level })
Keys.bind({ key = "m", id = "hudGroove", when = inGame, fn = HUD.groove })
Keys.bind({ key = "c", id = "hudSurroundings", when = inGame, fn = HUD.surroundings })

return HUD
