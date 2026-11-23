-- F1 help: a browsable list for the current context. Up/Down read one entry, Home/End jump,
-- F1, Escape or Enter close. Contexts register with a priority; the highest active one wins.

local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")

local Help = {}

local contexts = {}

--- context: id, priority (higher wins), active (function -> bool), lines (function -> list of strings).
function Help.register(context)
	for i, c in ipairs(contexts) do
		if c.id == context.id then
			contexts[i] = context
			return
		end
	end
	contexts[#contexts + 1] = context
end

local function activeContext()
	local best
	for _, c in ipairs(contexts) do
		local ok, active = pcall(c.active)
		if ok and active and (not best or c.priority > best.priority) then
			best = c
		end
	end
	return best
end

local browser = { lines = {}, index = 1 }

local function close()
	Keys.popModal("help")
	Speech.say(Strings.get("help.closed"), true)
end

local function read()
	Speech.say(browser.lines[browser.index] or "", true)
end

local function handler(key, mods)
	if key == "escape" or key == "f1" or key == "enter" then
		close()
		return true
	elseif key == "down" then
		if browser.index < #browser.lines then
			browser.index = browser.index + 1
			read()
		else
			Speech.say(Strings.get("buffer.end") .. ". " .. browser.lines[browser.index], true)
		end
		return true
	elseif key == "up" then
		if browser.index > 1 then
			browser.index = browser.index - 1
			read()
		else
			Speech.say(Strings.get("buffer.top") .. ". " .. browser.lines[1], true)
		end
		return true
	elseif key == "home" then
		browser.index = 1
		read()
		return true
	elseif key == "end" then
		browser.index = #browser.lines
		read()
		return true
	end
	-- Swallow movement and menu keys while help is open; let everything else through.
	return key == "left" or key == "right" or key == "space"
end

function Help.open()
	local context = activeContext()
	local lines = {}
	if context then
		local ok, result = pcall(context.lines)
		if ok and type(result) == "table" then
			lines = result
		else
			log.error("Help: %s failed: %s", context.id, tostring(result))
		end
	end
	for _, line in ipairs(Help.commonLines()) do
		lines[#lines + 1] = line
	end
	browser.lines = lines
	browser.index = 1
	Keys.pushModal("help", handler)
	Speech.say(Strings.get("help.opened", { count = #lines }) .. " " .. (lines[1] or ""), true)
end

--- Lines appended to every help list: the keys that work everywhere.
function Help.commonLines()
	return {
		Strings.get("help.common.repeat"),
		Strings.get("help.common.buffers"),
		Strings.get("help.common.stop"),
		Strings.get("help.common.close"),
	}
end

Keys.bind({ key = "f1", id = "help", fn = Help.open })

return Help
