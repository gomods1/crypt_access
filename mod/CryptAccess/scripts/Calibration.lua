-- Latency calibration (necro/menu/options/LatencyCalibration.lua, menu "latencyCalibration"), the first
-- screen of a new save. Its text is read by MenuReader; this adds the blind-player hint for the visual step.

local MenuReader = require("CryptAccess.MenuReader")
local Strings = require("CryptAccess.Strings")

MenuReader.special.latencyCalibration = {
	onOpen = function()
		return { Strings.get("calibration.videoHint") }
	end,
	help = { "help.calibration.1", "help.calibration.2", "help.calibration.3" },
}

return {}
