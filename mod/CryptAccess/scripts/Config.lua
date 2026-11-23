-- Crypt Access settings. They are game settings (necro.config.Settings, user scope), so they appear
-- in the game's own settings menus under this mod, are saved by the game and need no file editing.

local Settings = require("necro.config.Settings")

local Strings = require("CryptAccess.Strings")

local Config = {}

local function name(key)
	return Strings.get("setting." .. key)
end

cueEnemies = Settings.user.bool({
	id = "cues.enemies",
	name = name("cueEnemies"),
	default = true,
})
cueItems = Settings.user.bool({
	id = "cues.items",
	name = name("cueItems"),
	default = true,
})
cueWalls = Settings.user.bool({
	id = "cues.walls",
	name = name("cueWalls"),
	default = true,
})
cueRadius = Settings.user.number({
	id = "cues.radius",
	name = name("cueRadius"),
	default = 4,
	minimum = 1,
	maximum = 9,
})
cueVolume = Settings.user.percent({
	id = "cues.volume",
	name = name("cueVolume"),
	default = 0.9,
})
metronome = Settings.user.bool({
	id = "cues.metronome",
	name = name("metronome"),
	default = false,
})
speakHits = Settings.user.bool({
	id = "speech.hits",
	name = name("speakHits"),
	default = true,
})
speakPositions = Settings.user.bool({
	id = "speech.positions",
	name = name("speakPositions"),
	default = true,
})
autoFreeze = Settings.user.bool({
	id = "freeze.onLevelStart",
	name = name("autoFreeze"),
	default = false,
})

tutorialHints = Settings.user.bool({
	id = "tutorial.hints",
	name = name("tutorialHints"),
	default = true,
})

--- Current values (read live each time; the game updates the globals when a setting changes).
function Config.get(key)
	if key == "cueEnemies" then
		return cueEnemies
	elseif key == "cueItems" then
		return cueItems
	elseif key == "cueWalls" then
		return cueWalls
	elseif key == "cueRadius" then
		return cueRadius
	elseif key == "cueVolume" then
		return cueVolume
	elseif key == "metronome" then
		return metronome
	elseif key == "speakHits" then
		return speakHits
	elseif key == "speakPositions" then
		return speakPositions
	elseif key == "autoFreeze" then
		return autoFreeze
	elseif key == "tutorialHints" then
		return tutorialHints
	end
end

return Config
