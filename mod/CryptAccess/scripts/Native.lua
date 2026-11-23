-- The only door out of the mod sandbox. Needs "core.StandardLibrary" in the scriptWhitelist of
-- Necrodancer64/config.json (the installer adds it). Every other script gets ffi/io/os from here.
-- Members are never nil: reading a missing member of another module throws in Synchrony.

local Native = {
	available = false,
	error = false,
	ffi = false,
	io = false,
	os = false,
	package = false,
	require = false,
	lib = false,
	diagnostics = "",
}

local diag = {}

local ok, standardLibrary = pcall(require, "core.StandardLibrary")

if ok and type(standardLibrary) == "table" then
	Native.lib = standardLibrary
	Native.io = standardLibrary.io or false
	Native.os = standardLibrary.os or false
	Native.package = standardLibrary.package or false
	Native.require = standardLibrary.require or false
	Native.ffi = standardLibrary.ffi or false

	-- The engine never registers LuaJIT's ffi module, but lua51.dll exports luaopen_ffi.
	-- Open it once per Lua state and cache it in package.loaded (opening it twice would reset ffi's state).
	local package = Native.package
	if not Native.ffi and package then
		local loaded = package.loaded
		if type(loaded.ffi) == "table" then
			Native.ffi = loaded.ffi
		else
			local opener, err = package.loadlib("lua51.dll", "luaopen_ffi")
			if opener then
				local okOpen, ffiOrErr = pcall(opener)
				if okOpen and type(ffiOrErr) == "table" then
					loaded.ffi = ffiOrErr
					Native.ffi = ffiOrErr
					diag[#diag + 1] = "ffi opened from lua51.dll"
				else
					diag[#diag + 1] = "luaopen_ffi failed: " .. tostring(ffiOrErr)
				end
			else
				diag[#diag + 1] = "package.loadlib(lua51.dll, luaopen_ffi) failed: " .. tostring(err)
			end
		end
	end
	Native.available = Native.ffi ~= false
else
	Native.error = tostring(standardLibrary)
	diag[#diag + 1] = "core.StandardLibrary not available: " .. Native.error
end

Native.diagnostics = table.concat(diag, "; ")
log.info("Native: %s", Native.diagnostics)

--- Exports of any loaded engine script, including ones the sandbox refuses (necro.mod.*, core.*).
--- Reads ScriptLoader's private loadedScripts table through debug.getupvalue. Returns nil if not loaded.
function Native.engineModule(name)
	local package, lib = Native.package, Native.lib
	local scriptLoader = package and package.loaded["core.ScriptLoader"]
	if type(scriptLoader) ~= "table" or not lib or not lib.debug then
		return nil
	end
	local i = 1
	while true do
		local upName, value = lib.debug.getupvalue(scriptLoader.loadScript, i)
		if not upName then
			return nil
		end
		if upName == "loadedScripts" then
			local entry = value[name]
			return entry and entry.exports or nil
		end
		i = i + 1
	end
end

-- Absolute folder of this mod. The game keeps unpacked mods in %LOCALAPPDATA%\NecroDancer\mods.
function Native.modFolder()
	local base = Native.os and Native.os.getenv("LOCALAPPDATA")
	return base and (base .. "\\NecroDancer\\mods\\CryptAccess") or nil
end

return Native
