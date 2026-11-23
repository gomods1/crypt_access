-- Speaks cutscenes (necro.client.Cutscene): the title screen, the seizure warning, logos, story videos
-- and their subtitles. Scenes are images or videos with no text the mod could read, so each kind gets
-- a line of its own; story subtitles come from the game's subtitle table.
-- Picture descriptions (setting "describe.cutscenes"): the title art, and for each story and intro
-- video a timeline of what is on screen (CutsceneTimeline.lua, written from the video frames), spoken
-- between the subtitles. During the credits, each monster that dances by is named with its joke name.

local Cutscene = require("necro.client.Cutscene")

local Config = require("CryptAccess.Config")
local Describe = require("CryptAccess.Describe")
local Help = require("CryptAccess.Help")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local Timeline = require("CryptAccess.CutsceneTimeline")

local CutsceneReader = {}

local lastSubtitle = false

local function describe(scene)
	if type(scene) ~= "table" then
		return nil
	end
	local image = tostring(scene.image or "")
	local kind = scene.type
	local types = Cutscene.Type
	if kind == types.SPLASH then
		if scene.showVersion then
			return Strings.get("cutscene.title")
		elseif image:find("eizure") then
			return Strings.get("cutscene.warning")
		elseif image:find("BYG") or image:find("SpikeChunsoft") then
			return Strings.get("cutscene.logo")
		elseif image:find("LoadingPage") then
			return Strings.get("cutscene.loading")
		elseif image:find("Seasonal") then
			return Strings.get("cutscene.season")
		end
		return nil
	end
	return Strings.get("cutscene.video")
end

local function describing()
	return Config.get("describeCutscenes") ~= false
end

event.cutsceneBegin.add("cryptAccessCutscene", { order = "duration", sequence = 10 }, function(ev)
	lastSubtitle = false
	local ok, line = pcall(describe, ev.scene)
	Speech.debug("cutscene " .. tostring(ev.scene and ev.scene.type) .. " " .. tostring(ev.scene and ev.scene.image))
	if ok and line then
		Speech.say(line, false)
	end
	-- Title screens are pictures: say what they show.
	if describing() and type(ev.scene) == "table" and ev.scene.type == Cutscene.Type.SPLASH then
		local okArt, art = pcall(Describe.forSplash, ev.scene.image)
		if okArt and art then
			Speech.say(art, false)
		end
	end
end)

-- Story subtitles, read the same way the game draws them (necro.render.hud.Subtitles).
local subtitleKey, subtitleText

local function currentSubtitle()
	if not subtitleKey then
		subtitleKey = require("necro.game.data.SubtitlesXML")
		subtitleText = require("necro.game.data.i18n.TextPoolCutscene")
	end
	local key = subtitleKey.getSubtitleKey(Cutscene.getName(), Cutscene.getPlaybackTime())
	return subtitleText.getSubtitle(key)
end

event.tick.add("cryptAccessCutsceneSubtitles", { order = "cutscene", sequence = 10 }, function()
	if not Cutscene.isActive() then
		lastSubtitle = false
		return
	end
	local ok, subtitle = pcall(currentSubtitle)
	if ok and subtitle then
		local text = Text.clean(subtitle)
		if text ~= "" and text ~= lastSubtitle then
			lastSubtitle = text
			Speech.say(text, false)
		end
	end
end)

-- Scene descriptions of the story and intro videos, spoken as the playback time reaches them.
local sceneName, sceneNext = false, 1

local function timelineFor(name)
	local ok, list = pcall(function()
		return Timeline[name]
	end)
	return ok and type(list) == "table" and list or nil
end

event.tick.add("cryptAccessCutsceneScenes", { order = "cutscene", sequence = 12 }, function()
	if not Cutscene.isActive() then
		sceneName, sceneNext = false, 1
		return
	end
	local okName, name = pcall(Cutscene.getName)
	if not okName or type(name) ~= "string" then
		return
	end
	if name ~= sceneName then
		sceneName, sceneNext = name, 1
	end
	local list = timelineFor(name)
	if not list or not describing() then
		return
	end
	local okTime, time = pcall(Cutscene.getPlaybackTime)
	if not okTime or type(time) ~= "number" then
		return
	end
	while list[sceneNext] and time >= list[sceneNext][1] do
		local key = list[sceneNext][2]
		sceneNext = sceneNext + 1
		Speech.say(Strings.get(key), false)
	end
end)

