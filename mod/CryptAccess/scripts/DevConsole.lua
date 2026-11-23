-- Developer console for testing by script (never needed by players, never shipped: tools/package.ps1
-- leaves it out). Active only when the file <mod>\dev\enabled exists. tools/dev.py writes a Lua chunk to
-- dev\cmd.lua with a first line "--id N"; this script runs it once per new id and writes the result to
-- dev\out.txt. The chunk sees:
--   R(name)        any engine or mod module (the sandbox require, else package.loaded)
--   M.Name         a Crypt Access module (M.World, M.Scanner, ...)
--   key(...)       queue key presses: "enter", "wait" (8 frames), "beat:left" (pressed when the beat
--                  window opens), "ctrl+up" / "shift+pagedown" (mod hotkeys with modifiers),
--                  "up&down" (simultaneous presses, the game's combinations)
--   S(value)       serialize a value
--   setKeyLog(on)  log every pressed key name and id to NecroDancer.log

local Native = require("CryptAccess.Native")
local Timer = require("system.utils.Timer")
local Input = require("system.game.Input")

local DevConsole = {}

local state = script.persist(function()
	return { lastID = false, nextPoll = 0, pendingKeys = {}, keyLog = false, earlyFrames = 0 }
end)

local function folder()
	local base = Native.modFolder()
	return base and (base .. "\\dev") or nil
end

local function readFile(path)
	local io = Native.io
	local f = io and io.open(path, "rb")
	if not f then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
end

local function writeFile(path, text)
	local f = Native.io and Native.io.open(path, "wb")
	if f then
		f:write(text)
		f:close()
	end
end

local function serialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	local t = type(value)
	if t == "string" then
		return string.format("%q", value)
	elseif t ~= "table" then
		return tostring(value)
	end
	if seen[value] then
		return "<cycle>"
	end
	if depth > 3 then
		return "{...}"
	end
	seen[value] = true
	local parts, count = {}, 0
	for k, v in pairs(value) do
		count = count + 1
		if count > 60 then
			parts[#parts + 1] = "..."
			break
		end
		parts[#parts + 1] = tostring(k) .. "=" .. serialize(v, depth + 1, seen)
	end
	seen[value] = nil
	return "{" .. table.concat(parts, ", ") .. "}"
end
DevConsole.serialize = serialize

local sandboxRequire = require

--- The mod's own require (lazy module interfaces), falling back to package.loaded for modules the
--- sandbox does not allow (core.*, necro.mod.*).
local function rawRequire(name)
	local ok, module = pcall(sandboxRequire, name)
	if ok then
		return module
	end
	local loaded = Native.package and Native.package.loaded[name]
	if loaded ~= nil then
		return loaded
	end
	error(module, 2)
end

--- Queues key presses (see the header for the syntax).
local function key(...)
	for _, name in ipairs({ ... }) do
		state.pendingKeys[#state.pendingKeys + 1] = name
	end
	return #state.pendingKeys
end

local function modules()
	return setmetatable({}, {
		__index = function(_, name)
			return rawRequire("CryptAccess." .. name)
		end,
	})
end

local function run(code)
	local chunk, err = Native.lib.loadstring(code, "=devcmd")
	if not chunk then
		return "compile error: " .. tostring(err)
	end
	local out = {}
	local env = Native.lib.setmetatable({
		R = rawRequire,
		M = modules(),
		key = key,
		S = serialize,
		setKeyLog = function(on)
			state.keyLog = on
		end,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[#parts + 1] = tostring((select(i, ...)))
			end
			out[#out + 1] = table.concat(parts, "\t")
		end,
	}, { __index = Native.lib.getfenv(1) })
	Native.lib.setfenv(chunk, env)
	local results = { pcall(chunk) }
	if not results[1] then
		out[#out + 1] = "runtime error: " .. tostring(results[2])
	else
		for i = 2, #results do
			out[#out + 1] = serialize(results[i])
		end
	end
	return table.concat(out, "\n")
end

local function poll()
	local dir = folder()
	if not dir then
		return
	end
	local code = readFile(dir .. "\\cmd.lua")
	if not code then
		return
	end
	local id = code:match("^%-%-id (%S+)")
	if not id or id == state.lastID then
		return
	end
	state.lastID = id
	local result = run(code)
	writeFile(dir .. "\\out.txt", "--id " .. id .. "\n" .. result .. "\n")
end

local held = {}

local function pumpKeys(input)
	-- Release keys pressed a few frames ago.
	for i = #held, 1, -1 do
		local h = held[i]
		h.frames = h.frames - 1
		if h.frames <= 0 then
			if h.forced then
				rawRequire("CryptAccess.Keys").setForcedModifiers(false)
			end
			local id = h.name ~= "wait" and input.getRawKeyID(h.name)
			if id then
				input.appendKeyEvents({ -id, Timer.getGlobalTime() })
			end
			table.remove(held, i)
		end
	end
	if #held > 0 or not state.pendingKeys[1] then
		return
	end
	local nextName = state.pendingKeys[1]
	if nextName:sub(1, 5) == "beat:" then
		-- Press on the beat: once the game no longer finds the press too early for the next beat.
		local okMap, map = pcall(function()
			return require("necro.audio.Beatmap").getPrimary()
		end)
		if not (okMap and map) then
			return
		end
		if map.isBeatTooEarly() or map.isLockoutActive() then
			state.earlyFrames = 0
			return
		end
		state.earlyFrames = (state.earlyFrames or 0) + 1
		if state.earlyFrames < 3 then
			return
		end
		state.earlyFrames = 0
		state.pendingKeys[1] = nextName:sub(6)
	end
	local name = table.remove(state.pendingKeys, 1)
	local modsPart, base = name:match("^(.+)%+(%w+)$")
	if modsPart then
		rawRequire("CryptAccess.Keys").setForcedModifiers({
			ctrl = modsPart:find("ctrl") ~= nil,
			shift = modsPart:find("shift") ~= nil,
			alt = modsPart:find("alt") ~= nil,
		})
		name = base
	end
	if name:find("&") then
		-- Simultaneous presses (the game's two-key combinations), e.g. "up&down".
		local now = Timer.getGlobalTime()
		for part in name:gmatch("[^&]+") do
			local id = input.getRawKeyID(part)
			input.appendKeyEvents({ id, now })
			held[#held + 1] = { name = part, frames = 3 }
		end
	elseif name ~= "wait" then
		local id = input.getRawKeyID(name)
		if id then
			input.appendKeyEvents({ id, Timer.getGlobalTime() })
			held[#held + 1] = { name = name, frames = 3, forced = modsPart ~= nil }
		else
			log.warn("DevConsole: unknown key %s", tostring(name))
		end
	else
		held[#held + 1] = { name = "wait", frames = 8 }
	end
end

local enabled = nil

event.tick.add("cryptAccessDevConsole", { order = "menu", sequence = 1 }, function()
	if enabled == nil then
		local dir = folder()
		enabled = dir ~= nil and readFile(dir .. "\\enabled") ~= nil
		if enabled then
			log.info("DevConsole enabled")
		end
	end
	if not enabled then
		return
	end
	pumpKeys(Input)
	if state.keyLog then
		local pressed = Input.getPressedKeys()
		if pressed[1] then
			local names = {}
			for i, k in ipairs(pressed) do
				names[i] = tostring(k) .. "=" .. tostring(Input.getRawKeyID(k))
			end
			log.info("DevConsole keys: %s", table.concat(names, " "))
		end
	end
	local now = Timer.getGlobalTime()
	if now >= state.nextPoll then
		state.nextPoll = now + 0.2
		local ok, err = pcall(poll)
		if not ok then
			log.warn("DevConsole: %s", tostring(err))
		end
	end
end)

return DevConsole
