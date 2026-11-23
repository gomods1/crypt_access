-- Speaks transient on-screen text during play:
--   flyaways (necro.game.system.Flyaway: "Locked!", item names, "Missed beat"...), polled each tick;
--   voice subtitles (event.objectVocalize with the "subtitled" component, e.g. Cadence's tutorial lines);
--   the HUD text overlay on the player (hudTextOverlay.text, e.g. "Song ended! Next level").
-- Every line also goes to the Events buffer.

local Flyaway = require("necro.game.system.Flyaway")
local Player = require("necro.game.character.Player")

local Buffers = require("CryptAccess.Buffers")
local Speech = require("CryptAccess.Speech")
local Text = require("CryptAccess.Text")
local World = require("CryptAccess.World")

local ScreenText = {}

-- Text the mod already says in its own words; flyaways matching these are not repeated.
ScreenText.suppressed = {}

local seen = setmetatable({}, { __mode = "k" })

local Dedupe = require("CryptAccess.Dedupe")

local function announce(text, interrupt, turnID)
	text = Text.clean(text)
	if text == "" or ScreenText.suppressed[text] then
		return
	end
	if Dedupe.replaying() or (turnID and not Dedupe.first(text, turnID)) then
		return
	end
	-- Flyaways made only of symbols (music notes) carry no words.
	if not text:find("[%w\128-\255]") then
		return
	end
	Buffers.addEvent(text)
	Speech.say(text, interrupt or false)
end
ScreenText.announce = announce

-- Flyaways that repeat on a timer (a caged NPC calling for help) are spoken once per 20 seconds.
local REPEAT_COOLDOWN = 20
local lastSpokenAt = {}
local Timer = require("system.utils.Timer")

local function cooledDown(text)
	local now = Timer.getGlobalTime()
	local last = lastSpokenAt[text]
	if last and now - last < REPEAT_COOLDOWN and now >= last then
		return false
	end
	lastSpokenAt[text] = now
	return true
end

local function pollFlyaways(list)
	for i = 1, #list do
		local instance = list[i]
		if type(instance) == "table" and not seen[instance] then
			seen[instance] = true
			-- Only world flyaways of other things (NPC calls) get the cooldown, never the player's own
			-- feedback ("Missed!", groove chain) or HUD flyaways.
			local p = World.player()
			local fromOther = instance.worldX ~= nil and not (p and instance.animationID == p.id)
			if fromOther and not cooledDown(tostring(instance.text)) then
				goto continue
			end
			local ok, err = pcall(announce, instance.text, false, instance.turnID)
			if not ok then
				log.warn("ScreenText: %s", tostring(err))
			end
		end
		::continue::
	end
end

local lastOverlay = false
local lastSummary = false
local lastBossSplash = false

--- Names of the bosses on the level (entities with the boss component), for the boss splash.
local function bossNames()
	local Entities = require("system.game.Entities")
	local Describe = require("CryptAccess.Describe")
	local names, seenNames, pictures = {}, {}, {}
	for e in Entities.entitiesWithComponents({ "boss" }) do
		local name = World.name(e)
		if name ~= "" and not seenNames[name] then
			seenNames[name] = true
			names[#names + 1] = name
			-- The splash shows the boss's portrait: describe it (once per boss kind on screen).
			local picture = Describe.forType(e.name)
			if picture and not seenNames[picture] then
				seenNames[picture] = true
				pictures[#pictures + 1] = picture
			end
			Describe.markSeen(e.name)
		end
	end
	return names, pictures
end

--- The run-end prompt (necro.render.hud.RunSummaryHUD): outcome, killer, score, how to continue.
local function summaryText(summary)
	local Action = require("necro.game.system.Action")
	local Controls = require("necro.config.Controls")
	local Strings = require("CryptAccess.Strings")
	local parts = {}
	if summary.victory then
		parts[#parts + 1] = Strings.get("summary.won")
	elseif summary.killerName then
		parts[#parts + 1] = Strings.get("summary.diedBy", { who = Text.clean(summary.killerName) })
	else
		parts[#parts + 1] = Strings.get("summary.complete")
	end
	if type(summary.score) == "number" then
		parts[#parts + 1] = Strings.get("summary.score", { n = summary.score })
	end
	local ok, key = pcall(function()
		return Controls.getFriendlyName(Controls.getActionKeyBind(Action.Special.THROW))
	end)
	parts[#parts + 1] = Strings.get("summary.continue", { key = ok and Text.clean(key) or "" })
	return table.concat(parts, ". ")
end

event.tick.add("cryptAccessScreenText", { order = "flyaway", sequence = 10 }, function()
	local okSummary, summary = pcall(function()
		return require("necro.client.RunSummary").getPendingSummary()
	end)
	summary = okSummary and summary and not summary.autoDismiss and summary or false
	if summary ~= lastSummary then
		lastSummary = summary
		if summary then
			-- In co-op the pending summary can be another player's: say whose it is.
			local me = World.player()
			local myID = me and me.controllable and me.controllable.playerID
			if summary.playerID and myID and summary.playerID ~= myID and not summary.victory then
				local Strings = require("CryptAccess.Strings")
				local who = summary.killerName and Text.clean(summary.killerName) or ""
				announce(Strings.get("summary.partnerDied", { who = who }))
			else
				announce(summaryText(summary))
			end
		end
	end
	local okSplash, splash = pcall(function()
		return require("necro.render.hud.BossSplashHUD").isActive()
	end)
	splash = okSplash and splash or false
	if splash and not lastBossSplash then
		local names, pictures = bossNames()
		if #names > 0 then
			local Strings = require("CryptAccess.Strings")
			announce(Strings.get("event.boss", { name = Strings.join(names) }))
			if require("CryptAccess.Config").get("describeScenes") then
				for _, picture in ipairs(pictures) do
					announce(picture)
				end
			end
		end
	end
	lastBossSplash = splash
	pollFlyaways(Flyaway.getLocal())
	pollFlyaways(Flyaway.getAll())
	local ok, entity = pcall(Player.getPlayerEntity)
	local overlay = ok and entity and entity.hudTextOverlay and entity.hudTextOverlay.text or false
	if overlay == "" then
		overlay = false
	end
	if overlay ~= lastOverlay then
		lastOverlay = overlay
		if overlay then
			announce(overlay)
		end
	end
end)

event.objectVocalize.add("cryptAccessSubtitles", { filter = "subtitled", order = "subtitles", sequence = 10 }, function(ev)
	local map = ev.entity.subtitled.map
	local text = map and ev.soundGroup and map[ev.soundGroup]
	if type(text) == "string" then
		announce(text)
	end
end)

return ScreenText
