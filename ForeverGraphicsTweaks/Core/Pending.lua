-- Pending values: what the user picked but has not applied. Nothing here
-- writes a CVar. Entries only exist where the pending value differs from live.
local _, ns = ...

local Store = ns.CVarStore
local Pending = {}
ns.Pending = Pending

local values = {}
local lastCustom -- manual edits saved when a preset replaced them

local function copy(map)
	local out = {}
	for k, v in pairs(map) do
		out[k] = v
	end
	return out
end

local function isEmpty(map)
	return next(map) == nil
end

function Pending.normalize(setting, value)
	value = tonumber(value)
	if value == nil then
		return nil
	end
	value = math.max(setting.min, math.min(setting.max, value))
	local steps = math.floor((value - setting.min) / setting.step + 0.5)
	return tonumber(string.format("%.4f", setting.min + steps * setting.step))
end

-- Stores value without notifying. Returns true if stored.
local function put(cvar, value)
	local setting = ns.SettingsByKey[cvar]
	if not setting then
		return false
	end
	value = Pending.normalize(setting, value)
	if value == nil then
		return false
	end
	local live = Store.get(cvar)
	if live ~= nil and Store.near(live, value) then
		values[cvar] = nil
	else
		values[cvar] = value
	end
	return true
end

function Pending.get(cvar)
	return values[cvar]
end

function Pending.effective(cvar)
	local value = values[cvar]
	if value ~= nil then
		return value
	end
	return Store.get(cvar)
end

-- Effective values for every available setting. Used to save profiles.
function Pending.effectiveAll()
	local out = {}
	for _, setting in ipairs(ns.Settings) do
		if Store.status(setting.cvar) == "available" then
			out[setting.cvar] = Pending.effective(setting.cvar)
		end
	end
	return out
end

function Pending.set(cvar, value)
	if put(cvar, value) then
		ns.emit("PENDING_CHANGED")
	end
end

function Pending.clear()
	values = {}
	ns.emit("PENDING_CHANGED")
end

-- Replaces all pending values with `map` (cvar -> number). Unknown or
-- unavailable settings are ignored.
function Pending.load(map)
	values = {}
	for cvar, value in pairs(map) do
		if Store.status(cvar) == "available" then
			put(cvar, value)
		end
	end
	ns.emit("PENDING_CHANGED")
end

function Pending.count()
	local n = 0
	for _ in pairs(values) do
		n = n + 1
	end
	return n
end

-- Target value of a preset for one setting, or nil for "leave unchanged".
function Pending.presetValue(setting, presetKey)
	if presetKey == "default" then
		return Store.default(setting.cvar)
	end
	return setting.presets[presetKey]
end

local function matches(presetKey)
	for _, setting in ipairs(ns.Settings) do
		if Store.status(setting.cvar) == "available" then
			local target = Pending.presetValue(setting, presetKey)
			if target == nil then
				if values[setting.cvar] ~= nil then
					return false
				end
			else
				local effective = Pending.effective(setting.cvar)
				local normalized = Pending.normalize(setting, target)
				if effective == nil or not Store.near(effective, normalized) then
					return false
				end
			end
		end
	end
	return true
end

-- "default" | "balanced" | "ultra" | "custom".
function Pending.activePreset()
	for _, key in ipairs({ "default", "balanced", "ultra" }) do
		if matches(key) then
			return key
		end
	end
	return "custom"
end

function Pending.hasCustom()
	return lastCustom ~= nil
end

-- Fills pending values from a preset. "custom" brings back the manual edits
-- that the last preset choice replaced.
function Pending.applyPreset(presetKey)
	if presetKey == "custom" then
		if lastCustom then
			Pending.load(lastCustom)
		end
		return
	end
	if not isEmpty(values) and Pending.activePreset() == "custom" then
		lastCustom = copy(values)
	end
	values = {}
	for _, setting in ipairs(ns.Settings) do
		if Store.status(setting.cvar) == "available" then
			local target = Pending.presetValue(setting, presetKey)
			if target ~= nil then
				put(setting.cvar, target)
			end
		end
	end
	ns.emit("PENDING_CHANGED")
end

-- Pending entries that differ from live, as { cvar, value } in apply order.
function Pending.changes()
	local list = {}
	for cvar, value in pairs(values) do
		local live = Store.get(cvar)
		if live == nil or not Store.near(live, value) then
			table.insert(list, { cvar = cvar, value = value })
		end
	end
	return Store.sortByTier(list)
end

local function constraintError(setting, changing)
	local other = setting.lessThan or setting.atMost
	if not other then
		return nil
	end
	if not (changing[setting.cvar] or changing[other]) then
		return nil
	end
	local value = Pending.effective(setting.cvar)
	local limit = ns.SettingsByKey[other] and Pending.effective(other) or Store.get(other)
	if value == nil or limit == nil then
		return nil
	end
	local otherLabel = ns.SettingsByKey[other] and ns.SettingsByKey[other].label or other
	if setting.lessThan and value >= limit then
		return string.format("%s (%s) must be below %s (%s).", setting.label, value, otherLabel, limit)
	end
	if setting.atMost and value > limit then
		return string.format("%s (%s) must not exceed %s (%s).", setting.label, value, otherLabel, limit)
	end
	return nil
end

-- Returns ok, errors. Checks every change before anything is written.
function Pending.validate(changes)
	local errors = {}
	local changing = {}
	for _, change in ipairs(changes) do
		changing[change.cvar] = true
		local setting = ns.SettingsByKey[change.cvar]
		local status = setting and Store.status(change.cvar)
		if not setting then
			table.insert(errors, "Unknown setting " .. tostring(change.cvar) .. ".")
		elseif status ~= "available" then
			table.insert(errors, setting.label .. " is " .. status .. " on this client.")
		elseif not setting.previewable then
			table.insert(errors, setting.label .. " cannot be tested with the timer.")
		elseif type(change.value) ~= "number" or change.value < setting.min or change.value > setting.max then
			table.insert(errors, setting.label .. " value " .. tostring(change.value) .. " is out of range.")
		end
	end
	for _, setting in ipairs(ns.Settings) do
		local err = constraintError(setting, changing)
		if err then
			table.insert(errors, err)
		end
	end
	return #errors == 0, errors
end
