-- Echoes typing in text fields: menu text entries (seed, names, search) and the chat box.
-- Typed characters are spoken; deleted characters are spoken as "deleted x". Opening a field says
-- its current text; closing it says the final text. While typing, the mod's hotkeys are off.

local Chat = require("necro.client.Chat")
local Menu = require("necro.menu.Menu")

local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")

local TextEntry = {}

local active = false
local lastValue = ""

local function eval(value)
	if type(value) == "function" then
		local ok, result = pcall(value)
		return ok and result or nil
	end
	return value
end

local function charName(c)
	if c == " " then
		return Strings.get("char.space")
	end
	return c
end

--- Current field text and whether a field is being edited.
local function currentField()
	local okChat, chatOpen = pcall(Chat.isChatboxOpen)
	if okChat and chatOpen then
		local ok, text = pcall(Chat.getChatboxText)
		return true, ok and tostring(text or "") or "", "chat"
	end
	local okMenu, editing = pcall(Menu.isTextEntryActive)
	if okMenu and editing then
		local entry = Menu.getSelectedEntry()
		local value = nil
		if entry then
			-- The label shows the live text (with a cursor code); the getter may hold the committed text.
			local label = entry.label
			if type(label) == "function" then
				local ok, result = pcall(label, true)
				label = ok and result or ""
			end
			value = Text.clean(label)
			if value == "" then
				value = eval(entry.textEntryGet)
			end
		end
		return true, tostring(value or ""), "menu"
	end
	return false, "", nil
end

function TextEntry.isActive()
	return active
end

local function utf8Chars(s)
	local list = {}
	for ch in tostring(s):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		list[#list + 1] = ch
	end
	return list
end

event.tick.add("cryptAccessTextEntry", { order = "menu", sequence = 12 }, function()
	local editing, value, kind = currentField()
	if editing and not active then
		active = true
		lastValue = value
		Keys.setEnabled(false)
		Speech.say(Strings.get(kind == "chat" and "text.chatOpen" or "text.editing", { text = value }), true)
		return
	elseif not editing and active then
		active = false
		Keys.setEnabled(true)
		Speech.say(Strings.get("text.done", { text = Text.clean(lastValue) }), true)
		lastValue = ""
		return
	end
	if not editing or value == lastValue then
		return
	end
	local old, new = utf8Chars(lastValue), utf8Chars(value)
	if #new > #old and value:sub(1, #lastValue) == lastValue then
		local added = {}
		for i = #old + 1, #new do
			added[#added + 1] = charName(new[i])
		end
		Speech.say(table.concat(added, " "), true)
	elseif #new < #old and lastValue:sub(1, #value) == value then
		local removed = {}
		for i = #new + 1, #old do
			removed[#removed + 1] = charName(old[i])
		end
		Speech.say(Strings.get("text.deleted", { text = table.concat(removed, " ") }), true)
	else
		Speech.say(value, true)
	end
	lastValue = value
end)

return TextEntry
