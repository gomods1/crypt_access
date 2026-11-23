-- Online sessions carry only packaged mods: .necromod files in %LOCALAPPDATA%\NecroDancer\mods (the game's
-- "packaged" load path; see necro.mod.NetworkMods and Mods.lua updateRemoteModList). When you host, the
-- game swaps each unpacked mod for its package of the same name, and players who join load that same
-- package from their own mods folder.
-- The installers put the package inside the mod folder (package\CryptAccess-<version>.necromod). Once per
-- launch this script copies it next to the mod folder if it is missing or different, deletes Crypt
-- Access packages of other versions (an old one would be picked as the "latest" package), and refreshes
-- the game's list of available mods. Needs the native door (Native.io); a friend's game without the
-- installer's config.json change skips all of this.

local Native = require("CryptAccess.Native")

local Package = {}

local MOD_NAME = "CryptAccess"

local function readFile(path)
	local f = Native.io.open(path, "rb")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function writeFile(path, data)
	local f = Native.io.open(path, "wb")
	if not f then
		return false
	end
	f:write(data)
	f:close()
	return true
end

--- The version in the mod folder's mod.json, or nil.
function Package.modVersion()
	local folder = Native.modFolder()
	local json = folder and readFile(folder .. "\\mod.json")
	return json and json:match('"version"%s*:%s*"([^"]+)"') or nil
end

function Package.fileName(version)
	return string.format("%s-%s.necromod", MOD_NAME, version)
end

--- True when the package of this version is in the mods folder (nil when that cannot be checked).
function Package.isInstalled(version)
	local folder = Native.io and Native.modFolder()
	if not folder or not version then
		return nil
	end
	local f = Native.io.open(folder:match("^(.*)\\[^\\]+$") .. "\\" .. Package.fileName(version), "rb")
	if f then
		f:close()
		return true
	end
	return false
end

--- Copies the bundled package into the mods folder. Returns a short status for the log.
function Package.install()
	if not (Native.available and Native.io and Native.os) then
		return "no native access"
	end
	local folder = Native.modFolder()
	local version = Package.modVersion()
	if not folder or not version then
		return "no mod.json"
	end
	local name = Package.fileName(version)
	local data = readFile(folder .. "\\package\\" .. name)
	if not data or #data == 0 then
		return "no bundled package"
	end
	local modsDir = folder:match("^(.*)\\[^\\]+$")
	local target = modsDir .. "\\" .. name
	local changed = false
	if readFile(target) ~= data then
		if not writeFile(target, data) then
			return "cannot write " .. target
		end
		changed = true
	end
	local Mods = Native.engineModule("necro.mod.Mods")
	if type(Mods) == "table" then
		local ok, versions = pcall(Mods.listVersionsIncludeFiltered, MOD_NAME)
		if ok and type(versions) == "table" then
			for _, v in ipairs(versions) do
				-- Only our own packages in the mods folder; never mod.io downloads (basePath "downloaded").
				if v.package and v.basePath == "packaged" and v.version ~= version and type(v.path) == "string"
					and v.path:match("^" .. MOD_NAME .. "%-[^/\\]+%.necromod$") then
					Native.os.remove(modsDir .. "\\" .. v.path)
					changed = true
				end
			end
		end
		if changed then
			pcall(Mods.updateModList)
		end
	end
	return changed and ("installed " .. name) or ("up to date " .. name)
end

local function once()
	local loaded = Native.package and Native.package.loaded
	if not loaded or loaded["CryptAccess.packageChecked"] then
		return
	end
	local ok, status = pcall(Package.install)
	log.info("Package: %s", tostring(ok and status or ("failed: " .. tostring(status))))
	-- The first mount at startup cannot reach necro.mod.Mods yet (see NOTEBOOK), so the clean-up of old
	-- versions and the refresh wait for the second mount; the copy itself is done on the first.
	if type(Native.engineModule("necro.mod.Mods")) == "table" then
		loaded["CryptAccess.packageChecked"] = true
	end
end

once()

return Package
