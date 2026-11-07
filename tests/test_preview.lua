local function liveMap(ns)
	return ns.CVarStore.readAll()
end

local function same(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false, k
		end
	end
	return true
end

test("start applies, reads back, and arms a 15 second deadline", function()
	local ns, env = newAddon()
	ns.Pending.applyPreset("balanced")
	local ok = ns.Preview.start()
	truthy(ok)
	truthy(ns.Preview.isActive())
	eq(env.cvars.value("groundEffectDensity"), 64)
	eq(ns.Preview.remaining(), 15)
end)

test("countdown uses elapsed clock time, not ticks", function()
	local ns, env = newAddon()
	ns.Pending.set("textureFilteringMode", 5)
	ns.Preview.start()
	for _ = 1, 1000 do
		ns.Preview.tick()
	end
	truthy(ns.Preview.isActive(), "many frames with no time passing do not end the test")
	env.t = env.t + 14.9
	ns.Preview.tick()
	truthy(ns.Preview.isActive())
	env.t = env.t + 0.2
	ns.Preview.tick()
	eq(ns.Preview.isActive(), false)
end)

test("timeout reverts to the exact snapshot", function()
	local ns, env = newAddon()
	local before = liveMap(ns)
	ns.Pending.applyPreset("ultra")
	ns.Preview.start()
	env.t = env.t + 16
	ns.Preview.tick()
	local ok, key = same(before, liveMap(ns))
	truthy(ok, "differs at " .. tostring(key))
end)

test("manual revert restores snapshot and keeps pending edits", function()
	local ns = newAddon()
	local before = liveMap(ns)
	ns.Pending.applyPreset("ultra")
	local pendingBefore = ns.Pending.count()
	ns.Preview.start()
	ns.Preview.revert("manual")
	truthy((same(before, liveMap(ns))))
	eq(ns.Pending.count(), pendingBefore)
end)

test("revert restores children rewritten by a quality parent", function()
	local ns, env = newAddon({ values = { groundEffectDensity = 72 } })
	ns.Pending.set("graphicsGroundClutter", 9)
	ns.Preview.start()
	truthy(env.cvars.value("groundEffectDensity") ~= 72, "parent rewrote child")
	ns.Preview.revert("manual")
	eq(env.cvars.value("graphicsGroundClutter"), 5)
	eq(env.cvars.value("groundEffectDensity"), 72)
end)

test("keep commits and clears pending, with no later revert", function()
	local ns, env = newAddon()
	ns.Pending.set("textureFilteringMode", 5)
	ns.Preview.start()
	ns.Preview.keep()
	env.t = env.t + 60
	ns.Preview.tick()
	eq(env.cvars.value("textureFilteringMode"), 5)
	eq(ns.Pending.count(), 0)
end)

test("partial apply failure rolls back and never starts the countdown", function()
	local ns, env = newAddon({ error = set({ "weatherDensity" }) })
	local before = liveMap(ns)
	ns.Pending.applyPreset("ultra")
	local ok, message = ns.Preview.start()
	eq(ok, false)
	truthy(message:find("Weather density"), message)
	eq(ns.Preview.isActive(), false)
	truthy((same(before, liveMap(ns))))
end)

test("rejected write is treated as a failure", function()
	local ns = newAddon({ reject = set({ "reflectionMode" }) })
	local before = liveMap(ns)
	ns.Pending.applyPreset("ultra")
	eq((ns.Preview.start()), false)
	truthy((same(before, liveMap(ns))))
end)

test("clamped write is accepted and reported", function()
	local ns, env = newAddon({ clamp = { terrainLodDist = 800 } })
	local started
	ns.on("PREVIEW_STARTED", function(records) started = records end)
	ns.Pending.applyPreset("ultra")
	truthy((ns.Preview.start()))
	local found
	for _, record in ipairs(started) do
		if record.cvar == "terrainLodDist" then
			found = record
		end
	end
	eq(found.result, "clamped")
	eq(found.actual, 800)
end)

test("revert skips settings changed by something else during the test", function()
	local ns, env = newAddon()
	ns.Pending.applyPreset("ultra")
	ns.Preview.start()
	env.cvars.external("weatherDensity", 2)
	local _, _, skipped = ns.Preview.revert("manual")
	contains(skipped, "weatherDensity")
	eq(env.cvars.value("weatherDensity"), 2)
	eq(env.cvars.value("reflectionMode"), 0, "others still revert")
end)

test("start is refused in combat, when idle of changes, and while running", function()
	local ns, env = newAddon()
	eq((ns.Preview.start()), false, "no changes")
	ns.Pending.set("textureFilteringMode", 5)
	env.combat = true
	eq((ns.Preview.start()), false, "combat")
	eq(#env.cvars.writes, 0)
	env.combat = false
	truthy((ns.Preview.start()))
	eq((ns.Preview.start()), false, "already running")
end)

test("timeout still reverts during combat", function()
	local ns, env = newAddon()
	ns.Pending.set("textureFilteringMode", 5)
	ns.Preview.start()
	env.combat = true
	env.t = env.t + 20
	ns.Preview.tick()
	eq(env.cvars.value("textureFilteringMode"), 2)
end)

test("invalid values abort before any write", function()
	local ns, env = newAddon()
	ns.Pending.set("groundEffectFade", 400)
	eq((ns.Preview.start()), false)
	eq(#env.cvars.writes, 0)
end)

test("first test captures the baseline from pre-test values", function()
	local ns, env = newAddon()
	ns.Pending.set("textureFilteringMode", 5)
	ns.Preview.start()
	eq(env.db.baseline.values.textureFilteringMode, 2)
end)

test("revert keeps an outside change to a child its parent rewrites", function()
	local ns, env = newAddon()
	ns.Pending.set("graphicsGroundClutter", 9)
	ns.Preview.start()
	env.cvars.external("groundEffectDensity", 120)
	local _, _, skipped = ns.Preview.revert("manual")
	contains(skipped, "groundEffectDensity")
	eq(env.cvars.value("graphicsGroundClutter"), 5)
	eq(env.cvars.value("groundEffectDensity"), 120)
	eq(env.cvars.value("groundEffectDist"), 200, "unskipped child still reverts")
end)

test("a preset child already equal to live survives its parent's rewrite", function()
	local ns, env = newAddon({ values = { groundEffectDensity = 128 } })
	ns.Pending.applyPreset("ultra")
	truthy((ns.Preview.start()))
	eq(env.cvars.value("graphicsGroundClutter"), 9)
	eq(env.cvars.value("groundEffectDensity"), 128)
end)
