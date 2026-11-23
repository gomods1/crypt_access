-- Hotkey dispatcher. Runs before the game reads its input (tick order "inputContext", negative sequence),
-- so a claimed key is removed with Input.suppressKey and the game never acts on it.
-- Key names are the engine's (lower case): letters, "f1".."f12", "up", "down", "left", "right", "home",
-- "end", "pageup", "pagedown", "enter", "escape", "space", "tab", "backspace", "delete".
-- Punctuation names depend on the keyboard layout, so the mod never binds punctuation.

local Input = require("system.game.Input")

local Keys = {}

local bindings = {}
local modals = {}

--- Binds a key. spec: key, ctrl, shift, alt (booleans, default false), when (function -> bool),
--- fn (function), id (for the help list), repeatable (fires on key repeat too).
function Keys.bind(spec)
	-- A script reloaded by the game binds again: replace its old binding (same id) instead of
	-- keeping a closure over the unloaded copy.
	if spec.id then
		for i, existing in ipairs(bindings) do
			if existing.id == spec.id then
				bindings[i] = spec
				return spec
			end
		end
	end
	bindings[#bindings + 1] = spec
	return spec
end

--- Pushes a modal key handler: handler(key, mods) returns true when it used the key.
--- While a modal is on the stack it sees every key first, and keys it uses never reach the game.
function Keys.pushModal(name, handler)
	Keys.popModal(name)
	modals[#modals + 1] = { name = name, handler = handler }
end

function Keys.popModal(name)
	for i = #modals, 1, -1 do
		if modals[i].name == name then
			table.remove(modals, i)
		end
	end
end

function Keys.modalActive(name)
	for i = 1, #modals do
		if not name or modals[i].name == name then
			return true
		end
	end
	return false
end

local function down(name)
	return Input.keyDown(name)
end

-- Test hook (DevConsole): modifiers to pretend are held for the next key press.
local forcedModifiers = false

function Keys.setForcedModifiers(mods)
	forcedModifiers = mods or false
end

function Keys.modifiers()
	if forcedModifiers then
		return forcedModifiers
	end
	return {
		ctrl = down("lcontrol") or down("rcontrol"),
		shift = down("lshift") or down("rshift"),
		alt = down("lalt") or down("ralt"),
	}
end

local ARROWS = { up = true, down = true, left = true, right = true }

--- Keys the game must not see while Ctrl or Shift is held (they would move the player or the menu).
local function shouldSwallowWithModifier(key, mods)
	return (mods.ctrl or mods.shift) and ARROWS[key]
end

local function matches(spec, key, mods)
	return spec.key == key
		and (spec.ctrl or false) == mods.ctrl
		and (spec.shift or false) == mods.shift
		and (spec.alt or false) == mods.alt
end

local function dispatch(key, mods)
	for i = #modals, 1, -1 do
		local ok, used = pcall(modals[i].handler, key, mods)
		if not ok then
			log.error("Keys: modal %s failed: %s", modals[i].name, tostring(used))
			return true
		end
		if used then
			return true
		end
	end
	for _, spec in ipairs(bindings) do
		if matches(spec, key, mods) then
			local active = true
			if spec.when then
				local ok, result = pcall(spec.when)
				active = ok and result
			end
			if active then
				local ok, err = pcall(spec.fn)
				if not ok then
					log.error("Keys: %s failed: %s", tostring(spec.id or key), tostring(err))
				end
				return true
			end
		end
	end
	return false
end

local enabled = true

--- Turns every mod hotkey off (while typing in a text field) or back on.
function Keys.setEnabled(on)
	enabled = on and true or false
end

event.tick.add("cryptAccessKeys", { order = "inputContext", sequence = -10 }, function()
	if not enabled then
		return
	end
	local pressed = Input.getPressedKeys()
	if not pressed[1] then
		-- Still hide held arrows from the game while a modifier is down (multi-key combos read held keys).
		local mods = Keys.modifiers()
		if mods.ctrl or mods.shift then
			for name in pairs(ARROWS) do
				if Input.keyDown(name) then
					Input.suppressKey(name)
				end
			end
		end
		return
	end
	local mods = Keys.modifiers()
	for _, key in ipairs(pressed) do
		local used = dispatch(key, mods)
		if used or shouldSwallowWithModifier(key, mods) then
			Input.suppressKey(key)
		end
	end
	if mods.ctrl or mods.shift then
		for name in pairs(ARROWS) do
			if Input.keyDown(name) then
				Input.suppressKey(name)
			end
		end
	end
end)

return Keys
