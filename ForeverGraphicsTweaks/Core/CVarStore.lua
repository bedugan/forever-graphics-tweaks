-- Reads, classifies, and writes CVars. Every write is checked by reading back.
local _, ns = ...

local Store = {}
ns.CVarStore = Store

local function near(a, b)
	return math.abs(a - b) <= 1e-4 * math.max(1, math.abs(b))
end
Store.near = near

-- "available", "missing", or "restricted".
function Store.status(cvar)
	local api = ns.api.cvar
	if not (api and api.GetCVarInfo) then
		return "missing"
	end
	local ok, value, _, _, _, locked, secure, readOnly = pcall(api.GetCVarInfo, cvar)
	if not ok or value == nil then
		return "missing"
	end
	if locked or secure or readOnly then
		return "restricted"
	end
	return "available"
end

function Store.get(cvar)
	local ok, value = pcall(ns.api.cvar.GetCVar, cvar)
	return ok and tonumber(value) or nil
end

function Store.default(cvar)
	local ok, value = pcall(ns.api.cvar.GetCVarDefault, cvar)
	return ok and tonumber(value) or nil
end

-- Live values for every available managed setting.
function Store.readAll()
	local values = {}
	for _, setting in ipairs(ns.Settings) do
		if Store.status(setting.cvar) == "available" then
			values[setting.cvar] = Store.get(setting.cvar)
		end
	end
	return values
end

-- Returns result, actual, message.
-- result: "ok" | "clamped" (stored a different value) | "rejected" (unchanged) | "error".
function Store.set(cvar, value)
	local before = Store.get(cvar)
	local ok, err = pcall(ns.api.cvar.SetCVar, cvar, tostring(value))
	local actual = Store.get(cvar)
	if not ok then
		return "error", actual, tostring(err)
	end
	if actual == nil then
		return "error", nil, "value unreadable after write"
	end
	if near(actual, value) then
		return "ok", actual
	end
	if before ~= nil and near(actual, before) then
		return "rejected", actual
	end
	return "clamped", actual
end

local function byTier(a, b)
	local sa, sb = ns.SettingsByKey[a.cvar], ns.SettingsByKey[b.cvar]
	if sa.tier ~= sb.tier then
		return sa.tier < sb.tier
	end
	return sa.order < sb.order
end

function Store.sortByTier(list)
	table.sort(list, byTier)
	return list
end

-- Writes target values (cvar -> number) where they differ from `current`,
-- tier 1 first. Skips any cvar not in `allowed` when that set is given.
-- Returns the list of write records { cvar, requested, result, actual, message }.
local function writeValues(targets, allowed)
	local list = {}
	for cvar, value in pairs(targets) do
		if allowed == nil or allowed[cvar] then
			table.insert(list, { cvar = cvar, requested = value })
		end
	end
	Store.sortByTier(list)
	local records = {}
	for _, item in ipairs(list) do
		local live = Store.get(item.cvar)
		if live == nil or not near(live, item.requested) then
			local result, actual, message = Store.set(item.cvar, item.requested)
			table.insert(records, {
				cvar = item.cvar, requested = item.requested,
				result = result, actual = actual, message = message,
			})
		end
	end
	return records
end
Store.writeValues = writeValues

-- Applies changes as one unit. On any error or rejection, puts every
-- managed value back to `snapshot` and reports failure.
-- changes: list of { cvar, value }. snapshot: cvar -> number.
-- Returns ok, records, failedRecord, rollbackRecords.
function Store.transaction(changes, snapshot)
	local list = {}
	for _, change in ipairs(changes) do
		table.insert(list, { cvar = change.cvar, value = change.value })
	end
	Store.sortByTier(list)

	local records = {}
	for _, item in ipairs(list) do
		local result, actual, message = Store.set(item.cvar, item.value)
		local record = {
			cvar = item.cvar, requested = item.value,
			result = result, actual = actual, message = message,
		}
		table.insert(records, record)
		if result == "error" or result == "rejected" then
			local rollback = writeValues(snapshot)
			return false, records, record, rollback
		end
	end
	return true, records
end
