-- Review buffers (template section 8). Ctrl+Up/Down move inside the current buffer, Ctrl+Left/Right
-- switch buffers (skipping empty ones). The focused thing's buffer ("details") holds that thing only:
-- line 1 is its name and summary, then its detail lines.

local Keys = require("CryptAccess.Keys")
local Speech = require("CryptAccess.Speech")
local Strings = require("CryptAccess.Strings")

local Buffers = {}

local MAX_EVENTS = 200

-- Order of the buffers when switching with Ctrl+Left/Right.
local order = { "details", "events", "surroundings", "inventory" }
local buffers = {}
for _, id in ipairs(order) do
	buffers[id] = { id = id, items = {}, cursor = 0 }
end
local current = "details"

local function nameOf(id)
	return Strings.get("buffer." .. id)
end

--- Replaces a buffer's lines. Focus-fed buffers start on line 1 (the name just spoken).
function Buffers.set(id, lines, makeCurrent)
	local b = buffers[id]
	if not b then
		return
	end
	b.items = {}
	for _, line in ipairs(lines or {}) do
		if type(line) == "string" and line ~= "" then
			b.items[#b.items + 1] = line
		end
	end
	b.cursor = 1
	if makeCurrent ~= false then
		current = id
	end
end

--- Sets the details buffer for a newly focused thing and makes it current.
function Buffers.focus(lines)
	Buffers.set("details", lines, true)
end

--- Adds an event line at the top of the events buffer (newest first).
function Buffers.addEvent(line)
	local b = buffers.events
	table.insert(b.items, 1, line)
	if b.cursor > 0 then
		b.cursor = b.cursor + 1
	end
	while #b.items > MAX_EVENTS do
		table.remove(b.items)
	end
end

function Buffers.clear(id)
	if buffers[id] then
		buffers[id].items = {}
		buffers[id].cursor = 0
	end
end

local function speakLine(b)
	local line = b.items[b.cursor]
	if line then
		Speech.say(line, true)
	end
end

function Buffers.move(delta)
	local b = buffers[current]
	if not b or #b.items == 0 then
		Speech.say(Strings.get("buffer.empty", { name = nameOf(current) }), true)
		return
	end
	local target = b.cursor + delta
	if target < 1 then
		b.cursor = 1
		Speech.say(Strings.get("buffer.top") .. ". " .. b.items[1], true)
		return
	elseif target > #b.items then
		b.cursor = #b.items
		Speech.say(Strings.get("buffer.end") .. ". " .. b.items[#b.items], true)
		return
	end
	b.cursor = target
	speakLine(b)
end

function Buffers.switch(delta)
	local index = 1
	for i, id in ipairs(order) do
		if id == current then
			index = i
		end
	end
	for step = 1, #order do
		local i = ((index - 1 + delta * step) % #order) + 1
		local b = buffers[order[i]]
		if #b.items > 0 then
			current = order[i]
			if current == "events" then
				b.cursor = 0
			end
			Speech.say(Strings.get("buffer.switch", { name = nameOf(current), count = #b.items }), true)
			return
		end
	end
	Speech.say(Strings.get("buffer.allEmpty"), true)
end

function Buffers.current()
	return current
end

Keys.bind({ key = "up", ctrl = true, id = "bufferDeeper", fn = function()
	Buffers.move(1)
end })
Keys.bind({ key = "down", ctrl = true, id = "bufferTop", fn = function()
	Buffers.move(-1)
end })
Keys.bind({ key = "right", ctrl = true, id = "bufferNext", fn = function()
	Buffers.switch(1)
end })
Keys.bind({ key = "left", ctrl = true, id = "bufferPrevious", fn = function()
	Buffers.switch(-1)
end })

return Buffers
