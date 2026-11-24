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

-- The status line, spectator line and per-player tags the game draws over the grid (CharacterSelector.lua
-- drawStatus, drawSpectatorText, getStatusText, drawPlayerSlots). Same conditions, in our strings.
-- Not covered: headerTextOverride (a local set by a game event) and the in-game character change screen.

-- Script globals of necro.client.CharacterSelector (not module fields): inGameOpen, passiveMode.
local function selectorGlobal(name)
	local Native = require("CryptAccess.Native")
	local loader = Native.package and Native.package.loaded and Native.package.loaded["core.ScriptLoader"]
	if type(loader) ~= "table" then
		return nil
	end
	local ok, value = pcall(loader.getGlobal, "necro.client.CharacterSelector", name)
	return ok and value or nil
end

local function selectKey()
	local ok, key = pcall(function()
		local Controls = require("necro.config.Controls")
		return Controls.getFriendlyMiscKeyBind(Controls.Misc.SELECT)
	end)
	return ok and Text.clean(tostring(key)) or ""
end

local function networkMods()
	local ok, module = pcall(require("CryptAccess.Native").engineModule, "necro.mod.NetworkMods")
	return ok and type(module) == "table" and module or nil
end

local function statusLine()
	local okSingle, single = pcall(function()
		return require("necro.client.SinglePlayer").isActive()
	end)
	if (okSingle and single) or selectorGlobal("inGameOpen") then
		return nil
	end
	local okCount, counting = pcall(function()
		return require("necro.client.GameState").getCountdown()
	end)
	if okCount and counting then
		return nil
	end
	if not PlayerList.allPlayersReady() then
		return nil
	end
	local okSync, synced = pcall(function()
		return require("necro.client.NetClock").isSynced()
	end)
	if okSync and not synced then
		return Strings.get("lobby.clockSync")
	end
	local okRes, done = pcall(function()
		return require("necro.client.Resources").allTransfersDone()
	end)
	if okRes and not done then
		return Strings.get("lobby.transmitting")
	end
	local mods = networkMods()
	local okMods, synchronized = pcall(function()
		return mods.allModsSynchronized()
	end)
	if okMods and not synchronized then
		return Strings.get("lobby.incompatible")
	end
	if PlayerList.isHost() and not selectorGlobal("passiveMode") then
		return Strings.get("lobby.pressStart", { key = selectKey() })
	end
	return Strings.get("lobby.waitHost")
end

local function otherPlayerLines()
	local lines = {}
	local mods = networkMods()
	local okList, ids = pcall(PlayerList.getPlayerList)
	if not okList or type(ids) ~= "table" or not mods then
		return lines
	end
	local okActive, active = pcall(mods.isActive)
	if not (okActive and active) then
		return lines
	end
	local localID = PlayerList.getLocalPlayerID()
	local spectators = {}
	for _, id in ipairs(ids) do
		local okSpec, spec = pcall(function()
			return PlayerList.getAttribute(id, require("necro.network.Netplay").PlayerAttribute.SPECTATING)
		end)
		if okSpec and spec then
			spectators[#spectators + 1] = Text.clean(tostring(PlayerList.getName(id) or ""))
		end
	end
	if #spectators > 0 then
		lines[#lines + 1] = Strings.get("lobby.spectators", { names = Strings.join(spectators) })
	end
	for _, id in ipairs(ids) do
		if id ~= localID then
			local okState, state = pcall(mods.isPlayerModListSynchronized, id)
			local name = Text.clean(tostring(PlayerList.getName(id) or ""))
			if okState and state == false then
				lines[#lines + 1] = Strings.get("lobby.playerMissingMods", { name = name })
			elseif okState and state == nil then
				lines[#lines + 1] = Strings.get("lobby.playerLoadingMods", { name = name })
			end
		end
	end
	return lines
end

local function spectatorLine()
	local okSpec, spectating = pcall(CharacterSelector.isSpectating)
	if okSpec and spectating and not selectorGlobal("passiveMode")
		and (not PlayerList.isHost() or not PlayerList.allPlayersReady()) then
		return Strings.get("lobby.spectating", { key = selectKey() })
	end
	return nil
end

local lobby = { status = false, others = {}, spectator = false, download = false }

local function announceLobby()
	local status = statusLine() or false
	if status ~= lobby.status then
		lobby.status = status
		if status then
			Speech.say(status, false)
		end
	end
	local spectator = spectatorLine() or false
	if spectator ~= lobby.spectator then
		lobby.spectator = spectator
		if spectator then
			Speech.say(spectator, false)
		end
	end
	local others = {}
	for _, line in ipairs(otherPlayerLines()) do
		others[line] = true
		if not lobby.others[line] then
			Speech.say(line, false)
		end
	end
	lobby.others = others
	-- Our own mod download, in steps of 25 percent.
	local okDl, progress = pcall(function()
		return require("necro.client.Resources").getDownloadProgress()
	end)
	local step = okDl and type(progress) == "number" and math.floor(progress * 4) or false
	if step ~= lobby.download then
		lobby.download = step
		if step then
			Speech.say(Strings.get("lobby.download", { n = step * 25 }), false)
		end
	end
end

--- The lobby state lines (also read by F1 here).
function CharSelectReader.lobbyLines()
	local lines = {}
	lines[#lines + 1] = statusLine()
	lines[#lines + 1] = spectatorLine()
	for _, line in ipairs(otherPlayerLines()) do
		lines[#lines + 1] = line
	end
	return lines
end

event.tick.add("cryptAccessCharSelect", { order = "menu", sequence = 13 }, function()
	if not isOpen() then
		state.open, state.character, state.ready = false, false, nil
		lobby.status, lobby.others, lobby.spectator, lobby.download = false, {}, false, false
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
	pcall(announceLobby)
end)

Help.register({
	id = "charSelect",
	priority = 55,
	active = isOpen,
	lines = function()
		local lines = CharSelectReader.lobbyLines()
		lines[#lines + 1] = Strings.get("help.charSelect")
		return lines
	end,
})

return CharSelectReader
