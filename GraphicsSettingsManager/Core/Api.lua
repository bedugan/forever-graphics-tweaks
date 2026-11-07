-- Public API for companion addons, such as the capture tool. Small on
-- purpose: read the definitions and live values, and make or undo one
-- change with GSM's own write, read-back, and baseline rules.
-- Treat every returned table as read-only.
local _, ns = ...

local Store = ns.CVarStore

local function blocked()
	if ns.Preview.isActive() then
		return "Finish the current GSM test first."
	end
	if ns.api.inCombat() then
		return "Not available in combat."
	end
	return nil
end

-- True if `value` breaks the lessThan or atMost rule of `setting` against `limit`.
local function breaks(setting, value, limit)
	return (setting.lessThan and value >= limit) or (setting.atMost and value > limit)
end

-- Checks the setting's own limit and every setting whose limit it is,
-- against live values.
local function limitError(setting, value)
	local other = setting.lessThan or setting.atMost
	local limit = other and Store.get(other)
	if limit and breaks(setting, value, limit) then
		local partner = ns.SettingsByKey[other]
		return string.format("%s %s is over the limit set by %s (%s).",
			setting.label, tostring(value), partner and partner.label or other, tostring(limit))
	end
	for _, dependent in ipairs(ns.Settings) do
		local live = (dependent.lessThan or dependent.atMost) == setting.cvar and Store.get(dependent.cvar)
		if live and breaks(dependent, live, value) then
			return string.format("%s %s is under %s (%s).",
				setting.label, tostring(value), dependent.label, tostring(live))
		end
	end
	return nil
end

local API = {
	version = ns.version,
	settings = ns.Settings,
	settingsByKey = ns.SettingsByKey,
	levels = ns.Levels.order,
	levelLabels = ns.Levels.labels,
	levelValue = ns.Levels.value,
	status = Store.status,
	get = Store.get,
	default = Store.default,
	snapshot = Store.readAll,
	blocked = blocked,
}

-- Writes one setting as a transaction, after capturing the baseline so
-- Restore Original still works. Returns ok, record or message.
-- record: { cvar, requested, result, actual }. result "ok" or "clamped".
function API.set(cvar, value)
	local reason = blocked()
	if reason then
		return false, reason
	end
	local setting = ns.SettingsByKey[cvar]
	if not setting then
		return false, "Unknown setting " .. tostring(cvar) .. "."
	end
	if Store.status(cvar) ~= "available" then
		return false, setting.label .. " is " .. Store.status(cvar) .. " on this client."
	end
	if type(value) ~= "number" or value < setting.min or value > setting.max then
		return false, setting.label .. " value " .. tostring(value) .. " is out of range."
	end
	local limit = limitError(setting, value)
	if limit then
		return false, limit
	end
	ns.Profiles.ensureBaseline()
	local ok, records, failed = Store.transaction({ { cvar = cvar, value = value } }, Store.readAll())
	if not ok then
		return false, setting.label .. " was " .. failed.result .. " by the game."
	end
	return true, records[1] or { cvar = cvar, requested = value, result = "ok", actual = Store.get(cvar) }
end

-- Puts values back, quality-level parents first, skipping values already
-- live. Returns the records that did not land exactly, clamped included.
function API.restore(snapshot)
	local failed = {}
	for _, record in ipairs(Store.writeValues(snapshot)) do
		if record.result ~= "ok" then
			table.insert(failed, record)
		end
	end
	return failed
end

ns.API = API
GraphicsSettingsManagerAPI = API
