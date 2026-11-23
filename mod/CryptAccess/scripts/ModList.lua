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
	for _, entry in ipairs(list) do
		if type(entry) == "table" and entry.name == MOD_NAME then
			if entry.version == nil and version then
				entry.version = version
				entry.package = packaged or false
				log.info("ModList: set version %s on the existing entry", tostring(version))
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

-- Run at load time: the game's second loadMods happens in a later cycle and reads this list.
ModList.ensureRegistered()

return ModList
