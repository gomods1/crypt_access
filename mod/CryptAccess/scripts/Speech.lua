-- Screen reader output through Prism (prism.dll, loaded with LuaJIT ffi). The only script that touches Prism.
-- Every spoken line is also written to CryptAccess_speech.log in the mod folder (overwritten each launch).

local Native = require("CryptAccess.Native")
local Timer = require("system.utils.Timer")

local Speech = {}

local state = {
	lib = false,
	ctx = false,
	backend = false,
	backendName = "",
	features = 0,
	loadError = false,
	nextRetry = 0,
	logFile = false,
	lastSpoken = "",
}
-- Keep the native handles across live reloads of this script.
state = script.persist(function()
	return state
end)

local FEATURE_OUTPUT = 32 -- PRISM_BACKEND_SUPPORTS_OUTPUT (1 << 5)
local FEATURE_STOP = 128 -- PRISM_BACKEND_SUPPORTS_STOP (1 << 7)

local CDEF = [[
typedef struct PrismContext PrismContext;
typedef struct PrismBackend PrismBackend;
PrismContext *prism_init(void *cfg);
void prism_shutdown(PrismContext *ctx);
PrismBackend *prism_registry_create_best(PrismContext *ctx);
void prism_backend_free(PrismBackend *backend);
const char *prism_backend_name(PrismBackend *backend);
uint64_t prism_backend_get_features(PrismBackend *backend);
int prism_backend_speak(PrismBackend *backend, const char *text, bool interrupt);
int prism_backend_output(PrismBackend *backend, const char *text, bool interrupt);
int prism_backend_braille(PrismBackend *backend, const char *text);
int prism_backend_stop(PrismBackend *backend);
const char *prism_error_string(int error);
]]

local function writeLog(prefix, text)
	local io = Native.io
	if not io then
		return
	end
	if not state.logFile then
		local folder = Native.modFolder()
		if not folder then
			return
		end
		state.logFile = io.open(folder .. "\\CryptAccess_speech.log", "w") or false
		if not state.logFile then
			return
		end
	end
	local clock = Timer.getGlobalTime()
	state.logFile:write(string.format("[%9.3f] %s%s\n", clock, prefix, text))
	state.logFile:flush()
end

local function candidatePaths()
	local paths = {}
	local folder = Native.modFolder()
	if folder then
		paths[#paths + 1] = folder .. "\\lib\\prism.dll"
	end
	paths[#paths + 1] = "CryptAccess\\prism.dll" -- next to Necrodancer.exe (working directory)
	paths[#paths + 1] = "prism.dll"
	return paths
end

local function loadLibrary()
	if state.lib then
		return true
	end
	local ffi = Native.ffi
	if not ffi then
		state.loadError = "ffi unavailable: " .. tostring(Native.error)
		return false
	end
	pcall(ffi.cdef, CDEF) -- already defined after a live reload
	local errors = {}
	for _, path in ipairs(candidatePaths()) do
		local ok, lib = pcall(ffi.load, path)
		if ok then
			state.lib = lib
			writeLog("Loaded ", path)
			return true
		end
		errors[#errors + 1] = path .. ": " .. tostring(lib)
	end
	state.loadError = table.concat(errors, "; ")
	return false
end

local function releaseBackend()
	if state.backend and state.lib then
		pcall(state.lib.prism_backend_free, state.backend)
	end
	state.backend = false
end

local function ensureBackend()
	if state.backend then
		return true
	end
	local now = Timer.getGlobalTime()
	if now < state.nextRetry then
		return false
	end
	state.nextRetry = now + 3
	if not loadLibrary() then
		log.error("Prism not loaded: %s", tostring(state.loadError))
		writeLog("ERROR ", tostring(state.loadError))
		return false
	end
	local lib, ffi = state.lib, Native.ffi
	if not state.ctx then
		local ctx = lib.prism_init(nil)
		if ctx == nil then
			writeLog("ERROR ", "prism_init returned NULL")
			return false
		end
		state.ctx = ctx
	end
	local backend = lib.prism_registry_create_best(state.ctx)
	if backend == nil then
		writeLog("ERROR ", "no Prism backend available")
		return false
	end
	state.backend = backend
	state.backendName = ffi.string(lib.prism_backend_name(backend))
	state.features = tonumber(lib.prism_backend_get_features(backend)) or 0
	writeLog("Backend ", state.backendName)
	log.info("Prism backend: %s", state.backendName)
	return true
end

local function hasFeature(bit)
	return math.floor(state.features / bit) % 2 == 1
end

--- Speaks text. interrupt defaults to false (queue), per the project rules.
function Speech.say(text, interrupt)
	if type(text) ~= "string" or text == "" then
		return false
	end
	writeLog(interrupt and "Say! " or "Say  ", text)
	state.lastSpoken = text
	if not ensureBackend() then
		return false
	end
	local lib = state.lib
	local fn = hasFeature(FEATURE_OUTPUT) and lib.prism_backend_output or lib.prism_backend_speak
	local ok, result = pcall(fn, state.backend, text, interrupt and true or false)
	if not ok or result ~= 0 then
		local message = ok and Native.ffi.string(lib.prism_error_string(result)) or tostring(result)
		writeLog("ERROR ", "speak failed: " .. message)
		-- The screen reader may have been restarted: create the backend again on the next call.
		releaseBackend()
		state.nextRetry = 0
		return false
	end
	return true
end

function Speech.stop()
	if state.backend and hasFeature(FEATURE_STOP) then
		pcall(state.lib.prism_backend_stop, state.backend)
	end
end

--- The last line spoken (for the repeat key).
function Speech.last()
	return state.lastSpoken or ""
end

function Speech.backendName()
	return state.backendName
end

--- Writes a diagnostic line to the speech log without speaking it.
function Speech.debug(text)
	writeLog("Debug ", tostring(text))
end

return Speech
