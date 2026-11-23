-- Freeze (observe) mode: Space pauses the game without opening the pause menu, so the player can use
-- the scanner, the review cursor and the buffers with the music stopped. Space again resumes with the
-- game's own count-in (necro.client.StateControl.unpauseBeats). Single player or host only.

local GameState = require("necro.client.GameState")
local StateControl = require("necro.client.StateControl")
local Menu = require("necro.menu.Menu")

local Config = require("CryptAccess.Config")
local Cues = require("CryptAccess.Cues")
local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

local Freeze = {}

local frozenByMod = false
local frozenAt = 0
local Timer = require("system.utils.Timer")

local function isPaused()
	local ok, paused = pcall(GameState.isPaused)
	return ok and paused
end

--- Frozen by this mod, or paused with no menu in front (a pause without menu).
function Freeze.isFrozen()
	return frozenByMod or (isPaused() and not Menu.isOpen())
end

function Freeze.toggle()
	if Freeze.isFrozen() then
		local ok, sent = pcall(StateControl.unpauseBeats)
		if ok and sent ~= false then
			frozenByMod = false
			Cues.playCentered("unfreeze", 0.8)
			Speech.say(Strings.get("freeze.off"), true)
		else
			Speech.say(Strings.get("freeze.wait"), true)
		end
		return
	end
	if isPaused() then
		return
	end
	local okAllowed, allowed = pcall(StateControl.isPauseAllowed)
	if not (okAllowed and allowed) then
		Speech.say(Strings.get("freeze.notAllowed"), true)
		return
	end
	local ok, err = pcall(StateControl.pauseWithoutMenu)
	if ok then
		frozenByMod = true
		frozenAt = Timer.getGlobalTime()
		Cues.playCentered("freeze", 0.8)
		Speech.say(Strings.get("freeze.on"), true)
	else
		log.warn("Freeze: %s", tostring(err))
	end
end

-- If the pause menu or anything else unpauses the game, forget our freeze.
event.tick.add("cryptAccessFreezeState", { order = "hud", sequence = 60 }, function()
	-- The pause is a network message, so it takes effect a moment later.
	if frozenByMod and not isPaused() and Timer.getGlobalTime() - frozenAt > 1.5 then
		frozenByMod = false
	end
end)

local pendingAutoFreeze = false

event.gameStateLevel.add("cryptAccessAutoFreeze", { order = "levelLoadingDone", sequence = 60 }, function()
	pendingAutoFreeze = Config.get("autoFreeze") and true or false
end)

event.tick.add("cryptAccessAutoFreeze", { order = "hud", sequence = 61 }, function()
	if pendingAutoFreeze and World.playing() then
		pendingAutoFreeze = false
		local ok, lobby = pcall(require("necro.game.level.CurrentLevel").isLobby)
		if not (ok and lobby) and not isPaused() then
			Freeze.toggle()
		end
	end
end)

Keys.bind({ key = "space", id = "freeze", when = function()
	return World.inLevel() and not World.inEditor() and (not Menu.isOpen() or Freeze.isFrozen())
end, fn = Freeze.toggle })

return Freeze
