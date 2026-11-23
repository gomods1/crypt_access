-- Startup: announces that the mod is running, so the player knows speech works.

local Native = require("CryptAccess.Native")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Keys = require("CryptAccess.Keys")

-- The game remounts the mod right after startup (see ModList.lua); package.loaded survives that,
-- so the announcement is spoken once per game launch, not once per mount.
local function alreadyAnnounced()
	local loaded = Native.package and Native.package.loaded
	if not loaded then
		return false
	end
	local was = loaded["CryptAccess.announced"] == true
	loaded["CryptAccess.announced"] = true
	return was
end

local announced = false

event.tick.add("cryptAccessStartup", { order = "menu", sequence = 5 }, function()
	if announced then
		return
	end
	announced = true
	if alreadyAnnounced() then
		return
	end
	if Native.available then
		Speech.say(Strings.get("loaded"), false)
		Speech.debug("backend " .. Speech.backendName())
	else
		log.error("Crypt Access cannot speak: add core.StandardLibrary to the scriptWhitelist in config.json (%s)",
			tostring(Native.error))
	end
end)

Keys.bind({ key = "r", id = "repeat", fn = function()
	Speech.say(Speech.last(), true)
end })
