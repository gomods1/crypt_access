-- The character grid ("Choose your character", necro.client.CharacterSelector) shown in the game's
-- session lobby (multiplayer, local co-op, returning from some runs). It is not a menu, so it gets its
-- own reader: the title when it opens, then the highlighted character and the ready state.

local CharacterSelector = require("necro.client.CharacterSelector")
local Entities = require("system.game.Entities")
local Menu = require("necro.menu.Menu")
local PlayerList = require("necro.client.PlayerList")

local Buffers = require("CryptAccess.Buffers")
local Describe = require("CryptAccess.Describe")
local Help = require("CryptAccess.Help")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")

local CharSelectReader = {}

local state = { open = false, character = false, ready = nil }

local function displayName(typeName)
	local ok, proto = pcall(Entities.getEntityPrototype, typeName)
	if ok and proto and proto.friendlyName and proto.friendlyName.name then
		return Text.clean(proto.friendlyName.name)
	end
	return tostring(typeName or "")
end

--- "Bolt, locked" for characters the player has not unlocked yet.
local function describe(typeName)
	local name = displayName(typeName)
	local ok, unlocked = pcall(function()
		local Progression = require("necro.game.system.Progression")
		if not Entities.typeHasComponent(typeName, "playableCharacterUnlockable") then
			return true
		end
		return Progression.isLocallyUnlocked(Progression.UnlockType.PLAYABLE_CHARACTER, typeName)
	end)
	if ok and not unlocked then
		return name .. ", " .. Strings.get("charSelect.locked")
	end
	return name
end

local function isOpen()
	local ok, open = pcall(CharacterSelector.isOpen)
	return ok and open and not Menu.isOpen()
end

local function isReady()
	local ok, ready = pcall(PlayerList.isReady, PlayerList.getLocalPlayerID())
	return ok and ready or false
end

event.tick.add("cryptAccessCharSelect", { order = "menu", sequence = 13 }, function()
	if not isOpen() then
		state.open, state.character, state.ready = false, false, nil
		return
	end
	local ok, character = pcall(CharacterSelector.getSelectedCharacter)
	character = ok and character or false
	local ready = isReady()
	if not state.open then
		state.open = true
		state.character, state.ready = character, ready
		local line = Strings.get("charSelect.open", { name = character and describe(character) or "" })
		Speech.say(line, true)
		Buffers.focus({ line, character and Describe.forType(character) or nil })
		return
	end
	if character ~= state.character then
		state.character = character
		if character then
			local name = describe(character)
			Speech.say(name, true)
			-- Ctrl+Up reads the portrait description.
			Buffers.focus({ name, Describe.forType(character) })
		end
	end
	if ready ~= state.ready then
		state.ready = ready
		Speech.say(Strings.get(ready and "charSelect.ready" or "charSelect.notReady"), false)
	end
end)

Help.register({
	id = "charSelect",
	priority = 55,
	active = isOpen,
	lines = function()
		return { Strings.get("help.charSelect") }
	end,
})

return CharSelectReader
