-- Latency calibration (necro/menu/options/LatencyCalibration.lua, menu "latencyCalibration"), the first
-- screen of a new save, also opened by Options "Calibrate automatically".
-- Step one (video) is purely visual: the game mutes the music (audioFilter gain 2^(inputs - 20)) and the
-- player must press Up when two bars meet. Crypt Access marks that step done as soon as the menu is built,
-- so the player lands on step two (press Down on each tick sound). The video latency keeps its previous
-- value (args.video.latency starts at initVideoLatency, 0 on a new save) and only shifts the picture.
-- Its text is read by MenuReader; this adds the blind-player hint.

local MenuReader = require("CryptAccess.MenuReader")
local Strings = require("CryptAccess.Strings")

-- Runs after the game's own handler (same key, later sequence), which fills ev.arg.video.
event.menu.add("cryptAccessSkipVisualCalibration", { key = "latencyCalibration", sequence = 1 }, function(ev)
	local args = ev.arg
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

MenuReader.special.latencyCalibration = {
	onOpen = function()
		return { Strings.get("calibration.visualSkipped") }
	end,
	help = { "help.calibration.1", "help.calibration.2", "help.calibration.3" },
}

return {}
