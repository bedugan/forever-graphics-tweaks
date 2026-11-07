-- Runs a screenshot sequence: for each step, prepare it, show its caption,
-- wait for the scene to settle, take a screenshot, and wait for the game to
-- confirm. Knows nothing about GSM, so it can become a library later.
--
-- step:  { settle = seconds, prepare = function() -> ok, info|message }
--        Any other fields are the caller's.
-- hooks: clock()                      current time in seconds
--        screenshot()                 takes the screenshot
--        caption(step, info, index, total)
--        taken(step, info, index)     the game saved the screenshot
--        skipped(step, message, index) prepare returned false
--        finish(reason)               "done" or why the run stopped
local _, ns = ...

local Runner = {}
ns.Runner = Runner

-- Seconds to wait for SCREENSHOT_SUCCEEDED or SCREENSHOT_FAILED.
Runner.SHOT_TIMEOUT = 5

local Run = {}
Run.__index = Run

function Runner.start(steps, hooks)
	local run = setmetatable({ steps = steps, hooks = hooks, index = 0, phase = "idle" }, Run)
	run:advance()
	return run
end

function Run:isRunning()
	return self.phase ~= "done"
end

-- Moves to the next step that prepares without error.
function Run:advance()
	while true do
		self.index = self.index + 1
		local step = self.steps[self.index]
		if not step then
			self:stop("done")
			return
		end
		local ok, info = step.prepare()
		if ok then
			self.info = info
			self.phase = "settling"
			self.deadline = self.hooks.clock() + (step.settle or 0)
			self.hooks.caption(step, info, self.index, #self.steps)
			return
		end
		self.hooks.skipped(step, info, self.index)
	end
end

-- Call every frame.
function Run:tick()
	if self.phase == "settling" and self.hooks.clock() >= self.deadline then
		self.phase = "shooting"
		self.deadline = self.hooks.clock() + Runner.SHOT_TIMEOUT
		local ok, err = pcall(self.hooks.screenshot)
		if not ok then
			self:stop("screenshot error: " .. tostring(err))
		end
	elseif self.phase == "shooting" and self.hooks.clock() >= self.deadline then
		self:stop("the game did not confirm the screenshot")
	end
end

-- Call from SCREENSHOT_SUCCEEDED (true) and SCREENSHOT_FAILED (false).
-- Ignored unless this run asked for the screenshot.
function Run:shot(ok)
	if self.phase ~= "shooting" then
		return
	end
	if not ok then
		self:stop("the game could not save the screenshot")
		return
	end
	self.hooks.taken(self.steps[self.index], self.info, self.index)
	self:advance()
end

-- Ends the run once. Later calls do nothing.
function Run:stop(reason)
	if self.phase == "done" then
		return
	end
	self.phase = "done"
	self.hooks.finish(reason)
end
