-- The key rebinding prompt (necro.client.KeyRebinder): "Press a key for Move left", "Currently bound to
-- Left". It is an overlay, not a menu; its texts are the script globals currentLabel/currentSubLabel.
-- While it waits for a key, the mod's hotkeys are off so every key reaches the game.

local KeyRebinder = require("necro.client.KeyRebinder")

local Keys = require("CryptAccess.Keys")
local Native = require("CryptAccess.Native")
local Speech = require("CryptAccess.Speech")
local Text = require("CryptAccess.Text")

local wasOpen = false

local function global(name)
	local scriptLoader = Native.package and Native.package.loaded["core.ScriptLoader"]
	if not scriptLoader then
		return nil
	end
	local ok, value = pcall(scriptLoader.getGlobal, "necro.client.KeyRebinder", name)
	return ok and value or nil
end

event.tick.add("cryptAccessRebind", { order = "menu", sequence = 14 }, function()
	local ok, open = pcall(KeyRebinder.isOpen)
	open = ok and open and true or false
	if open and not wasOpen then
		Keys.setEnabled(false)
		local lines = { Text.clean(global("currentLabel") or "") }
		local sub = global("currentSubLabel")
		if type(sub) == "table" then
			for _, line in ipairs(sub) do
				lines[#lines + 1] = Text.clean(line)
			end
		end
		Speech.say(Text.sentences(lines), true)
	elseif not open and wasOpen then
		Keys.setEnabled(true)
	end
	wasOpen = open
end)

return {}
