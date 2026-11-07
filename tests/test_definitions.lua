test("every setting definition is complete and consistent", function()
	local ns = newAddon()
	local categories = {}
	for _, c in ipairs(ns.Categories) do
		categories[c.key] = true
	end
	local kinds = set({ "slider", "choice", "toggle" })
	local impacts = set({ "low", "medium", "high" })
	local timings = set({ "immediate", "delayed" })
	for _, s in ipairs(ns.Settings) do
		local where = s.cvar
		truthy(s.label and s.summary, where .. " text")
		truthy(categories[s.category], where .. " category")
		truthy(kinds[s.kind], where .. " kind")
		truthy(impacts[s.impact], where .. " impact")
		truthy(timings[s.timing], where .. " timing")
		truthy(s.tier == 1 or s.tier == 2, where .. " tier")
		truthy(s.min < s.max and s.step > 0, where .. " range")
		truthy(s.evidence == "source" or s.evidence == "wiki", where .. " evidence")
		truthy(s.visual, where .. " visual")
		if s.kind == "choice" then
			eq(#s.choices, s.max - s.min + 1, where .. " choices")
		end
		for preset, value in pairs(s.presets) do
			truthy(value >= s.min and value <= s.max, where .. " " .. preset .. " in range")
			eq(ns.Pending.normalize(s, value), value, where .. " " .. preset .. " on step")
		end
	end
end)

test("SSAOType is not managed", function()
	local ns = newAddon()
	eq(ns.SettingsByKey.SSAOType, nil)
	eq(ns.SettingsByKey.ssaoType, nil)
end)

test("loading Core writes nothing", function()
	local _, env = newAddon()
	eq(#env.cvars.writes, 0)
end)

test("diagnostics runs read-only", function()
	local ns, env = newAddon({ experience = 0, missing = set({ "weatherDensity" }) })
	local lines = ns.Diagnostics.lines()
	truthy(#lines > 10)
	eq(#env.cvars.writes, 0)
	local text = table.concat(lines, "\n")
	truthy(text:find("Experience preset: classic"), "experience line")
	truthy(text:find("15 available, 1 missing"), "counts")
end)
