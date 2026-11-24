-- Latency calibration (necro/menu/options/LatencyCalibration.lua, menu "latencyCalibration"), the first
-- screen of a new save, also opened by Options "Calibrate automatically".
-- Step one (video) is purely visual: the game mutes the music (audioFilter gain 2^(inputs - 20)) and the
-- player must press Up when two bars meet. Crypt Access marks that step done as soon as the menu is built,
-- so the player lands on step two (press Down on each tick sound). The video latency keeps its previous
-- value (args.video.latency starts at initVideoLatency, 0 on a new save) and only shifts the picture.
-- Its text is read by MenuReader; this adds the blind-player hint.

local Menu = require("necro.menu.Menu")

local MenuReader = require("CryptAccess.MenuReader")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")

-- The menu's args (the game's handler builds them; menu updates keep the same table).
local current = nil
local announced = false

-- Runs after the game's own handler (same key, later sequence), which fills ev.arg.video.
event.menu.add("cryptAccessSkipVisualCalibration", { key = "latencyCalibration", sequence = 1 }, function(ev)
	local args = ev.arg
	if type(args) == "table" and args ~= current then
		current, announced = args, false
	end
	local video = type(args) == "table" and args.video
	if type(video) ~= "table" or video.done then
		return
	end
	video.done = true
	-- What a finished video step leaves behind: 15 counted inputs (music fades in from there) and no
	-- held-beat offset on the beat map.
	video.inputCount = math.max(video.inputCount or 0, 15)
	if type(args.beatmap) == "table" then
		args.beatmap.heldBeatOffset = 0
	end
	log.info("CryptAccess: visual calibration step skipped")
end)

-- When the tick step finishes the game only draws "Calibration complete" and "Audio latency: N ms" as
-- unselectable text. Say it: a wrong value (missed or early presses) puts every beat sound off by that much.
-- args.audio.latency is in seconds (LatencyCalibration.lua handleInput; saved to latency.audio on done).
event.tick.add("cryptAccessCalibrationDone", { order = "menu", sequence = 20 }, function()
	if announced or type(current) ~= "table" then
		return
	end
	local audio = current.audio
	if type(audio) ~= "table" or not audio.done then
		return
	end
	local okMenu, menu = pcall(Menu.getCurrent)
	if not okMenu or type(menu) ~= "table" or menu.name ~= "latencyCalibration" then
		return
	end
	announced = true
	local ms = math.floor((tonumber(audio.latency) or 0) * 1000 + 0.5)
	if current.seamless then
		Speech.say(Strings.get("calibration.doneFirst", { ms = ms, count = (current.continuePresses or 0) + 1 }), true)
	else
		Speech.say(Strings.get("calibration.done", { ms = ms }), true)
	end
end)

MenuReader.special.latencyCalibration = {
	-- The result block is said by the tick handler above, in the player's language.
	ownMessages = true,
	onOpen = function()
		return { Strings.get("calibration.visualSkipped") }
	end,
	help = { "help.calibration.1", "help.calibration.2", "help.calibration.3" },
}

return {}
