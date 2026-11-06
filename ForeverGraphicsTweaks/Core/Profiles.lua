-- Baseline (the player's settings before FGT's first write), Restore
-- Original, and named profiles. Profiles only fill pending values.
local _, ns = ...

local Store = ns.CVarStore
local Profiles = {}
ns.Profiles = Profiles

Profiles.MAX_NAME = 40

local function trim(name)
	return (tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Called just before any write. Captures live values once, and adds
-- settings that are new since the baseline was taken.
function Profiles.ensureBaseline()
	local db = ns.api.db()
	if not db.baseline then
		db.baseline = { values = {}, captured = ns.api.now() }
	end
	for cvar, value in pairs(Store.readAll()) do
		if db.baseline.values[cvar] == nil then
			db.baseline.values[cvar] = value
		end
	end
end

function Profiles.baseline()
	return ns.api.db().baseline
end

local function blocked()
	if ns.Preview.isActive() then
		return "Finish the current test first."
	end
	if ns.api.inCombat() then
		return "Not available in combat."
	end
	return nil
end

-- Makes the current live values the new baseline.
function Profiles.resetBaseline()
	local reason = blocked()
	if reason then
		return false, reason
	end
	ns.api.db().baseline = { values = Store.readAll(), captured = ns.api.now() }
	return true
end

-- Writes the baseline back. No countdown; the UI asks for confirmation.
-- Returns ok, message, records.
function Profiles.restoreOriginal()
	local reason = blocked()
	if reason then
		return false, reason
	end
	local baseline = Profiles.baseline()
	if not baseline then
		return false, "Nothing to restore. FGT has not changed any settings yet."
	end
	local changes = {}
	for cvar, value in pairs(baseline.values) do
		if ns.SettingsByKey[cvar] and Store.status(cvar) == "available" then
			local live = Store.get(cvar)
			if live == nil or not Store.near(live, value) then
				table.insert(changes, { cvar = cvar, value = value })
			end
		end
	end
	if #changes == 0 then
		return true, "Settings already match the original values.", {}
	end
	local ok, records, failed = Store.transaction(changes, Store.readAll())
	if not ok then
		return false, ns.SettingsByKey[failed.cvar].label .. " could not be restored. Nothing was changed.", records
	end
	ns.Pending.clear()
	return true, "Original settings restored.", records
end

function Profiles.validName(name)
	name = trim(name)
	if name == "" then
		return nil, "Enter a profile name."
	end
	if #name > Profiles.MAX_NAME then
		return nil, "Profile names can be up to " .. Profiles.MAX_NAME .. " characters."
	end
	return name
end

function Profiles.exists(name)
	return ns.api.db().profiles[trim(name)] ~= nil
end

-- Saves the effective values (pending where set, otherwise live).
function Profiles.save(name)
	local valid, err = Profiles.validName(name)
	if not valid then
		return false, err
	end
	ns.api.db().profiles[valid] = { values = ns.Pending.effectiveAll(), saved = ns.api.now() }
	ns.emit("PROFILES_CHANGED")
	return true, "Saved profile " .. valid .. "."
end

function Profiles.load(name)
	local profile = ns.api.db().profiles[name]
	if not profile then
		return false, "No profile named " .. tostring(name) .. "."
	end
	ns.Pending.load(profile.values or {})
	return true, "Loaded " .. name .. " into pending values. Test them to see the result."
end

function Profiles.delete(name)
	ns.api.db().profiles[name] = nil
	ns.emit("PROFILES_CHANGED")
end

function Profiles.list()
	local names = {}
	for name in pairs(ns.api.db().profiles) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end
