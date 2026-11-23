-- Online (and local) multiplayer:
--   * chat messages and the game's own chat notices (players joining, leaving) are spoken (setting
--     "speech.chat"); your own messages are not repeated;
--   * when an online session's mod list arrives, says whether the session keeps Crypt Access. Online
--     sessions only carry packaged mods that every player has (necro.mod.NetworkMods), and a lobby
--     with cross-play on drops every mod the game's server has not signed, Crypt Access included. When
--     the mod is about to be turned off, this is the last thing it can say, so it says how to fix it;
--   * spectating after death: who you watch and how to change or join (necro.game.character.Spectator);
--   * pauses by the host, and the game's "network issues" notice;
--   * O: the players in the game, with character and health (Details buffer, Control plus Up);
--   * the host menu (networkHost): a warning while cross-play would drop the mod.

local Controls = require("necro.config.Controls")
local GameClient = require("necro.client.GameClient")
local GameState = require("necro.client.GameState")
local Menu = require("necro.menu.Menu")
local Player = require("necro.game.character.Player")
local PlayerList = require("necro.client.PlayerList")
local SettingsStorage = require("necro.config.SettingsStorage")
local SinglePlayer = require("necro.client.SinglePlayer")
local Spectator = require("necro.game.character.Spectator")
local Timer = require("system.utils.Timer")

local Buffers = require("CryptAccess.Buffers")
local Config = require("CryptAccess.Config")
local Dedupe = require("CryptAccess.Dedupe")
local Help = require("CryptAccess.Help")
local Keys = require("CryptAccess.Keys")
local MenuReader = require("CryptAccess.MenuReader")
local Native = require("CryptAccess.Native")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local Online = {}

local MOD_NAME = "CryptAccess"

--- True in an online session (connected to a server that is not the local single-player one).
function Online.isOnline()
	local okConnected, connected = pcall(GameClient.isConnected)
	local okSingle, single = pcall(SinglePlayer.isActive)
	return okConnected and connected and not (okSingle and single) or false
end

local function say(text, interrupt)
	if type(text) == "string" and text ~= "" then
		Buffers.addEvent(text)
		Speech.say(text, interrupt or false)
	end
end

local function keyName(misc)
	local ok, name = pcall(function()
		return Controls.getFriendlyMiscKeyBind(Controls.Misc[misc])
	end)
	return ok and type(name) == "string" and Text.clean(name) or ""
end

--- A player's name, with "P2" for a second player on the same computer.
function Online.playerName(playerID)
	local okName, name = pcall(PlayerList.getName, playerID)
	name = okName and type(name) == "string" and Text.clean(name) or nil
	if not name or name == "" then
		return nil
	end
	local okCoop, isCoop = pcall(function()
		return require("necro.client.LocalCoop").isCoopPlayer(playerID)
	end)
	if okCoop and isCoop then
		local okNumber, number = pcall(function()
			return require("necro.client.LocalCoop").getCoopPlayerNumber(playerID)
		end)
		if okNumber and number then
			name = name .. " P" .. tostring(number)
		end
	end
	return name
end

-- Chat --------------------------------------------------------------------------------------------

event.chatMessage.add("cryptAccessChat", { order = "sound", sequence = -10 }, function(ev)
	if Config.get("speakChat") == false or Dedupe.replaying() then
		return
	end
	local text = Text.clean(tostring(ev.text or ""))
	if text == "" then
		return
	end
	-- Your own messages: the text field already said what you sent.
	local okLocal, localID = pcall(PlayerList.getLocalPlayerID)
	if ev.name and ev.playerID and okLocal and ev.playerID == localID then
		return
	end
	local line = text
	if type(ev.name) == "string" and ev.name ~= "" then
		line = Strings.get("chat.message", { name = Text.clean(ev.name), text = text })
	end
	-- A message sent during a turn is fired again when the turn is re-simulated.
	if ev.turnID ~= nil and not Dedupe.first(line, ev.turnID) then
		return
	end
	say(line)
end)

-- The session's mod list ------------------------------------------------------------------------

