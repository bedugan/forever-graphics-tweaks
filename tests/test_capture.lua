-- The capture companion: the generic runner, the GSM plan, the public API,
-- and the /gsmcap wiring against the fake frame API from test_ui_smoke.lua.

local CAPTURE = ROOT .. "/GraphicsSettingsManager_Capture/"

local function loadRunner()
	local ns = {}
	assert(loadfile(CAPTURE .. "Runner.lua"))("GraphicsSettingsManager_Capture", ns)
	return ns.Runner
end

-- Steps that log what happens. fail: set of step indexes whose prepare fails.
local function runnerFixture(count, fail)
	local log, clock = {}, { t = 0 }
	local steps = {}
	for i = 1, count do
		steps[i] = {
			settle = 2,
			prepare = function()
				table.insert(log, "prepare " .. i)
				if fail and fail[i] then
					return false, "nope"
				end
				return true, { n = i }
			end,
		}
	end
	local hooks = {
		clock = function() return clock.t end,
		screenshot = function() table.insert(log, "shoot") end,
		caption = function(_, info, index, total) table.insert(log, "caption " .. index .. "/" .. total) end,
		taken = function(_, info) table.insert(log, "taken " .. info.n) end,
		skipped = function(_, message, index) table.insert(log, "skipped " .. index .. " " .. message) end,
		finish = function(reason) table.insert(log, "finish " .. reason) end,
	}
	return steps, hooks, log, clock
end

