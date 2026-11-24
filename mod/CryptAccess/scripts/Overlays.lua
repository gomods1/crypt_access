-- Text the game draws over menus and levels outside menu entries, spoken for blind players:
--   * mod download progress (menu/mod/ModDownloadProgress.lua) and the missing-mods list (NetworkModList.lua);
--   * replay mode, its speed and controls, and the replay loading percentage (SpectatorHUD, ReplaySkipHUD);
--   * the run intro text on 1-1 (game/level/IntroText.lua: mode, "mods enabled" warning);
--   * the run seed on the run summary (SeedHUD via RunSummaryMenu renderCallback);
--   * mod updates and the game version on the lobby pause menu (ModUpdateOverlay.lua);
--   * for the L key: win streak, Deathless win count, speedrun timer (WinStreak, Deathless, TimerHUD).

local Controls = require("necro.config.Controls")
local CurrentLevel = require("necro.game.level.CurrentLevel")

local MenuReader = require("CryptAccess.MenuReader")
local Native = require("CryptAccess.Native")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local Overlays = {}

local function engine(name)
	local ok, module = pcall(Native.engineModule, name)
	return ok and type(module) == "table" and module or nil
end

local function scriptGlobal(script, name)
	local loader = Native.package and Native.package.loaded and Native.package.loaded["core.ScriptLoader"]
	if type(loader) ~= "table" then
		return nil
	end
	local ok, value = pcall(loader.getGlobal, script, name)
	return ok and value or nil
end

local function miscKey(name)
	local ok, key = pcall(function()
		return Controls.getFriendlyMiscKeyBind(Controls.Misc[name])
	end)
	return ok and Text.clean(tostring(key)) or "?"
end

---------------------------------------------------------------------------------------------------- mod downloads
-- necro.mod.portal.ModPortal: getActiveDownloads() lists identifiers, getDownloadStatus(id) gives modName,
-- version, receivedBytes, totalBytes, status (Status: PENDING 1, ACTIVE 2, COMPLETE 3, FAILED 4).

local downloads = {} -- identifier -> last spoken step ("pending", 0..3, "done", "failed")

local function downloadState(status)
	if status.status == 3 then
		return "done"
	elseif status.status == 4 then
		return "failed"
	elseif status.status == 1 then
		return "pending"
	end
	local total = tonumber(status.totalBytes) or 0
	if total <= 0 then
		return 0
	end
	return math.min(3, math.floor((tonumber(status.receivedBytes) or 0) / total * 4))
end

local function announceDownloads()
	local portal = engine("necro.mod.portal.ModPortal")
	if not portal then
		return
	end
	local ok, ids = pcall(portal.getActiveDownloads)
	if not ok or type(ids) ~= "table" then
		return
	end
	local seen = {}
	for _, id in ipairs(ids) do
		local okS, status = pcall(portal.getDownloadStatus, id)
		if okS and type(status) == "table" then
			seen[id] = true
			local state = downloadState(status)
			if downloads[id] ~= state then
				downloads[id] = state
				local name = Text.clean(tostring(status.modName or id))
				if state == "done" then
					Speech.say(Strings.get("download.done", { name = name }), false)
				elseif state == "failed" then
					Speech.say(Strings.get("download.failed", { name = name }), false)
				elseif state == "pending" then
					Speech.say(Strings.get("download.pending", { name = name }), false)
				else
					Speech.say(Strings.get("download.progress", { name = name, n = state * 25 }), false)
				end
			end
		end
	end
	for id in pairs(downloads) do
		if not seen[id] then
			downloads[id] = nil
		end
	end
end

-- The missing-mods list: the note under the list sits below the first choice, and the download
-- percentages change in rows that are not selected (MenuReader.special.watchChoices).
MenuReader.special.networkModList = { allInfo = true, watchChoices = true }

---------------------------------------------------------------------------------------------------- replays