local function localVersion()
	local Mods = Native.engineModule("necro.mod.Mods")
	if type(Mods) ~= "table" then
		return nil
	end
	local ok, version = pcall(Mods.getLatestVersion, MOD_NAME)
	return ok and type(version) == "table" and version.version or nil
end

local function hasExactVersion(version, packaged)
	local Mods = Native.engineModule("necro.mod.Mods")
	if type(Mods) ~= "table" then
		return true
	end
	local ok, found = pcall(Mods.getExactInstalledVersion, MOD_NAME, version, packaged)
	return ok and found ~= nil
end

--- Called as soon as the session's mod list arrives, before the game loads it (next cycle).
local function checkSessionMods()
	if not Online.isOnline() then
		return
	end
	local NetworkMods = Native.engineModule("necro.mod.NetworkMods")
	if type(NetworkMods) ~= "table" then
		return
	end
	local ok, list = pcall(NetworkMods.getRemoteModList)
	if not ok or type(list) ~= "table" then
		return
	end
	local entry
	for _, mod in ipairs(list) do
		if type(mod) == "table" and mod.name == MOD_NAME then
			entry = mod
		end
	end
	if not entry then
		Speech.say(Strings.get("online.notInSession"), false)
	elseif not hasExactVersion(entry.version, entry.package) then
		Speech.say(Strings.get("online.versionMismatch", {
			version = tostring(entry.version),
			mine = tostring(localVersion() or "?"),
		}), false)
	else
		Speech.say(Strings.get("online.active"), false)
	end
end

event.resourceLoaded.add("cryptAccessSessionMods", "MOD_LIST", function()
	local ok, err = pcall(checkSessionMods)
	if not ok then
		log.warn("Online: mod list check failed: %s", tostring(err))
	end
end)

-- Spectating, pauses by the host, network trouble ---------------------------------------------------

local spectating = { active = false, target = false }
local pausedByHost = false
local networkNotice = false
local networkNoticeAt = -100

local function spectatorLine()
	local ok, target = pcall(Spectator.getTargetPlayerID)
	local who = ok and target and Online.playerName(target) or Strings.get("online.everyone")
	return Strings.get("online.spectating", {
		name = who,
		left = keyName("MENU_LEFT"),
		right = keyName("MENU_RIGHT"),
		join = keyName("SELECT"),
	})
end

local function updateSpectator()
	local okActive, active = pcall(Spectator.isActive)
	active = okActive and active and not SinglePlayer.isActive() or false
	local okTarget, target = pcall(Spectator.getTargetPlayerID)
	target = okTarget and target or false
	if active and (not spectating.active or target ~= spectating.target) then
		say(spectatorLine(), true)
	end
	spectating.active, spectating.target = active, target
end

local function updateHostPause()
	if not Online.isOnline() then
		pausedByHost = false
		return
	end
	local okPaused, paused = pcall(GameState.isPaused)
	paused = okPaused and paused or false
	local okAllowed, allowed = pcall(function()
		return require("necro.client.StateControl").isPauseAllowed()
	end)
	local byHost = paused and okAllowed and not allowed and not Menu.isOpen()
	if byHost and not pausedByHost then
		say(Strings.get("online.pausedByHost"))
	elseif not paused and pausedByHost then
		say(Strings.get("online.resumed"))
	end
	pausedByHost = byHost or (pausedByHost and paused)
end

local function updateNetworkNotice()
	if not Online.isOnline() then
		networkNotice = false
		return
	end
	local okDesync, desync = pcall(function()
		return require("necro.client.Synchronizer").getDesyncNotification()
	end)
	local notice = okDesync and type(desync) == "string" and desync ~= "" and Text.clean(desync) or nil
	if not notice then
		local okLock, locked = pcall(function()
			return require("necro.client.InputLock").isActive()
		end)
		if okLock and locked then
			notice = Strings.get("online.networkIssues")
		end
	end
	local now = Timer.getGlobalTime()
	if notice and notice ~= networkNotice and now - networkNoticeAt > 15 then
		networkNoticeAt = now
		say(notice)
	end
	networkNotice = notice or false