test("capture runner: settles, shoots, waits for the game, then moves on", function()
	local Runner = loadRunner()
	local steps, hooks, log, clock = runnerFixture(2)
	local run = Runner.start(steps, hooks)
	eq(table.concat(log, ","), "prepare 1,caption 1/2")
	run:tick()
	eq(#log, 2, "no screenshot before the scene settles")
	clock.t = 2
	run:tick()
	eq(log[3], "shoot")
	run:shot(true)
	eq(table.concat(log, ",", 4), "taken 1,prepare 2,caption 2/2")
	clock.t = 4
	run:tick()
	run:shot(true)
	eq(log[#log], "finish done")
	eq(run:isRunning(), false)
end)

test("capture runner: skips steps that fail to prepare", function()
	local Runner = loadRunner()
	local steps, hooks, log, clock = runnerFixture(3, { [2] = true })
	local run = Runner.start(steps, hooks)
	clock.t = 2
	run:tick()
	run:shot(true)
	eq(table.concat(log, ",", 4), "taken 1,prepare 2,skipped 2 nope,prepare 3,caption 3/3")
end)

test("capture runner: stops on a failed or missing screenshot, once", function()
	local Runner = loadRunner()
	local steps, hooks, log, clock = runnerFixture(2)
	local run = Runner.start(steps, hooks)
	run:shot(true)
	eq(#log, 2, "a screenshot the run did not ask for is ignored")
	clock.t = 2
	run:tick()
	run:shot(false)
	eq(log[#log], "finish the game could not save the screenshot")
	run:stop("again")
	run:tick()
	eq(log[#log], "finish the game could not save the screenshot", "finish runs once")

	steps, hooks, log, clock = runnerFixture(1)
	run = Runner.start(steps, hooks)
	clock.t = 2
	run:tick()
	clock.t = 2 + Runner.SHOT_TIMEOUT
	run:tick()
	eq(log[#log], "finish the game did not confirm the screenshot")
end)

local function loadPlan()
	local ns = {}
	for _, file in ipairs({ "Runner.lua", "Band.lua", "Plan.lua" }) do
		assert(loadfile(CAPTURE .. file))("GraphicsSettingsManager_Capture", ns)
	end
	return ns.Plan
end

-- Band.lua only builds frames when create() is called, so Plan loads
-- without the fake frame API.
test("capture plan: four shots per setting, each from the start values plus one change", function()
	local gsm, env = newAddon()
	local Plan = loadPlan()
	local settings = assert(Plan.settings(gsm.API, { "groundEffectDensity", "graphicsGroundClutter" }))
	local snapshot = gsm.API.snapshot()
	local steps = Plan.steps(gsm.API, settings, snapshot)
	eq(#steps, 8)
	eq(steps[1].settle, Plan.SETTLE.delayed + Plan.LEAD_IN, "lead-in on the first shot")
	eq(steps[2].settle, Plan.SETTLE.delayed)
	eq(steps[4].shot, "control")
	eq(steps[4].value, steps[1].value, "the control repeats Low")

	truthy(steps[3].prepare())
	eq(env.cvars.value("groundEffectDensity"), 256)
	-- Clutter low after density high: density goes back first, then the
	-- clutter level rewrites it, as the game's menu would.
	local ok, record = steps[5].prepare()
	truthy(ok)
	eq(record.actual, 0)
	eq(env.cvars.value("groundEffectDensity"), 16, "the level rewrote its child")
	eq(env.cvars.value("lodObjectFadeScale"), snapshot.lodObjectFadeScale)
	eq(#gsm.API.restore(snapshot), 0)
	for cvar, value in pairs(snapshot) do
		eq(env.cvars.value(cvar), value, cvar)
	end
end)

test("capture plan: all skips missing settings; unknown names are refused", function()
	local gsm = newAddon({ missing = set({ "weatherDensity" }) })
	local Plan = loadPlan()
	local all = Plan.settings(gsm.API, { "ALL" })
	for _, setting in ipairs(all) do
		truthy(setting.cvar ~= "weatherDensity")
	end
	eq(#all, #gsm.Settings - 1)
	local none, message = Plan.settings(gsm.API, { "notACVar" })
	eq(none, nil)
	truthy(message:find("does not manage"))
	none, message = Plan.settings(gsm.API, { "weatherDensity" })
	eq(none, nil)
	truthy(message:find("missing"))
end)

test("capture plan: a level over its partner's live limit is skipped, not forced", function()
	local gsm, env = newAddon()
	local Plan = loadPlan()
	local steps = Plan.steps(gsm.API, { gsm.SettingsByKey.groundEffectFade }, gsm.API.snapshot())
	local ok, message = steps[3].prepare()
	eq(ok, false)
	truthy(message:find("Grass draw distance"), message)
	eq(env.cvars.value("groundEffectFade"), 160)
end)

test("capture plan: caption shows this shot, default, before, and presets", function()
	local gsm = newAddon({ values = { groundEffectDensity = 64 } })
	local Plan = loadPlan()
	local snapshot = gsm.API.snapshot()
	local steps = Plan.steps(gsm.API, { gsm.SettingsByKey.groundEffectDensity }, snapshot)
	local _, record = steps[2].prepare()
	local content = Plan.caption(gsm.API, steps[2], record, 2, 4, snapshot)
	eq(content.title, "Grass density")
	eq(content.subtitle, "groundEffectDensity / Medium / shot 2 of 4")
	eq(content.cells[1].value, "136")
	eq(content.cells[2].value, "40")
	eq(content.cells[3].value, "64")
	eq(content.cells[4].value, "64 / 128")
	content = Plan.caption(gsm.API, steps[4], record, 4, 4, snapshot)
	truthy(content.subtitle:find("Low again %(control%)"))
end)

test("gsm api: set captures the baseline and refuses during a test or combat", function()
	local gsm, env = newAddon()
	eq(env.db.baseline, nil)
	local ok, record = gsm.API.set("groundEffectDensity", 64)
	truthy(ok)
	eq(record.result, "ok")
	eq(env.db.baseline.values.groundEffectDensity, 40, "baseline holds the value before the first write")
	ok, record = gsm.API.set("groundEffectDensity", 64)
	truthy(ok, "setting a value already live is fine")
	eq(record.actual, 64)

	gsm.Pending.set("weatherDensity", 3)
	truthy(gsm.Preview.start())
	ok, record = gsm.API.set("groundEffectDensity", 80)
	eq(ok, false)
	truthy(record:find("current GSM test"))
	gsm.Preview.revert("manual")

	env.combat = true
	eq(gsm.API.set("groundEffectDensity", 80), false)
	eq(GraphicsSettingsManagerAPI, gsm.API, "the API is a global")
end)

test("gsm api: lowering a limit below a live dependent is refused", function()
	local gsm, env = newAddon()
	local ok, message = gsm.API.set("groundEffectDist", 40)
	eq(ok, false)
	truthy(message:find("Grass fade start"), message)
	eq(env.cvars.value("groundEffectDist") ~= 40, true)
end)

test("gsm api: a clamped restore counts as a failure", function()
	local gsm = newAddon({ values = { groundEffectDensity = 64 }, clamp = { groundEffectDensity = 200 } })
	local snapshot = gsm.API.snapshot()
	snapshot.groundEffectDensity = 256
	local failed = gsm.API.restore(snapshot)
	eq(#failed, 1)
	eq(failed[1].result, "clamped")
end)

test("gsm api: rejected writes report failure and leave the value alone", function()
	local gsm, env = newAddon({ reject = set({ "groundEffectDensity" }) })
	local ok, message = gsm.API.set("groundEffectDensity", 64)
	eq(ok, false)
	truthy(message:find("rejected"))
	eq(env.cvars.value("groundEffectDensity"), 40)
	eq(gsm.API.set("groundEffectDensity", 9999), false, "out of range")
end)

-- /gsmcap end to end, on the fake frame API.

local function tocFiles(path)
	local out = {}
	for line in io.lines(path) do
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" and not line:find("^#") then
			table.insert(out, line)
		end
	end
	return out
end

local function newCapture(opts)
	opts = opts or {}
	local gsm, env = UI.new(opts)
	env.shots, env.chat, env.moving = 0, {}, false
	WorldFrame = UI.widget("Frame", "WorldFrame")
	WorldFrame:SetHeight(1080)
	DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(env.chat, msg) end }
	GetTime = function() return env.t end
	time = os.time
	GetBuildInfo = function() return "1.60.1", "70790" end
	GetRealZoneText = function() return "Elwynn Forest" end
	GetSubZoneText = function() return "Goldshire" end
	IsPlayerMoving = function() return env.moving end
	C_CVar = { GetCVar = function() return "jpeg" end }
	Screenshot = function() env.shots = env.shots + 1 end
	SetUIVisibility = function(show)
		if opts.uiLocked then
			return
		end
		UIParent:SetShown(show)
	end
	GraphicsSettingsManagerCaptureDB = nil
	local ns = {}
	for _, file in ipairs(tocFiles(CAPTURE .. "GraphicsSettingsManager_Capture.toc")) do
		assert(loadfile(CAPTURE .. file))("GraphicsSettingsManager_Capture", ns)
	end
	env.cap = SlashCmdList.GRAPHICSSETTINGSMANAGERCAPTURE
	-- Advance the clock and confirm screenshots until the run ends or n shots.
	function env.shoot(n)
		for _ = 1, n do
			local before = env.shots
			for _ = 1, 20 do
				env.t = env.t + 1
				UI.update()
				if env.shots > before then
					break
				end
			end
			UI.fire("SCREENSHOT_SUCCEEDED")
		end
	end
	return gsm, env, ns
end

local function band()
	return GraphicsSettingsManagerCaptureBand
end

test("gsmcap: one setting runs four shots, logs them, and puts everything back", function()
	local gsm, env = newCapture()
	local before = gsm.CVarStore.readAll()
	env.cap("groundEffectDensity")
	eq(UIParent:IsShown(), false, "the interface is hidden")
	truthy(band():IsShown())
	eq(env.cvars.value("groundEffectDensity"), 16)
	env.shoot(4)
	local run = GraphicsSettingsManagerCaptureDB.runs[1]
	eq(run.result, "done")
	eq(#run.shots, 4)
	eq(run.shots[2].level, "medium")
	eq(run.shots[2].actual, 136)
	eq(run.shots[4].shot, "control")
	truthy(run.shots[1].stamp:match("^%d%d%d%d%d%d_%d%d%d%d%d%d$"))
	eq(run.build, "1.60.1.70790")
	eq(run.zone, "Elwynn Forest, Goldshire")
	eq(run.band, 64 / 1080)
	eq(band():IsShown(), false)
	truthy(UIParent:IsShown(), "the interface comes back")
	for cvar, value in pairs(before) do
		eq(env.cvars.value(cvar), value, cvar)
	end
end)

test("gsmcap: a setting with a level over a live limit is dropped before the run, with a reason", function()
	local _, env = newCapture()
	env.cap("groundEffectFade")
	eq(GraphicsSettingsManagerCaptureDB, nil, "no run is logged")
	truthy(env.chat[#env.chat - 1]:find("Skipping Grass fade start. .*Grass draw distance"), env.chat[#env.chat - 1])
	truthy(env.chat[#env.chat]:find("Nothing left to capture"))
	eq(UIParent:IsShown(), true)

	env.cap("groundEffectFade groundEffectDensity")
	env.shoot(4)
	local run = GraphicsSettingsManagerCaptureDB.runs[1]
	eq(run.result, "done")
	eq(#run.shots, 4)
	eq(run.shots[1].cvar, "groundEffectDensity")
	eq(run.labels.groundEffectFade, nil)
end)

test("gsmcap: Esc, movement, and combat stop the run and restore", function()
	for _, stop in ipairs({ "esc", "move", "combat" }) do
		local gsm, env = newCapture()
		env.cap("groundEffectDensity")
		env.shoot(1)
		if stop == "esc" then
			local keys
			for _, w in ipairs(UI.frames()) do
				if w.scripts.OnKeyDown and w.parent == band() then
					keys = w
				end
			end
			keys:fire("OnKeyDown", "W")
			eq(GraphicsSettingsManagerCaptureDB.runs[1].result, nil, "other keys pass through")
			keys:fire("OnKeyDown", "ESCAPE")
		elseif stop == "move" then
			UI.fire("PLAYER_STARTED_MOVING")
		else
			UI.fire("PLAYER_REGEN_DISABLED")
		end
		local run = GraphicsSettingsManagerCaptureDB.runs[1]
		truthy(run.result ~= nil and run.result ~= "done", stop)
		eq(#run.shots, 1)
		eq(env.cvars.value("groundEffectDensity"), 40, stop .. " restores")
		truthy(UIParent:IsShown())
	end
end)

test("gsmcap: waits for Alt+Z when the interface cannot be hidden, then gives up", function()
	local _, env = newCapture({ uiLocked = true })
	env.cap("groundEffectDensity")
	eq(env.cvars.value("groundEffectDensity"), 40, "nothing written while waiting")
	UIParent:Hide()
	UI.update()
	eq(env.cvars.value("groundEffectDensity"), 16, "starts once hidden")
	env.shoot(4)
	eq(GraphicsSettingsManagerCaptureDB.runs[1].result, "done")
	eq(UIParent:IsShown(), false, "the player hid it, so the player shows it")
	truthy(env.chat[#env.chat - 1]:find("Alt%+Z"))

	_, env = newCapture({ uiLocked = true })
	env.cap("groundEffectDensity")
	env.t = env.t + 31
	UI.update()
	eq(GraphicsSettingsManagerCaptureDB.runs[1].result, "the interface was not hidden")
end)

test("gsmcap: refuses during a GSM test, while moving, and twice", function()
	local gsm, env = newCapture()
	env.moving = true
	env.cap("groundEffectDensity")
	truthy(env.chat[#env.chat]:find("Stand still"))
	env.moving = false
	gsm.Pending.set("weatherDensity", 3)
	gsm.Preview.start()
	env.cap("all")
	truthy(env.chat[#env.chat]:find("current GSM test"))
	gsm.Preview.revert("manual")
	env.cap("all")
	env.cap("all")
	truthy(env.chat[#env.chat]:find("already running"))
	env.cap("stop")
	eq(GraphicsSettingsManagerCaptureDB.runs[1].result, "stopped by /gsmcap stop")
end)

test("gsmcap: logout mid-run restores before SavedVariables are written", function()
	local _, env = newCapture()
	env.cap("groundEffectDensity")
	env.shoot(2)
	UI.fire("PLAYER_LOGOUT")
	eq(GraphicsSettingsManagerCaptureDB.runs[1].result, "logout")
	eq(env.cvars.value("groundEffectDensity"), 40)
end)
