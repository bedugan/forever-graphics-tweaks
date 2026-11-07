-- Read-only report for /gsm diag. Never writes a CVar.
local _, ns = ...

local Store = ns.CVarStore
local Diagnostics = {}
ns.Diagnostics = Diagnostics

local function yesno(value)
	return value and "yes" or "no"
end

function Diagnostics.lines()
	local api = ns.api
	local lines = {}
	local function add(fmt, ...)
		table.insert(lines, string.format(fmt, ...))
	end

	local version, build, _, toc = "?", "?", nil, nil
	if api.buildInfo then
		version, build, _, toc = api.buildInfo()
	end
	add("Graphics Settings Manager %s", ns.version)
	add("Client %s (%s), interface %s, addon expects %d", tostring(version), tostring(build), tostring(toc), ns.interface)

	local foreverApi = api.gameRules and api.gameRules.GetForeverExperiencePreset ~= nil
	add("Forever experience API: %s", yesno(foreverApi))
	local experience, reason = ns.Experience.detect()
	add("Experience preset: %s%s", experience, reason and (" (" .. reason .. ")") or "")
	add("C_CVar: %s", yesno(api.cvar and api.cvar.GetCVarInfo and api.cvar.SetCVar))

	for _, cvar in ipairs(ns.WatchedCVars) do
		add("%s = %s", cvar, tostring(Store.get(cvar)))
	end
	if Store.get("RAIDsettingsEnabled") == 1 then
		add("Raid graphics settings are on. GSM does not manage the raid copies.")
	end

	local counts = { available = 0, missing = 0, restricted = 0 }
	for _, setting in ipairs(ns.Settings) do
		local status = Store.status(setting.cvar)
		counts[status] = counts[status] + 1
		add("  %s: %s, live %s, default %s", setting.cvar, status,
			tostring(Store.get(setting.cvar)), tostring(Store.default(setting.cvar)))
	end
	add("Settings: %d available, %d missing, %d restricted", counts.available, counts.missing, counts.restricted)

	local db = api.db()
	add("SavedVariables loads: %s (stays at 1 after /reload if persistence is broken)", tostring(db.loads))
	add("Baseline captured: %s", yesno(db.baseline))
	add("Profiles: %d", #ns.Profiles.list())
	add("Test running: %s", yesno(ns.Preview.isActive()))
	add("Pending changes: %d", ns.Pending.count())
	return lines
end
