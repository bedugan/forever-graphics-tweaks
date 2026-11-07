-- Events, the /gsmcap command, and the capture log. Developer tool: it is
-- not part of the GSM release ZIP. Nothing here writes a CVar at load.
local _, ns = ...

local gsm = GraphicsSettingsManagerAPI
local Plan, Runner = ns.Plan, ns.Runner

-- Seconds to wait for the player to hide the interface with Alt+Z.
local UI_WAIT = 30

local session -- nil when idle

local function say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7GSM capture|r " .. msg)
end

local function db()
	local saved = GraphicsSettingsManagerCaptureDB
	if type(saved) ~= "table" then
		saved = {}
		GraphicsSettingsManagerCaptureDB = saved
	end
	saved.runs = saved.runs or {}
	return saved
end

local function zone()
	local name, sub = GetRealZoneText() or "?", GetSubZoneText() or ""
	return sub ~= "" and (name .. ", " .. sub) or name
end

local function stamp()
	return date("%m%d%y_%H%M%S")
end

local band = ns.Band.create(4)
-- Unparented, so its OnUpdate runs while the band is hidden.
local driver = CreateFrame("Frame")

-- Esc stops a run. Every other key goes through to the game.
local keys = CreateFrame("Frame", nil, band.frame)
keys:SetScript("OnKeyDown", function(self, key)
	local stop = key == "ESCAPE"
	self:SetPropagateKeyboardInput(not stop)
	if stop then
		ns.stop("Esc pressed")
	end
end)

