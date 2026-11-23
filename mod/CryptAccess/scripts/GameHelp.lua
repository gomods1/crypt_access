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
		-- In the lobby, first say what the lobby is and how to get around it.
		local okLobby, lobby = pcall(require("necro.game.level.CurrentLevel").isLobby)
		if okLobby and lobby then
			lines[1] = Strings.get("event.lobbyIntro")
		end
		for i = 1, 14 do
			local line = Strings.maybe("help.game." .. i)
			if line then
				lines[#lines + 1] = line
			end
		end
		-- Multiplayer: O lists the players; chat is read aloud.
		lines[#lines + 1] = Strings.get("help.online")
		return lines
	end,
})

return {}
