-- Speaks the game's menus (necro.menu.Menu). Polled once per tick after the game handled menu input.
-- On open: the title (menu label, or the heading entries above the first choice), any message lines,
-- then the selected entry. On move: the entry, preceded by its section heading when that changes.
-- Message lines that change while the menu is open (calibration steps, countdowns) are spoken too.

local Menu = require("necro.menu.Menu")

local Buffers = require("CryptAccess.Buffers")
local Help = require("CryptAccess.Help")
local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")
local Text = require("CryptAccess.Text")
local Timer = require("system.utils.Timer")

local MenuReader = {}

local last = {
	menuKey = false,
	entryKey = false,
	label = false,
	heading = false,
	messages = {},
	messageTimes = {},
}

-- Per-menu extras: name -> { onOpen = function(menu) -> lines, hint = string key }.
MenuReader.special = {}

-- More info lines than this changing in one tick is a table being filled, not a message.
local BULK_LINES = 6

--- Hooks other scripts can set: called with the menu when it opens.
MenuReader.listeners = {}

local function eval(value, default)
	if type(value) == "function" then
		local ok, result = pcall(value)
		if ok then
			return result
		end
		return default
	elseif value == nil then
		return default
	end
	return value
end

local function isSelectable(entry)
	local hasAction = entry.action or entry.textEntry or entry.leftAction or entry.rightAction
	return hasAction and eval(entry.selectableIf, true) and not eval(entry.hidden, false)
end

local function isEnabled(entry)
	if entry.toolEnabled == false then
		return false
	end
	if not (entry.action or entry.textEntry) then
		return true -- slider-like entries with only left/right actions
	end
	return eval(entry.enableIf, true)
end

local function labelOf(entry, selected)
	if not entry then
		return ""
	end
	-- Icon buttons (the mod browser) name themselves through toolLabel, and mod tiles only show a
	-- two-letter badge, so their id ("tile_CryptAccess") gives the name.
	local id = type(entry.id) == "string" and entry.id or ""
	if id:find("^tile_") then
		local name = id:sub(6):gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
		return Text.clean(name)
	end
	local text = Text.clean(Text.eval(entry.label, selected or false))
	if text == "" and entry.toolLabel then
		text = Text.clean(Text.eval(entry.toolLabel))
	end
	return text
end

