test("experience detects Classic and Enhanced by enum", function()
	local ns, env = newAddon({ experience = 0 })
	eq(ns.Experience.detect(), "classic")
	env.experience = 1
	eq(ns.Experience.detect(), "enhanced")
end)

test("experience is unknown when API is missing, errors, nil, or unexpected", function()
	eq(newAddon({ noGameRules = true }).Experience.detect(), "unknown")
	eq(newAddon({ experienceError = true }).Experience.detect(), "unknown")
	eq(newAddon({ experience = nil }).Experience.detect(), "unknown")
	eq(newAddon({ experience = 7 }).Experience.detect(), "unknown")
end)

test("classic warning shows once per session and again after the preset changes", function()
	local ns, env = newAddon({ experience = 0 })
	local E = ns.Experience
	truthy(E.needsWarning())
	E.acknowledge()
	eq(E.needsWarning(), false)
	env.experience = 1
	eq(E.needsWarning(), false)
	env.experience = 0
	truthy(E.needsWarning(), "warns again after a context change")
end)

test("enhanced never warns", function()
	local ns = newAddon({ experience = 1 })
	eq(ns.Experience.needsWarning(), false)
end)
