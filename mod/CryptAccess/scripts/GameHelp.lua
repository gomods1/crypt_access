-- F1 help while playing (dungeon, lobby, tutorial, training).

local Help = require("CryptAccess.Help")
local Strings = require("CryptAccess.Strings")
local World = require("CryptAccess.World")

Help.register({
	id = "game",
	priority = 10,
	active = World.inLevel,
	lines = function()
		local lines = {}
		for i = 1, 14 do
			local line = Strings.maybe("help.game." .. i)
			if line then
				lines[#lines + 1] = line
			end
		end
		return lines
	end,
})

return {}
