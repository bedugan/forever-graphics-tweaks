test("status reports available, missing, restricted", function()
	local ns = newAddon({ missing = set({ "weatherDensity" }), restricted = set({ "reflectionMode" }) })
	eq(ns.CVarStore.status("groundEffectDensity"), "available")
	eq(ns.CVarStore.status("weatherDensity"), "missing")
	eq(ns.CVarStore.status("reflectionMode"), "restricted")
end)

test("set classifies ok, clamped, rejected, error by readback", function()
	local ns = newAddon({
		clamp = { groundEffectDist = 300 },
		reject = set({ "reflectionMode" }),
		error = set({ "weatherDensity" }),
	})
	local Store = ns.CVarStore
	eq(Store.set("groundEffectDensity", 64), "ok")
	local result, actual = Store.set("groundEffectDist", 450)
	eq(result, "clamped")
	eq(actual, 300)
	eq((Store.set("weatherDensity", 3)), "error")
end)

test("set reports rejected when the value does not change", function()
	local ns = newAddon({ reject = set({ "reflectionMode" }) })
	eq((ns.CVarStore.set("reflectionMode", 3)), "rejected")
end)

test("readAll skips missing and restricted settings", function()
	local ns = newAddon({ missing = set({ "weatherDensity" }), restricted = set({ "reflectionMode" }) })
	local values = ns.CVarStore.readAll()
	eq(values.weatherDensity, nil)
	eq(values.reflectionMode, nil)
	eq(values.groundEffectDensity, 40)
end)

test("transaction writes tier 1 before tier 2", function()
	local ns, env = newAddon()
	local ok = ns.CVarStore.transaction({
		{ cvar = "groundEffectDensity", value = 64 },
		{ cvar = "graphicsGroundClutter", value = 7 },
	}, ns.CVarStore.readAll())
	truthy(ok)
	eq(env.cvars.writes[1].name, "graphicsGroundClutter")
	eq(env.cvars.writes[2].name, "groundEffectDensity")
	-- The explicit child value survives the parent's rewrite.
	eq(env.cvars.value("groundEffectDensity"), 64)
end)

test("transaction rolls back everything when a write fails", function()
	local ns, env = newAddon({ error = set({ "weatherDensity" }) })
	local snapshot = ns.CVarStore.readAll()
	local ok, _, failed = ns.CVarStore.transaction({
		{ cvar = "graphicsGroundClutter", value = 9 },
		{ cvar = "groundEffectDensity", value = 128 },
		{ cvar = "weatherDensity", value = 3 },
	}, snapshot)
	eq(ok, false)
	eq(failed.cvar, "weatherDensity")
	for cvar, value in pairs(snapshot) do
		eq(env.cvars.value(cvar), value, cvar)
	end
end)
