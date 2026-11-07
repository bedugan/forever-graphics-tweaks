-- Builds the screenshot steps for GSM settings. Each shot starts from the
-- values live when the capture began and changes exactly one setting, the
-- way the game's own menu would. A quality level still rewrites its
-- children, because that is what the level does.
local _, ns = ...

local Plan = {}
ns.Plan = Plan

-- Seconds to wait after a change. Delayed settings stream in new terrain
-- and grass, so they get longer.
Plan.SETTLE = { immediate = 2, delayed = 6 }
-- Extra wait before the first shot, so the camera and mouse are still.
Plan.LEAD_IN = 3

-- Low, Medium, High, then Low again. The second Low shows what moves on
-- its own (water, weather, swaying grass), so the import can ignore it.
Plan.SHOTS = { "low", "medium", "high", "control" }

local function levelOf(shot)
	return shot == "control" and "low" or shot
end

-- Settings to shoot. names: list of CVar names, or { "all" } for every
-- available setting that GSM can test. Returns list, or nil and message.
function Plan.settings(gsm, names)
	local out = {}
	if #names == 1 and names[1]:lower() == "all" then
		for _, setting in ipairs(gsm.settings) do
			if setting.previewable and gsm.status(setting.cvar) == "available" then
				table.insert(out, setting)
			end
		end
		return out
	end
	for _, name in ipairs(names) do
		local found
		for _, setting in ipairs(gsm.settings) do
			if setting.cvar:lower() == name:lower() then
				found = setting
			end
		end
		if not found then
			return nil, "GSM does not manage " .. name .. ". Try /gsmcap list."
		end
		local status = gsm.status(found.cvar)
		if status ~= "available" then
			return nil, found.label .. " is " .. status .. " on this client."
		end
		table.insert(out, found)
	end
	return out
end

-- snapshot: cvar -> value captured just before the run.
function Plan.steps(gsm, settings, snapshot)
	local steps = {}
	for _, setting in ipairs(settings) do
		for _, shot in ipairs(Plan.SHOTS) do
			local level = levelOf(shot)
			local value = gsm.levelValue(setting, level)
			table.insert(steps, {
				setting = setting,
				shot = shot,
				level = level,
				value = value,
				settle = Plan.SETTLE[setting.timing] or Plan.SETTLE.delayed,
				prepare = function()
					local failed = gsm.restore(snapshot)
					if #failed > 0 then
						return false, "could not put " .. failed[1].cvar .. " back before the shot"
					end
					return gsm.set(setting.cvar, value)
				end,
			})
		end
	end
	if steps[1] then
		steps[1].settle = steps[1].settle + Plan.LEAD_IN
	end
	return steps
end

-- Rough length of a run in seconds, including about a second per shot.
function Plan.duration(steps)
	local total = 0
	for _, step in ipairs(steps) do
		total = total + step.settle + 1
	end
	return total
end

local function show(setting, value)
	if value == nil then
		return "-"
	end
	local text = tostring(value)
	local choice = setting.choices and setting.choices[value - setting.min + 1]
	return choice and (text .. " " .. choice) or text
end

-- Band content for a step. record is what gsm.set returned.
function Plan.caption(gsm, step, record, index, total, snapshot)
	local setting = step.setting
	local presets = setting.presets or {}
	local levelLabel = gsm.levelLabels[step.level] .. (step.shot == "control" and " again (control)" or "")
	return {
		title = setting.label,
		subtitle = string.format("%s / %s / shot %d of %d", setting.cvar, levelLabel, index, total),
		cells = {
			{ label = "This shot", value = show(setting, record.actual), color = ns.Band.GOLD },
			{ label = "Game default", value = show(setting, gsm.default(setting.cvar)) },
			{ label = "Before capture", value = show(setting, snapshot[setting.cvar]) },
			{ label = "Balanced / Ultra", value = show(setting, presets.balanced) .. " / " .. show(setting, presets.ultra) },
		},
	}
end
