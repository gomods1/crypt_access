-- Turns game display strings into speakable text: strips the \x03 markup codes of
-- necro.config.i18n.TextFormat, converts checkbox icons to words and collapses whitespace.

local TextFormat = require("necro.config.i18n.TextFormat")

local Text = {}

local ESC = "\3"

local function plainFind(haystack, needle, replacement)
	if needle == nil or needle == "" then
		return haystack
	end
	local result, start = {}, 1
	while true do
		local first, last = string.find(haystack, needle, start, true)
		if not first then
			break
		end
		result[#result + 1] = haystack:sub(start, first - 1)
		result[#result + 1] = replacement
		start = last + 1
	end
	result[#result + 1] = haystack:sub(start)
	return table.concat(result)
end

local function getSymbolWords()
	local Strings = require("CryptAccess.Strings")
	local symbol = TextFormat.Symbol
	local on = " " .. Strings.get("text.checked") .. " "
	local off = " " .. Strings.get("text.notChecked") .. " "
	return {
		{ symbol.CHECKBOX_ON, on },
		{ symbol.CHECKBOX_OFF, off },
		{ symbol.SMALL_CHECKBOX_ON, on },
		{ symbol.SMALL_CHECKBOX_OFF, off },
		{ symbol.INFINITY, " " .. Strings.get("text.infinite") .. " " },
	}
end

--- Strips formatting codes. Icons become nothing unless they are known symbols.
function Text.clean(value)
	if value == nil then
		return ""
	end
	local text = tostring(value)
	if text:find(ESC, 1, true) then
		for _, pair in ipairs(getSymbolWords()) do
			text = plainFind(text, pair[1], pair[2])
		end
		text = text:gsub("\3#%x%x%x%x%x%x", "")
		text = text:gsub("\3T%x%x", "")
		text = text:gsub("\3b%x%x%x%x%x%x%x%x", "")
		text = text:gsub("\3m[%d%.%-]*;", "")
		text = text:gsub("\3o[%d%.%-]*;[%d%.%-]*;;", "")
		text = text:gsub("\3I[%d%.%-]*;[%d%.%-]*;[%d%.%-]*;[%d%.%-]*;[%d%.%-]*;[%d%.%-eE]*;", "")
		text = text:gsub("\3[rufc]", "")
		text = text:gsub("\3.", "")
	end
	text = text:gsub("[\16\17\18]", " ")
	-- A line break before an upper-case letter ends a sentence; before lower case it is word wrap.
	text = text:gsub("([^%.!%?:;,%s])[ \t]*\n%s*(%u)", "%1. %2")
	text = text:gsub("[%c]", " ")
	text = text:gsub("%s+", " ")
	text = text:gsub("^ ", ""):gsub(" $", "")
	return text
end

--- Evaluates a label that may be a function (menu entries pass isSelected).
function Text.eval(value, ...)
	if type(value) == "function" then
		local ok, result = pcall(value, ...)
		return ok and result or nil
	end
	return value
end

local ELLIPSIS = string.char(226, 128, 166)

--- True when text starts with a lower-case letter (ASCII, or Latin-1 accented letters in UTF-8),
--- which means it continues the previous line of a wrapped message.
local function startsLower(text)
	-- A quote that opens a wrapped phrase ("selección de personaje") does not start a sentence.
	text = text:gsub("^[\"']", "")
	local b1, b2 = text:byte(1, 2)
	if not b1 then
		return false
	end
	if b1 >= 97 and b1 <= 122 then
		return true
	end
	return b1 == 0xC3 and b2 ~= nil and b2 >= 0xA0
end

--- Joins lines into one utterance. A line without end punctuation gets a period, unless the next
--- line starts in lower case (a message wrapped over several menu entries).
function Text.sentences(lines)
	local list = {}
	for _, line in ipairs(lines) do
		if type(line) == "string" and line ~= "" then
			list[#list + 1] = line
		end
	end
	local out = {}
	for i, line in ipairs(list) do
		local nextLine = list[i + 1]
		if line:find("[%.!%?:;,]$") or line:sub(-3) == ELLIPSIS or (nextLine and startsLower(nextLine)) then
			out[#out + 1] = line
		else
			out[#out + 1] = line .. "."
		end
	end
	return table.concat(out, " ")
end

--- Joins the lines of a wrapped label: a line starting in lower case continues the previous one.
function Text.joinWrapped(lines)
	local out = ""
	for i, line in ipairs(lines) do
		if i == 1 then
			out = line
		elseif startsLower(line) or out:find("[%.!%?:;,]$") then
			out = out .. " " .. line
		else
			out = out .. ", " .. line
		end
	end
	return out
end

return Text