--- Selectable entries that have something to say.
local function choices(currentMenu)
	if currentMenu.lockSelection then
		return { currentMenu.selection }
	end
	local list = {}
	for i, entry in ipairs(currentMenu.entries or {}) do
		if isSelectable(entry) and not entry.skipSelection then
			list[#list + 1] = i
		end
	end
	return list
end

local function firstChoiceIndex(currentMenu)
	if currentMenu.lockSelection then
		return currentMenu.selection or 1
	end
	for i, entry in ipairs(currentMenu.entries or {}) do
		if isSelectable(entry) and not entry.skipSelection and labelOf(entry) ~= "" then
			return i
		end
	end
	return #(currentMenu.entries or {}) + 1
end

--- Non-selectable entries with text: headings and messages. Returns {index, text}.
--- In menus with a locked selection every other entry is a message.
local function infoLines(currentMenu)
	local lines = {}
	local rows = {}
	for i, entry in ipairs(currentMenu.entries or {}) do
		local info = not isSelectable(entry) or (currentMenu.lockSelection and i ~= currentMenu.selection)
		if info and not eval(entry.hidden, false) then
			local text = labelOf(entry)
			if text ~= "" then
				-- Cells of a table row (same y, different x) become one line.
				local y = type(entry.y) == "number" and math.floor(entry.y / 4 + 0.5) or nil
				local row = y and rows[y]
				if row and type(entry.x) == "number" and entry.x ~= row.x then
					row.line.text = row.line.text .. ", " .. text
				else
					local line = { index = i, text = text }
					lines[#lines + 1] = line
					if y then
						rows[y] = { line = line, x = entry.x }
					end
				end
			end
		end
	end
	return lines
end

--- The other cells on the selected entry's row (tables such as leaderboards), in x order.
local function rowContext(currentMenu, entry)
	if type(entry) ~= "table" or type(entry.y) ~= "number" then
		return nil
	end
	local cells = {}
	for _, other in ipairs(currentMenu.entries or {}) do
		if other ~= entry and type(other.y) == "number" and math.abs(other.y - entry.y) <= 3
			and type(other.x) == "number" and not eval(other.hidden, false)
			-- Only texts that cannot be selected belong to the entry (table cells, slider values);
			-- selectable neighbours (grid tiles, toolbar buttons) are choices of their own.
			and not isSelectable(other) then
			local text = labelOf(other)
			if text ~= "" then
				cells[#cells + 1] = { x = other.x, text = text, order = #cells }
			end
		end
	end
	if #cells == 0 then
		return nil
	end
	table.sort(cells, function(a, b)
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.order < b.order
	end)
	-- The selected cell first, then the rest of its row in reading order.
	local parts = {}
	for _, c in ipairs(cells) do
		parts[#parts + 1] = c.text
	end
	local own = labelOf(entry, true)
	-- "Music volume:" followed by its value reads as one phrase.
	local joiner = own:find(":%s*$") and " " or ". "
	return own .. joiner .. table.concat(parts, ", ")
end

--- The selectable-looking entries whose label is a message (selectable but with no label of their own
--- are skipped). Used for the "x of y" position.
local function position(currentMenu)
	local index, count = 0, 0
	for _, i in ipairs(choices(currentMenu)) do
		local entry = currentMenu.entries[i]
		if labelOf(entry) ~= "" then
			count = count + 1
			if i == currentMenu.selection then
				index = count
			end
		end
	end
	return index, count
end

--- The heading that owns the selected entry: the nearest non-selectable text entry above it, after the
--- first choice (headings above the first choice are the title area).
local function headingFor(currentMenu, selection)
	local first = firstChoiceIndex(currentMenu)
	for i = (selection or 1) - 1, first + 1, -1 do
		local entry = currentMenu.entries[i]
		-- Headings are centred lines (no x offset); table cells sit at an x offset.
		local centred = entry and (entry.x == nil or entry.x == 0)
		if entry and centred and not isSelectable(entry) then
			local text = labelOf(entry)
			if text ~= "" then
				return text
			end
		end
	end
	return false
end

function MenuReader.describeEntry(currentMenu, entry)
	local label = labelOf(entry, true)
	if label == "" then
		return ""
	end
	label = rowContext(currentMenu, entry) or label
	local parts = { label }
	if not isEnabled(entry) then
		parts[#parts + 1] = Strings.get("menu.unavailable")
	end
	if (entry.leftAction or entry.rightAction) and not entry.hideArrows then
		parts[#parts + 1] = Strings.get("menu.adjustable")
	end
	if entry.textEntry then
		parts[#parts + 1] = Strings.get("menu.textField")
	end
	if MenuReader.positionsEnabled() then
		local index, count = position(currentMenu)
		if index > 0 and count > 1 then
			parts[#parts + 1] = Strings.get("menu.position", { index = index, count = count })
		end
	end
	return table.concat(parts, ", ")
end

function MenuReader.positionsEnabled()
	local Config = require("CryptAccess.Config")
	return Config.get("speakPositions") ~= false
end

function MenuReader.describeSelection(currentMenu)
	currentMenu = currentMenu or Menu.getCurrent()
	if not currentMenu then
		return ""
	end
	return MenuReader.describeEntry(currentMenu, Menu.getSelectedEntry(currentMenu))
end

local function menuTitle(currentMenu)
	local title = Text.clean(Text.eval(currentMenu.label))
	return title
end

--- Title lines: the menu label, or the info lines above the first choice.
local function openingLines(currentMenu)
	local lines = {}
	local title = menuTitle(currentMenu)
	if title ~= "" then
		lines[#lines + 1] = title
	end
	local first = firstChoiceIndex(currentMenu)
	local selectableCount = #choices(currentMenu)
	local special = MenuReader.special[tostring(currentMenu.name)]
	for _, info in ipairs(infoLines(currentMenu)) do
		-- Short menus (dialogs, calibration) are all message; long ones only their top area, unless a
		-- special reader marks the menu's info as all worth hearing (allInfo).
		if info.index < first or selectableCount <= 3 or (special and special.allInfo) then
			lines[#lines + 1] = info.text
		end
	end
	if special and special.onOpen then
		local ok, extra = pcall(special.onOpen, currentMenu)
		if ok and type(extra) == "table" then
			for _, line in ipairs(extra) do
				lines[#lines + 1] = line
			end
		end
	end
	return lines
end

local function snapshotMessages(currentMenu)
	local messages = {}
	for _, info in ipairs(infoLines(currentMenu)) do
		messages[info.index] = info.text
	end
	return messages
end

--- Labels of the menu's choices, as a set (to notice entries added while the menu is open).
local function choiceLabels(currentMenu)
	local set, count = {}, 0
	for _, i in ipairs(choices(currentMenu)) do
		local text = labelOf(currentMenu.entries[i])
		if text ~= "" then
			set[text] = true
			count = count + 1
		end
	end
	return set, count
end

local function detailsFor(currentMenu, entry, spoken)
	local lines = { spoken }
	local tooltip = entry and (entry.tooltip or entry.description)
	if tooltip then
		local text = Text.clean(Text.eval(tooltip))
		if text ~= "" then
			lines[#lines + 1] = text
		end
	end
	local special = MenuReader.special[tostring(currentMenu.name)]
	if special and special.details then
		local ok, extra = pcall(special.details, currentMenu, entry)
		if ok and type(extra) == "table" then
			for _, line in ipairs(extra) do
				lines[#lines + 1] = line
			end
		end
	end
	return lines
end

function MenuReader.update()
	local currentMenu = Menu.getCurrent()
	if not currentMenu then
		if last.menuKey then
			last.menuKey, last.entryKey, last.label, last.heading = false, false, false, false
			last.messages = {}
		end
		return
	end

	local menuKey = tostring(currentMenu.name) .. "|" .. tostring(currentMenu.uniqueID) .. "|" .. menuTitle(currentMenu)
	local entry = Menu.getSelectedEntry(currentMenu)
	local entryKey = tostring(currentMenu.selection) .. "|" .. tostring(Menu.getSelectedID(currentMenu))
	local label = MenuReader.describeEntry(currentMenu, entry)

	if menuKey ~= last.menuKey then
		local lines = openingLines(currentMenu)
		if label ~= "" then
			lines[#lines + 1] = label
		end
		Speech.say(Text.sentences(lines), true)
		Speech.debug(string.format("menu %s, entry %s", tostring(currentMenu.name), entryKey))
		last.heading = headingFor(currentMenu, currentMenu.selection)
		last.messages = snapshotMessages(currentMenu)
		last.choices, last.choiceCount = choiceLabels(currentMenu)
		last.watch, last.watchTimes = {}, {}
		for _, i in ipairs(choices(currentMenu)) do
			last.watch[i] = labelOf(currentMenu.entries[i])
		end
		local details = detailsFor(currentMenu, entry, label ~= "" and label or Text.sentences(lines))
		-- Long menus: the lines not spoken on open (tables, notes) are one Ctrl+Up away.
		if #choices(currentMenu) > 3 then
			local first = firstChoiceIndex(currentMenu)
			for _, info in ipairs(infoLines(currentMenu)) do
				if info.index > first then
					details[#details + 1] = info.text
				end
			end
		end
		Buffers.focus(details)
		for _, listener in ipairs(MenuReader.listeners) do
			pcall(listener, currentMenu)
		end
	else
		if entryKey ~= last.entryKey then
			local heading = headingFor(currentMenu, currentMenu.selection)
			local text = label
			if heading and heading ~= last.heading then
				text = Text.sentences({ heading, label })
			end
			last.heading = heading
			if text ~= "" then
				Speech.say(text, true)
			end
			Buffers.focus(detailsFor(currentMenu, entry, label))
		elseif label ~= last.label and label ~= "" and not Menu.isTextEntryActive() then
			-- Same entry, new text: a value changed (slider, toggle, option cycle).
			Speech.say(label, true)
			Buffers.focus(detailsFor(currentMenu, entry, label))
		end
		-- Message lines that changed by themselves.
		local now = Timer.getGlobalTime()
		local messages = snapshotMessages(currentMenu)
		local changed = 0
		for index, text in pairs(messages) do
			if last.messages[index] ~= text then
				changed = changed + 1
			end
		end
		-- Many lines changing at once is content loading (a table), not a message: leave it to the buffer.
		-- A few lines changing together (a status block: calibration result, a rebuilt description) is
		-- spoken as one message, unless a special reader says it speaks that menu's changes itself.
		local special = MenuReader.special[tostring(currentMenu.name)]
		if changed > BULK_LINES then
			messages.__bulk = true
		elseif changed > 1 and not (special and special.ownMessages) then
			if now - (last.blockTime or -10) > 0.5 then
				last.blockTime = now
				local block = {}
				for _, info in ipairs(infoLines(currentMenu)) do
					if last.messages[info.index] ~= info.text then
						block[#block + 1] = info.text
						last.messageTimes[info.index] = now
					end
				end
				Speech.say(Text.sentences(block), false)
			else
				-- Too soon after the last block (lines ticking every frame): retry when they settle.
				for index in pairs(messages) do
					messages[index] = last.messages[index]
				end
			end
		elseif changed == 1 then
			for index, text in pairs(messages) do
				if last.messages[index] ~= text then
					local lastTime = last.messageTimes[index] or -10
					-- Lines that change every frame (timers): at most twice a second per line. A skipped
					-- change keeps the old text as "last", so the line's final value is spoken once it settles.
					if now - lastTime > 0.5 then
						last.messageTimes[index] = now
						Speech.say(text, false)
					else
						messages[index] = last.messages[index]
					end
				end
			end
		end
		if messages.__bulk then
			local lines = { label ~= "" and label or menuTitle(currentMenu) }
			for _, info in ipairs(infoLines(currentMenu)) do
				lines[#lines + 1] = info.text
			end
			Buffers.focus(lines)
		end
		messages.__bulk = nil
		last.messages = messages
		-- Entries that appeared while the menu is open (a co-op player added): say them, if only a few.
		local labels, count = choiceLabels(currentMenu)
		-- Only when the menu grew: a toggle changing its own label is not a new entry.
		if last.choices and count > (last.choiceCount or count) then
			local added = {}
			for text in pairs(labels) do
				if not last.choices[text] then
					added[#added + 1] = text
				end
			end
			if #added > 0 and #added <= 2 and count > 1 then
				Speech.say(Strings.get("menu.added", { items = Strings.join(added) }), false)
			end
		end
		last.choices = labels
		last.choiceCount = count
		-- Menus whose unselected rows change by themselves (download percentages): say a row's new text,
		-- at most every 2 seconds per row; a skipped change is retried, so the final value is heard.
		local watchSpecial = MenuReader.special[tostring(currentMenu.name)]
		if watchSpecial and watchSpecial.watchChoices then
			last.watch = last.watch or {}
			last.watchTimes = last.watchTimes or {}
			for _, i in ipairs(choices(currentMenu)) do
				if i ~= currentMenu.selection then
					local text = labelOf(currentMenu.entries[i])
					if last.watch[i] ~= nil and last.watch[i] ~= text and text ~= "" then
						if now - (last.watchTimes[i] or -10) > 2 then
							last.watchTimes[i] = now
							last.watch[i] = text
							Speech.say(text, false)
						end
					else
						last.watch[i] = text
					end
				end
			end
		end
	end

	last.menuKey, last.entryKey, last.label = menuKey, entryKey, label
end

--- Re-reads the menu title and selection (the repeat key in menus).
function MenuReader.repeatCurrent()
	local currentMenu = Menu.getCurrent()
	if not currentMenu then
		return false
	end
	local lines = openingLines(currentMenu)
	local label = MenuReader.describeSelection(currentMenu)
	if label ~= "" then
		lines[#lines + 1] = label
	end
	Speech.say(Text.sentences(lines), true)
	return true
end

function MenuReader.isOpen()
	return Menu.isOpen() and Menu.getCurrent() ~= nil
end

event.tick.add("cryptAccessMenuReader", { order = "menu", sequence = 10 }, function()
	MenuReader.update()
end)

-- Dialogs framed with a portrait (necro.menu.generic.BestiaryMenu: character unlocks, the Bard and
-- mode confirmations): the portrait is described after the message and the selected choice, and it is
-- the last line of the details buffer.
local function portraitOf(currentMenu)
	local arg = type(currentMenu) == "table" and currentMenu.arg
	if type(arg) ~= "table" then
		return nil
	end
	local Describe = require("CryptAccess.Describe")
	return Describe.forType(arg.entityName) or Describe.forImage(arg.image)
end

-- Weekly Challenge (necro/menu/game/WeeklyChallengeMenu.lua): the mode's author, description and required
-- character sit between the mode dropdown and Start.
MenuReader.special.weeklyChallenge = { allInfo = true }

MenuReader.special.bestiary = {
	details = function(currentMenu)
		local picture = portraitOf(currentMenu)
		return picture and { picture } or {}
	end,
}

MenuReader.listeners[#MenuReader.listeners + 1] = function(currentMenu)
	if tostring(currentMenu.name) ~= "bestiary" then
		return
	end
	local Config = require("CryptAccess.Config")
	if Config.get("describeScenes") == false then
		return
	end
	local picture = portraitOf(currentMenu)
	if picture then
		Speech.say(picture, false)
	end
end

Help.register({
	id = "menu",
	priority = 50,
	active = MenuReader.isOpen,
	lines = function()
		local lines = {}
		local currentMenu = Menu.getCurrent()
		local special = currentMenu and MenuReader.special[tostring(currentMenu.name)]
		if special and special.help then
			for _, key in ipairs(special.help) do
				lines[#lines + 1] = Strings.get(key)
			end
		end
		lines[#lines + 1] = Strings.get("help.menu.move")
		lines[#lines + 1] = Strings.get("help.menu.change")
		lines[#lines + 1] = Strings.get("help.menu.select")
		lines[#lines + 1] = Strings.get("help.menu.back")
		return lines
	end,
})

return MenuReader