local function finish(reason)
	local current = session
	session = nil
	driver:SetScript("OnUpdate", nil)
	keys:EnableKeyboard(false)
	band:hide()
	local failed = gsm.restore(current.snapshot)
	if current.hidUI then
		pcall(SetUIVisibility, true)
	end
	current.log.result = reason
	current.log.finished = time()
	if reason == "done" then
		say(string.format("Done: %d screenshots.", #current.log.shots))
	else
		say(string.format("Stopped: %s. %d screenshots taken.", reason, #current.log.shots))
	end
	for _, record in ipairs(failed) do
		say("Could not put back " .. record.cvar .. ". Run /gsm diag.")
	end
	if not UIParent:IsShown() then
		say("Press Alt+Z to show the interface again.")
	end
	say("Type /reload to save the log, then run scripts/import_captures.sh.")
end

local hooks = {
	clock = GetTime,
	screenshot = Screenshot,
	caption = function(step, record, index, total)
		band:set(Plan.caption(gsm, step, record, index, total, session.snapshot))
	end,
	taken = function(step, record)
		table.insert(session.log.shots, {
			stamp = stamp(), epoch = time(),
			cvar = step.setting.cvar, shot = step.shot, level = step.level,
			requested = step.value, actual = record.actual, result = record.result,
		})
	end,
	skipped = function(step, message)
		table.insert(session.log.skipped, { cvar = step.setting.cvar, shot = step.shot, message = message })
		say(string.format("Skipped %s %s: %s", step.setting.label, step.shot, message))
	end,
	finish = finish,
}

local function begin()
	session.log.band = band:fraction()
	keys:EnableKeyboard(true)
	keys:SetPropagateKeyboardInput(true)
	local current = session
	-- Runner.start can finish at once if every step is skipped.
	current.run = Runner.start(current.steps, hooks)
	if session then
		driver:SetScript("OnUpdate", function()
			current.run:tick()
		end)
	end
end

-- Waits until the interface is hidden, then starts the run.
local function waitForUI()
	if not UIParent:IsShown() then
		begin()
	elseif GetTime() >= session.uiDeadline then
		finish("the interface was not hidden")
	end
end

function ns.stop(reason)
	if not session then
		return false
	end
	if session.run then
		session.run:stop(reason)
	else
		finish(reason)
	end
	return true
end

function ns.start(names)
	if session then
		return false, "A capture is already running. /gsmcap stop ends it."
	end
	local reason = gsm.blocked()
	if reason then
		return false, reason
	end
	if IsPlayerMoving() then
		return false, "Stand still first."
	end
	local settings, message = Plan.settings(gsm, names)
	if not settings then
		return false, message
	end
	-- Drop a setting now if any level would be refused, rather than shooting
	-- a partial set. Every shot starts from the live values, so check those.
	local ready = {}
	for _, setting in ipairs(settings) do
		local problem
		for _, level in ipairs(gsm.levels) do
			problem = problem or gsm.check(setting.cvar, gsm.levelValue(setting, level))
		end
		if problem then
			say(string.format("Skipping %s. %s Change that in GSM first.", setting.label, problem))
		else
			table.insert(ready, setting)
		end
	end
	if #ready == 0 then
		return false, "Nothing left to capture."
	end
	settings = ready
	local snapshot = gsm.snapshot()
	local steps = Plan.steps(gsm, settings, snapshot)
	if #steps == 0 then
		return false, "Nothing to capture on this client."
	end
	local labels = {}
	for _, setting in ipairs(settings) do
		labels[setting.cvar] = setting.label
	end
	local version, build = GetBuildInfo()
	local log = {
		started = stamp(), epoch = time(), build = version .. "." .. build, zone = zone(),
		format = C_CVar.GetCVar("screenshotFormat"), labels = labels, before = snapshot,
		shots = {}, skipped = {},
	}
	table.insert(db().runs, log)
	session = { snapshot = snapshot, steps = steps, log = log }

	say(string.format("Capturing %d settings, %d shots, about %d seconds. Do not move or touch the camera. Esc stops.",
		#settings, #steps, Plan.duration(steps)))
	pcall(SetUIVisibility, false)
	if not UIParent:IsShown() then
		session.hidUI = true
		begin()
	else
		say("Press Alt+Z to hide the interface. The capture starts when it is hidden.")
		session.uiDeadline = GetTime() + UI_WAIT
		driver:SetScript("OnUpdate", waitForUI)
	end
	return true
end

local events = CreateFrame("Frame")
local stopEvents = {
	PLAYER_REGEN_DISABLED = "combat started",
	PLAYER_STARTED_MOVING = "you moved",
	PLAYER_LEAVING_WORLD = "a loading screen started",
	PLAYER_LOGOUT = "logout",
}
for _, event in ipairs({ "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED",
	"PLAYER_REGEN_DISABLED", "PLAYER_STARTED_MOVING", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do
	-- Event names can differ between client builds. Skip any the client rejects.
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
	if not session then
		return
	end
	if event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
		if session.run then
			session.run:shot(event == "SCREENSHOT_SUCCEEDED")
		end
	else
		ns.stop(stopEvents[event])
	end
end)

local help = {
	"/gsmcap all  shoot every setting GSM can test",
	"/gsmcap <cvar> [<cvar> ...]  shoot only these settings",
	"/gsmcap list  show the settings and their Low, Medium, and High values",
	"/gsmcap stop  stop and put the settings back",
}

SLASH_GRAPHICSSETTINGSMANAGERCAPTURE1 = "/gsmcap"
SlashCmdList.GRAPHICSSETTINGSMANAGERCAPTURE = function(msg)
	local words = {}
	for word in (msg or ""):gmatch("[^%s,]+") do
		table.insert(words, word)
	end
	local command = words[1] and words[1]:lower()
	if command == nil or command == "help" then
		for _, line in ipairs(help) do
			say(line)
		end
	elseif command == "stop" then
		if not ns.stop("stopped by /gsmcap stop") then
			say("No capture is running.")
		end
	elseif command == "list" then
		for _, setting in ipairs(gsm.settings) do
			local values = {}
			for _, level in ipairs(gsm.levels) do
				table.insert(values, tostring(gsm.levelValue(setting, level)))
			end
			say(string.format("%s  %s  %s", setting.cvar, gsm.status(setting.cvar), table.concat(values, " / ")))
		end
	else
		local ok, message = ns.start(words)
		if not ok then
			say(message)
		end
	end
end
