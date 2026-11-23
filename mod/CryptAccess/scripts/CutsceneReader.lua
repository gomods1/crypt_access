-- Speaks cutscenes (necro.client.Cutscene): the title screen, the seizure warning, logos, story videos
-- and their subtitles. Scenes are images or videos with no text the mod could read, so each kind gets
-- a line of its own; story subtitles come from the game's subtitle table.

local Cutscene = require("necro.client.Cutscene")

local Help = require("CryptAccess.Help")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")

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

event.cutsceneBegin.add("cryptAccessCutscene", { order = "duration", sequence = 10 }, function(ev)
	lastSubtitle = false
	local ok, line = pcall(describe, ev.scene)
	Speech.debug("cutscene " .. tostring(ev.scene and ev.scene.type) .. " " .. tostring(ev.scene and ev.scene.image))
	if ok and line then
		Speech.say(line, false)
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

-- Credits: necro.render.ui.CreditsRenderer keeps its parsed lines in the script global "credits"
-- (lines with baseY and speed in view units; a line is on screen once baseY - time * speed is below the
-- view height). Each line is spoken once, in order, as it scrolls in.
local creditsNext = 1
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

event.tick.add("cryptAccessCredits", { order = "cutscene", sequence = 11 }, function()
	if not Cutscene.isActive() then
		creditsTable, creditsNext = false, 1
		return
	end
	local credits = creditsLines()
	if not credits or type(credits.lines) ~= "table" then
		return
	end
	if credits ~= creditsTable then
		creditsTable, creditsNext = credits, 1
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
end)

function CutsceneReader.isActive()
	return Cutscene.isActive()
end

Help.register({
	id = "cutscene",
	priority = 60,
	active = Cutscene.isActive,
	lines = function()
		return { Strings.get("help.cutscene") }
	end,
})

return CutsceneReader
