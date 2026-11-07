-- Fake game API for Core tests.

CORE_FILES = {
	"Core/Namespace.lua",
	"Core/Definitions.lua",
	"Core/CVarStore.lua",
	"Core/Experience.lua",
	"Core/Pending.lua",
	"Core/Profiles.lua",
	"Core/Preview.lua",
	"Core/Diagnostics.lua",
}

-- Values loosely shaped like a mid-range client. Defaults equal live.
local BASE = {
	graphicsViewDistance = 5, graphicsEnvironmentDetail = 5, graphicsGroundClutter = 5,
	groundEffectDensity = 40, groundEffectDist = 200, groundEffectFade = 160,
	lodObjectFadeScale = 100, lodObjectCullSize = 18, terrainLodDist = 400, horizonStart = 1600,
	ResampleAlwaysSharpen = 0, ResampleSharpness = 0.2, textureFilteringMode = 2,
	reflectionMode = 0, shadowNumCascades = 2, weatherDensity = 1,
	horizonClip = 5000, RAIDsettingsEnabled = 0, ResampleQuality = 2,
}

-- opts.missing / restricted / reject / error: sets of cvar names.
-- opts.clamp: cvar -> max value the client accepts.
-- opts.values: overrides. opts.experience: number or nil. opts.noGameRules.
function newCVars(opts)
	opts = opts or {}
	local store = {}
	for name, value in pairs(BASE) do
		store[name] = { value = tostring(value), default = tostring(value) }
	end
	for name, value in pairs(opts.values or {}) do
		store[name].value = tostring(value)
	end
	for name in pairs(opts.missing or {}) do
		store[name] = nil
	end

	local cvars = { writes = {}, store = store }

	local function raw(name, value)
		store[name].value = tostring(value)
	end

	function cvars.GetCVar(name)
		return store[name] and store[name].value or nil
	end
	function cvars.GetCVarDefault(name)
		return store[name] and store[name].default or nil
	end
	function cvars.GetCVarInfo(name)
		local entry = store[name]
		if not entry then
			return nil
		end
		local restricted = (opts.restricted or {})[name] or false
		return entry.value, entry.default, false, false, false, false, restricted
	end
	function cvars.SetCVar(name, value)
		table.insert(cvars.writes, { name = name, value = value })
		if (opts.error or {})[name] then
			error("simulated failure for " .. name)
		end
		if not store[name] or (opts.reject or {})[name] then
			return false
		end
		local n = tonumber(value)
		local cap = (opts.clamp or {})[name]
		if cap and n > cap then
			n = cap
		end
		raw(name, n)
		-- Quality parents rewrite their children, like the real client.
		if name == "graphicsGroundClutter" then
			raw("groundEffectDensity", 16 + n * 8)
			raw("groundEffectDist", 100 + n * 20)
		elseif name == "graphicsViewDistance" then
			raw("terrainLodDist", 300 + n * 20)
		end
		return true
	end
	-- Something outside GSM changing a value.
	function cvars.external(name, value)
		raw(name, value)
	end
	function cvars.value(name)
		return tonumber(store[name].value)
	end
	return cvars
end

function newAddon(opts)
	opts = opts or {}
	local env = {
		t = 100,
		combat = false,
		printed = {},
		db = {},
	}
	env.cvars = newCVars(opts)
	local ns = {}
	ns.api = {
		cvar = env.cvars,
		gameRules = (not opts.noGameRules) and {
			GetForeverExperiencePreset = function()
				if opts.experienceError then
					error("boom")
				end
				return env.experience
			end,
		} or nil,
		enum = { ForeverExperiencePreset = { Classic = 0, Enhanced = 1 } },
		clock = function() return env.t end,
		now = function() return 1700000000 end,
		inCombat = function() return env.combat end,
		buildInfo = function() return "1.60.1", "70790", "Nov 1 2026", 16001 end,
		db = function()
			env.db.profiles = env.db.profiles or {}
			env.db.ui = env.db.ui or {}
			return env.db
		end,
		print = function(msg) table.insert(env.printed, msg) end,
		reportError = function(err) error(err, 0) end,
	}
	env.experience = opts.experience
	for _, file in ipairs(opts.files or CORE_FILES) do
		local chunk = assert(loadfile(ROOT .. "/GraphicsSettingsManager/" .. file))
		chunk("GraphicsSettingsManager", ns)
	end
	return ns, env
end

function set(list)
	local out = {}
	for _, v in ipairs(list) do
		out[v] = true
	end
	return out
end