local replay = { active = false, speed = false, loading = false }

local function replayControls()
	return Strings.get("replay.controls", {
		pause = miscKey("REPLAY_TOGGLE_PAUSE"),
		back = miscKey("REPLAY_SEEK_BACKWARD"),
		forward = miscKey("REPLAY_SEEK_FORWARD"),
		faster = miscKey("REPLAY_SPEED_UP"),
		slower = miscKey("REPLAY_SPEED_DOWN"),
	})
end

local function announceReplay()
	local okR, player = pcall(require, "necro.client.replay.ReplayPlayer")
	if not okR or type(player) ~= "table" then
		return
	end
	-- Loading (fast-forwarding to the replay's level), in steps of 25 percent.
	local okT, target = pcall(player.getAutoSkipTargetLevel)
	local loading = false
	if okT and type(target) == "number" and target > 0 then
		local okN, number = pcall(CurrentLevel.getSequentialNumber)
		loading = okN and math.floor((number or 0) / target * 4) or 0
	end
	if loading ~= replay.loading then
		replay.loading = loading
		if loading then
			Speech.say(Strings.get("replay.loading", { n = loading * 25 }), false)
		end
	end
	local okA, active = pcall(player.isActive)
	active = okA and active or false
	if active ~= replay.active then
		replay.active = active
		replay.speed = false
		if active then
			Speech.say(Strings.get("replay.mode") .. ". " .. replayControls(), false)
		end
	end
	if active then
		local okS, speed = pcall(function()
			return math.floor(require("necro.client.Room").getTempoMultiplier() * 100 + 0.5)
		end)
		speed = okS and speed or false
		if speed ~= replay.speed then
			if replay.speed then
				Speech.say(Strings.get("replay.speed", { n = speed }), false)
			end
			replay.speed = speed
		end
	end
end

---------------------------------------------------------------------------------------------------- 1-1 intro text
-- IntroText.lua fires getIntroText (orders default .. modsEnabled) and spawns its text as fading world labels.
-- Capture the final text after every handler and say it once the level is running.

local introPending = nil

event.getIntroText.add("cryptAccessIntroText", { order = "modsEnabled", sequence = 50 }, function(ev)
	if type(ev) == "table" and type(ev.text) == "string" and ev.text ~= "" then
		introPending = ev.text
	end
end)

local function announceIntro()
	if introPending and World.playing() then
		local lines = {}
		for line in introPending:gmatch("[^\n]+") do
			line = Text.clean(line)
			if line ~= "" then
				lines[#lines + 1] = line
			end
		end
		introPending = nil
		if #lines > 0 then
			Speech.say(Text.sentences(lines), false)
		end
	end
end

---------------------------------------------------------------------------------------------------- run summary seed

local function seedLine()
	local okVisible, visible = pcall(function()
		return require("necro.render.hud.SeedHUD").isVisibleInMode()
	end)
	if not (okVisible and visible) then
		return nil
	end
	local okSeed, seed = pcall(CurrentLevel.getSeed)
	if not okSeed or not seed then
		return nil
	end
	local okKey, copy = pcall(function()
		return Text.clean(Controls.getFriendlyName(Controls.getMiscKeyBind(Controls.Misc.EDITOR_COPY)))
	end)
	return Strings.get("summary.seed", { seed = seed, key = okKey and copy or "?" })
end

do
	local special = MenuReader.special.runSummary or {}
	local previous = special.details
	special.details = function(currentMenu, entry)
		local lines = {}
		if previous then
			local ok, extra = pcall(previous, currentMenu, entry)
			if ok and type(extra) == "table" then
				lines = extra
			end
		end
		lines[#lines + 1] = seedLine()
		return lines
	end
	MenuReader.special.runSummary = special
end

---------------------------------------------------------------------------------------------------- lobby pause menu

local function modUpdateLines()
	local update = engine("necro.mod.ModUpdate")
	local mods = engine("necro.mod.Mods")
	if not (update and mods) then
		return {}
	end
	local ok, list = pcall(function()
		if update.getAutoUpdateMode() == update.Mode.MANUAL then
			return {}
		end
		return update.listAvailableUpdates() or {}
	end)
	if not ok or type(list) ~= "table" or #list == 0 then
		return {}
	end
	local lines = { Strings.get("pause.modUpdates", { n = #list }) }
	for _, name in ipairs(list) do
		local okOld, old = pcall(function()
			return (mods.getLatestVersion(name, true) or {}).version
		end)
		local okNew, new = pcall(update.getAvailableUpdate, name)
		local okDisplay, display = pcall(mods.getDisplayName, name)
		lines[#lines + 1] = Strings.get("pause.modUpdate", {
			name = Text.clean(tostring(okDisplay and display or name)),
			old = tostring(okOld and old or "?"),
			new = tostring(okNew and new or "?"),
		})
	end
	return lines
end

local function inLobby()
	local ok, lobby = pcall(CurrentLevel.isLobby)
	return ok and lobby
end

do
	local special = MenuReader.special.pause or {}
	local previousOpen, previousDetails = special.onOpen, special.details
	special.onOpen = function(currentMenu)
		local lines = {}
		if previousOpen then
			local ok, extra = pcall(previousOpen, currentMenu)
			if ok and type(extra) == "table" then
				lines = extra
			end
		end
		if inLobby() then
			for _, line in ipairs(modUpdateLines()) do
				lines[#lines + 1] = line
			end
		end
		return lines
	end
	special.details = function(currentMenu, entry)
		local lines = {}
		if previousDetails then
			local ok, extra = pcall(previousDetails, currentMenu, entry)
			if ok and type(extra) == "table" then
				lines = extra
			end
		end
		if inLobby() then
			-- system.game.Session is outside the mod whitelist.
			local okV, version = pcall(function()
				return engine("system.game.Session").getVersion()
			end)
			if okV and version then
				lines[#lines + 1] = Strings.get("pause.version", { version = Text.clean(tostring(version)) })
			end
		end
		return lines
	end
	MenuReader.special.pause = special
end

---------------------------------------------------------------------------------------------------- L key extras

--- Win streak, Deathless win count and the speedrun timer, when the game shows them.
function Overlays.levelExtras()
	local lines = {}
	if inLobby() then
		return lines
	end
	local okDeathless, deathless = pcall(function()
		return require("necro.game.data.modifier.Deathless").isActive()
	end)
	if okDeathless and deathless then
		local okWins, wins = pcall(function()
			return require("necro.game.system.RunState").getState().winCount or 0
		end)
		lines[#lines + 1] = Strings.get("level.winCount", { n = okWins and wins or 0 })
	elseif scriptGlobal("necro.client.leaderboard.WinStreak", "winStreakMode") then
		local okStreak, streak = pcall(function()
			return require("necro.client.leaderboard.WinStreak").get()
		end)
		if okStreak and streak then
			lines[#lines + 1] = Strings.get("level.winStreak", { n = streak })
		end
	end
	local okMode, mode = pcall(CurrentLevel.getMode)
	if okMode and type(mode) == "table" and mode.timerHUD and scriptGlobal("necro.render.hud.TimerHUD", "timerVisible") then
		local okTime, time = pcall(function()
			local timer = require("necro.client.SpeedrunTimer")
			return timer.formatTime(timer.getTime())
		end)
		if okTime and time then
			lines[#lines + 1] = Strings.get("level.timer", { time = Text.clean(tostring(time)) })
		end
	end
	return lines
end

---------------------------------------------------------------------------------------------------- tick

event.tick.add("cryptAccessOverlays", { order = "menu", sequence = 30 }, function()
	pcall(announceDownloads)
	pcall(announceReplay)
	pcall(announceIntro)
end)

return Overlays
