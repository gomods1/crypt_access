-- Status the game only shows as numbers or text on screen, spoken for blind players:
--   * item slot labels: spell cooldowns, ammo, regeneration kill counters, combo counters, beat cooldowns
--     (captured from the game's own slot rendering, so they read exactly what a sighted player sees);
--   * Tempo's damage countdown (render/hud/DamageCountdownHUD.lua): on the H key, and "reset" after a kill;
--   * the heart transplant's "rhythm ignored" timer (render/hud/HeartbeatHUD.lua);
--   * the reason of a beat countdown: "Game begins in", "Pausing in", "Unpausing in" (client/Countdown.lua).

local Countdown = require("necro.client.Countdown")
local CurrentLevel = require("necro.game.level.CurrentLevel")
local Music = require("necro.audio.Music")

local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local Status = {}

---------------------------------------------------------------------------------------------------- slot labels
-- InventoryHUD.lua fires inventoryHUDRenderSlot once per slot each frame; ItemSlotRenderer.lua adds the labels
-- (beat and spell cooldowns, regeneration kills, combo, ammo, stack quantity, key binding, slot header) and
-- "labels" draws them. Order "labels", sequence -1 sees them all. Kept: everything except the key binding
-- (the I key lists those), the stack quantity (said as "name, count") and the slot's default name; a
-- replaced header is kept (an empty rifle's "Reload!", Weapon.lua slotLabel).

local captured = {} -- item id -> { name, text, ammo } from the frames since the last tick
local current = {} -- the last complete capture
local spoken = {} -- item id -> label text last announced (or first seen)
local hookCalls, hookPlayerCalls = 0, 0

local function labelText(ev)
	local parts = {}
	local defaultHeader = ev.slotInfo and ev.slotInfo.label
	local stack = ev.item.itemStack and not ev.item.weaponReloadable
	for _, label in ipairs(ev.labels or {}) do
		local keyBinding = label.wordWrap and label.relativeMaxWidth ~= nil
		local stackCount = stack and label.quantity
		if not keyBinding and not stackCount and label.text ~= defaultHeader then
			local text = Text.clean((tostring(label.text or ""):gsub("%s*\n%s*", " ")))
			if text ~= "" then
				parts[#parts + 1] = text
			end
		end
	end
	return table.concat(parts, ", ")
end

event.inventoryHUDRenderSlot.add("cryptAccessSlotLabels", { order = "labels", sequence = -1 }, function(ev)
	hookCalls = hookCalls + 1
	local item = ev.item
	if not item or not ev.holder or not World.isPlayer(ev.holder) then
		return
	end
	hookPlayerCalls = hookPlayerCalls + 1
	-- One item can fill two slots (a rifle: weapon slot with its ammo, throw slot "Reload!"): key by both.
	local slot = ev.slotInfo and (ev.slotInfo.slot or ev.slotInfo.action) or ev.action
	captured[tostring(item.id) .. "|" .. tostring(slot)] = {
		id = item.id,
		name = World.name(item),
		text = labelText(ev),
		ammo = item.weaponReloadable ~= nil,
	}
end)

event.gameStateLevel.add("cryptAccessSlotLabelsReset", { order = "levelLoadingDone", sequence = 61 }, function()
	spoken, current, captured = {}, {}, {}
end)

local function announceSlots()
	if next(captured) == nil then
		return
	end
	current, captured = captured, {}
	for key, info in pairs(current) do
		local before = spoken[key]
		if before == nil then
			spoken[key] = info.text
		elseif before ~= info.text then
			spoken[key] = info.text
			if info.text == "" then
				Speech.say(Strings.get("status.ready", { name = info.name }), false)
			elseif before == "" or info.ammo then
				-- A cooldown starting (spell cast), or ammo changing. Counting down in between stays quiet.
				Speech.say(Strings.get("status.slot", { name = info.name, label = info.text }), false)
			end
		end
	end
end

--- Debug counters (DevConsole): slot hook calls, calls for the local player, items in the last capture.
function Status.debug()
	local items = {}
	for key, info in pairs(current) do
		items[#items + 1] = tostring(key) .. " " .. info.name .. " [" .. info.text .. "]"
	end
	return { calls = hookCalls, player = hookPlayerCalls, items = items }
end

--- The label the game shows on an item's slot ("15 kills", "2 beats", ammo), or nil.
function Status.slotLabel(id)
	local parts = {}
	for _, info in pairs(current) do
		if info.id == id and info.text ~= "" then
			parts[#parts + 1] = info.text
		end
	end
	table.sort(parts)
	return parts[1] and table.concat(parts, ", ") or nil
end

--- Lines for slots that are not inventory items (Nocturna's bat form, cooldown icons), as "Name: label".
function Status.otherSlotLines(known)
	local lines = {}
	for _, info in pairs(current) do
		if not known[info.id] and info.text ~= "" and info.name ~= "" then
			lines[#lines + 1] = Strings.get("status.slot", { name = info.name, label = info.text })
		end
	end
	table.sort(lines)
	return lines
end

---------------------------------------------------------------------------------------------------- Tempo's curse
-- Component damageCountdown (CharacterComponents.lua): countdown drops each beat, a kill resets it; at 0 the
-- character takes `damage` (999 for Tempo). The HUD shows min(countdown, countdownReset - 1), not in safe levels.

local lastCurse = nil

local function curseValue(player)
	local dc = player and player.damageCountdown
	if not dc then
		return nil
	end
	local okSafe, safe = pcall(CurrentLevel.isSafe)
	if okSafe and safe then
		return nil
	end
	return math.min(dc.countdown or 0, (dc.countdownReset or 1) - 1)
end

-- The countdown itself (10, then 5 to 0) is already spoken: Tempo has damageCountdownFlyaways
-- (PlayableCharacters.lua), and ScreenText reads flyaways. Proven 2026-11-24: numbers were said twice.
-- Here only the reset after a kill, once it had run low, so the player knows the kill counted.
local CURSE_LOW = 5

local function announceCurse(player)
	local n = curseValue(player)
	if n == lastCurse then
		return
	end
	local alive = player and player.health and (player.health.health or 0) > 0
	if n and lastCurse and n > lastCurse and lastCurse <= CURSE_LOW and alive then
		Speech.say(Strings.get("status.curseReset", { n = n }), false)
	end
	lastCurse = n
end

---------------------------------------------------------------------------------------------------- heart transplant
-- Component rhythmIgnoredTemporarily: active, endTime (raw music time). HeartbeatHUD.lua draws endTime - rawTime.

local rhythmFree = false

local function rhythmFreeLeft(player)
	local r = player and player.rhythmIgnoredTemporarily
	if not (r and r.active and r.endTime) then
		return nil
	end
	local ok, now = pcall(Music.getRawTime)
	if not ok or type(now) ~= "number" or r.endTime <= now then
		return nil
	end
	return r.endTime - now
end

local function announceRhythmFree(player)
	local left = rhythmFreeLeft(player)
	if left and not rhythmFree then
		Speech.say(Strings.get("status.rhythmFree", { n = math.floor(left + 0.5) }), false)
	elseif not left and rhythmFree then
		Speech.say(Strings.get("status.rhythmBack"), false)
	end
	rhythmFree = left ~= nil
end

--- Extra lines for the H key: the curse countdown and the rhythm-free time, when they apply.
function Status.healthExtras()
	local player = World.player()
	local lines = {}
	local n = curseValue(player)
	if n then
		lines[#lines + 1] = Strings.get("status.curse", { n = n })
	end
	local left = rhythmFreeLeft(player)
	if left then
		lines[#lines + 1] = Strings.get("status.rhythmFree", { n = math.floor(left + 0.5) })
	end
	return lines
end

---------------------------------------------------------------------------------------------------- countdown reason
-- The game beeps the last counts but only draws why ("Game begins in" / "Pausing in" / "Unpausing in").
-- Our own unfreeze already says "Continue", so it is skipped then.

event.gameStateBeginCountdown.add("cryptAccessCountdownReason", { order = "overlay", sequence = 1 }, function(ev)
	if type(ev) ~= "table" then
		return
	end
	local text = ev.text
	if not text then
		local okData, data = pcall(function()
			return Countdown.Type.data[ev.type]
		end)
		text = okData and type(data) == "table" and data.text or nil
	end
	if type(text) ~= "string" or text == "" then
		return
	end
	if ev.type == Countdown.Type.UNPAUSE then
		local okF, recent = pcall(function()
			return require("CryptAccess.Freeze").recentlyToggled()
		end)
		if okF and recent then
			return
		end
	end
	local beats = tonumber(ev.beats)
	if beats and beats > 0 then
		Speech.say(Strings.get("status.countdown", { text = Text.clean(text), n = beats }), false)
	else
		Speech.say(Text.clean(text), false)
	end
end)

---------------------------------------------------------------------------------------------------- tick

event.tick.add("cryptAccessStatus", { order = "hud", sequence = 70 }, function()
	if not World.inLevel() then
		lastCurse, rhythmFree = nil, false
		return
	end
	local player = World.player()
	pcall(announceSlots)
	pcall(announceCurse, player)
	pcall(announceRhythmFree, player)
end)

return Status
