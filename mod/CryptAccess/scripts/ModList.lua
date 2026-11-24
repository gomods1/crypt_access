-- Keeps Crypt Access in the game's own mod list (setting "modLoader.list", global targetModList of
-- necro.mod.Mods). config.json's preload only loads the mod at startup; a moment later the game
-- re-applies targetModList, which would unload us. Each entry needs name, version and package: a
-- session start resolves mods by version, and an entry without one shows "missing mods".

local Native = require("CryptAccess.Native")

local ModList = {}

local MOD_NAME = "CryptAccess"

local function latestVersion(scriptLoader)
	local okMods, modsModule = pcall(Native.engineModule, "necro.mod.Mods")
	if okMods and type(modsModule) == "table" then
		local ok, version = pcall(modsModule.getLatestVersion, MOD_NAME, false)
		if ok and type(version) == "table" then
			return version.version, version.package
		end
	end
	return nil
end

function ModList.ensureRegistered()
	local package = Native.package
	local scriptLoader = package and package.loaded and package.loaded["core.ScriptLoader"]
	if type(scriptLoader) ~= "table" then
		log.warn("ModList: core.ScriptLoader not reachable")
		return false
	end
	local ok, list = pcall(scriptLoader.getGlobal, "necro.mod.Mods", "targetModList")
	if not ok or type(list) ~= "table" then
		log.warn("ModList: targetModList unavailable: %s", tostring(list))
		return false
	end
	local version, packaged = latestVersion(scriptLoader)
	-- The installed version is the one in the mod folder's mod.json. After an update the saved entry still
	-- names the old version, and the game's startup (Mods.unloadInvalidVersions) would unload the mod for
	-- that; correct it now, while the mod is preloaded. The unpacked folder always exists, so point there;
	-- hosting switches to the package by itself.
	local okInstalled, installed = pcall(function()
		return require("CryptAccess.Package").modVersion()
	end)
	installed = okInstalled and installed or nil
	if installed then
		version, packaged = installed, false
	end
	for _, entry in ipairs(list) do
		if type(entry) == "table" and entry.name == MOD_NAME then
			if (entry.version == nil or (installed and entry.version ~= installed)) and version then
				log.info("ModList: entry version %s -> %s", tostring(entry.version), tostring(version))
				entry.version = version
				entry.package = packaged or false
			elseif entry.package and installed then
				-- Loaded as a package (after hosting): fall back to the folder if the package file is gone.
				local okFile, present = pcall(function()
					return require("CryptAccess.Package").isInstalled(installed)
				end)
				if okFile and present == false then
					log.info("ModList: package %s missing, using the mod folder", tostring(installed))
					entry.package = false
				end
			end
			return true
		end
	end
	table.insert(list, { name = MOD_NAME, version = version, package = packaged or false })
	local okSet, set = pcall(scriptLoader.getGlobal, "necro.mod.Mods", "targetModSet")
	if okSet and type(set) == "table" then
		set[MOD_NAME] = true
	end
	log.info("ModList: added %s %s to the game's mod list", MOD_NAME, tostring(version))
	return true
end

-- At preload necro.mod.Mods is not loaded yet ("unloaded script"), so the load-time call fails and only a
-- saved entry kept the mod loaded. event.startup is protected (necro/event/Event.lua), but the first tick
-- runs in the same frame right after startup, and the frame runs "tick" before "modLoader", whose
-- loadLocalMods applies the list (system/game/Cycle.lua, necro/cycles/Tick.lua, necro/mod/Mods.lua).
local registered = ModList.ensureRegistered()
local attempts = 0

event.tick.add("cryptAccessModList", { order = "config", sequence = -10 }, function()
	if registered or attempts >= 10 then
		return
	end
	attempts = attempts + 1
	registered = ModList.ensureRegistered()
	if registered then
		log.info("ModList: registered on the first tick")
	end
end)

return ModList