-- Credits: necro.render.ui.CreditsRenderer keeps its parsed lines in the script global "credits"
-- (lines with baseY and speed in view units; a line is on screen once baseY - time * speed is below the
-- view height). Each line is spoken once, in order, as it scrolls in. The same table lists the
-- monsters ("actors") that dance across the left half, each from its start beat; the game shows each
-- one's joke name, or "???" for monsters not unlocked yet.
local creditsNext = 1
local actorsNext = 1
local creditsTable = false

local function creditsLines()
	local Native = require("CryptAccess.Native")
	local scriptLoader = Native.package and Native.package.loaded["core.ScriptLoader"]
	if not scriptLoader then
		return nil
	end
	local ok, credits = pcall(scriptLoader.getGlobal, "necro.render.ui.CreditsRenderer", "credits")
	return ok and type(credits) == "table" and credits or nil
end

local function actorLine(actor)
	local Entities = require("system.game.Entities")
	local proto = Entities.getEntityPrototype(actor.name)
	if not proto then
		return nil
	end
	local okUnlocked, unlocked = pcall(function()
		if not proto.enemyUnlockOnSpawn then
			return true
		end
		local Progression = require("necro.game.system.Progression")
		return Progression.isLocallyUnlocked(Progression.UnlockType.ENEMY_TRAINING, proto.name)
	end)
	if okUnlocked and not unlocked then
		return Strings.get("credits.locked")
	end
	local okName, name = pcall(function()
		return proto.friendlyName.name
	end)
	local okPun, pun = pcall(function()
		return proto.creditsAppearance.punnyName
	end)
	name = okName and type(name) == "string" and Text.clean(name) or tostring(actor.name)
	if okPun and type(pun) == "string" and pun ~= "" then
		pun = Text.clean(pun:gsub("\n", " "))
		if pun ~= name then
			return Strings.get("credits.actor", { name = name, pun = pun })
		end
	end
	return name
end

event.tick.add("cryptAccessCredits", { order = "cutscene", sequence = 11 }, function()
	if not Cutscene.isActive() then
		creditsTable, creditsNext, actorsNext = false, 1, 1
		return
	end
	local credits = creditsLines()
	if not credits or type(credits.lines) ~= "table" then
		return
	end
	if credits ~= creditsTable then
		creditsTable, creditsNext, actorsNext = credits, 1, 1
	end
	local time = Cutscene.getPlaybackTime() or 0
	local okSize, _, viewHeight = pcall(function()
		return require("system.gfx.GFX").getDefaultViewSize()
	end)
	viewHeight = okSize and viewHeight or 360
	while credits.lines[creditsNext] do
		local line = credits.lines[creditsNext]
		if (line.baseY or 0) - time * (line.speed or 10) > viewHeight then
			break
		end
		creditsNext = creditsNext + 1
		local text = Text.clean(line.origText or line.text)
		if text ~= "" then
			Speech.say(text, false)
		end
	end
	if describing() and type(credits.actors) == "table" then
		local beat = time * (credits.beatsPerSecond or 2.33) - 1
		while credits.actors[actorsNext] and beat >= (credits.actors[actorsNext].startBeat or 0) do
			local actor = credits.actors[actorsNext]
			actorsNext = actorsNext + 1
			local ok, line = pcall(actorLine, actor)
			if ok and line then
				Speech.say(line, false)
			end
		end
	end
end)

function CutsceneReader.isActive()
	return Cutscene.isActive()
end

Help.register({
	id = "cutscene",
	priority = 60,
	active = Cutscene.isActive,
	lines = function()
		return { Strings.get("help.cutscene"), Strings.get("help.cutscene.2") }
	end,
})

return CutsceneReader