end

local nextPoll = 0

event.tick.add("cryptAccessOnline", { order = "hud", sequence = 52 }, function()
	if not Native.available then
		return
	end
	local now = Timer.getGlobalTime()
	if now < nextPoll then
		return
	end
	nextPoll = now + 0.2
	pcall(updateSpectator)
	pcall(updateHostPause)
	pcall(updateNetworkNotice)
end)

-- O: the players in the game ---------------------------------------------------------------------------

local function playerLines()
	local lines = {}
	local okList, ids = pcall(PlayerList.getPlayerList)
	if not okList or type(ids) ~= "table" then
		return lines
	end
	local okLocal, localID = pcall(PlayerList.getLocalPlayerID)
	for _, id in ipairs(ids) do
		local name = Online.playerName(id) or Strings.get("online.unnamed")
		if okLocal and id == localID then
			name = Strings.get("online.you", { name = name })
		end
		local okEntity, entity = pcall(Player.getPlayerEntity, id)
		local parts = { name }
		if okEntity and entity then
			local character = entity.friendlyName and Text.clean(entity.friendlyName.name) or ""
			if character ~= "" then
				parts[#parts + 1] = character
			end
			local okAlive, alive = pcall(function()
				return require("necro.game.character.Character").isAlive(entity)
			end)
			if okAlive and not alive then
				parts[#parts + 1] = Strings.get("online.dead")
			else
				local okHealth, health = pcall(function()
					return require("CryptAccess.HUD").healthText(entity)
				end)
				if okHealth and type(health) == "string" then
					parts[#parts + 1] = health
				end
				local px, py = World.playerPosition()
				if entity.position and px and not World.isPlayer(entity) then
					parts[#parts + 1] = World.direction(entity.position.x - px, entity.position.y - py)
				end
			end
		else
			local okSpectating, isSpectating = pcall(Spectator.isSpectating, id)
			parts[#parts + 1] = Strings.get(okSpectating and isSpectating and "online.watching" or "online.notInLevel")
		end
		local okReady, ready = pcall(PlayerList.isReady, id)
		if okReady and ready and not World.inLevel() then
			parts[#parts + 1] = Strings.get("charSelect.ready")
		end
		lines[#lines + 1] = table.concat(parts, ", ")
	end
	return lines
end

function Online.listPlayers()
	local lines = playerLines()
	if #lines <= 1 then
		Speech.say(Strings.get("online.alone"), true)
		return
	end
	Buffers.focus(lines)
	Speech.say(Strings.get("online.players", { count = #lines }) .. " " .. lines[1], true)
end

Keys.bind({ key = "o", id = "players", when = function()
	return not Menu.isOpen() or Online.isOnline()
end, fn = Online.listPlayers })

-- The host menu: cross-play drops unsigned mods ----------------------------------------------------------

local function crossPlayDropsMod()
	local okType, serverType = pcall(SettingsStorage.get, "net.host.serverType")
	if okType and serverType == 1 then
		return false -- IP address servers have no cross-play
	end
	local okCross, crossPlay = pcall(SettingsStorage.get, "net.host.crossplay.brainCloud.enabled")
	return okCross and crossPlay ~= false
end

MenuReader.special.networkHost = {
	onOpen = function()
		if crossPlayDropsMod() then
			return { Strings.get("online.crossPlayWarning") }
		end
		return {}
	end,
	details = function()
		return { Strings.get("online.hostHelp") }
	end,
	help = { "online.hostHelp" },
}

Help.register({
	id = "spectator",
	priority = 20,
	active = function()
		local ok, active = pcall(Spectator.isActive)
		return ok and active and World.inLevel() and not Menu.isOpen() and not SinglePlayer.isActive()
	end,
	lines = function()
		local lines = { spectatorLine() }
		for i = 1, 14 do
			local line = Strings.maybe("help.game." .. i)
			if line then
				lines[#lines + 1] = line
			end
		end
		lines[#lines + 1] = Strings.get("help.online")
		return lines
	end,
})

return Online
