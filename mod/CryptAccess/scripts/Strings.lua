-- The mod's own strings, one table per language. Follows the game's language
-- (necro.config.i18n.Translation.getSessionTranslation). Missing keys fall back to English and log once.
-- Placeholders are {name}; never build sentences from fragments in code.

local Translation = require("necro.config.i18n.Translation")

local Strings = {}

local tables = {
	en = require("CryptAccess.LangEN"),
	es = require("CryptAccess.LangES"),
	de = require("CryptAccess.LangDE"),
	fr = require("CryptAccess.LangFR"),
	it = require("CryptAccess.LangIT"),
	pt_BR = require("CryptAccess.LangPTBR"),
	ru = require("CryptAccess.LangRU"),
	ja = require("CryptAccess.LangJA"),
	ko = require("CryptAccess.LangKO"),
	zh_CN = require("CryptAccess.LangZHCN"),
	zh_TW = require("CryptAccess.LangZHTW"),
}
Strings.tables = tables

local warned = {}

--- Registers (or extends) a language table. Language codes follow the game: "en", "es", "de", "fr",
--- "it", "ja", "ko", "pt_BR", "ru", "zh_CN", "zh_TW".
function Strings.add(lang, entries)
	local t = tables[lang] or {}
	tables[lang] = t
	for k, v in pairs(entries) do
		t[k] = v
	end
end

local langCache, langCacheTime = "en", -1

local function mapGameLanguage(code)
	if type(code) ~= "string" or code == "" then
		return "en"
	end
	if tables[code] then
		return code
	end
	local short = code:match("^(%a%a)")
	if short and tables[short] then
		return short
	end
	return "en"
end

function Strings.language()
	local ok, code = pcall(Translation.getSessionTranslation)
	return mapGameLanguage(ok and code or nil)
end

--- Module tables throw on a missing member, so every read is guarded.
local function get(t, key)
	if not t then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	return ok and value or nil
end

local function lookup(key)
	local lang = Strings.language()
	local t = tables[lang]
	local value = get(t, key)
	if value == nil then
		if lang ~= "en" and not warned[lang .. key] then
			warned[lang .. key] = true
			log.warn("Strings: missing %s in %s", key, lang)
		end
		value = get(tables.en, key)
	end
	return value
end

--- Returns the string for key, with {placeholders} replaced from params.
function Strings.get(key, params)
	local value = lookup(key)
	if value == nil then
		return key
	end
	if params then
		value = value:gsub("{([%w_]+)}", function(name)
			local p = params[name]
			if p == nil then
				return "{" .. name .. "}"
			end
			return tostring(p)
		end)
	end
	return value
end

--- Like get, but returns nil when the key does not exist in any table.
function Strings.maybe(key, params)
	if lookup(key) == nil then
		return nil
	end
	return Strings.get(key, params)
end

--- Joins parts with the language's list separator.
function Strings.join(parts)
	return table.concat(parts, Strings.get("sep.list"))
end

return Strings
