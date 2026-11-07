-- The three illustrative levels used by the comparison panel and by the
-- capture companion, so both agree on what "High" means for a setting.
local _, ns = ...

local Levels = {}
ns.Levels = Levels

Levels.order = { "low", "medium", "high" }
Levels.labels = { low = "Low", medium = "Medium", high = "High" }

local POSITION = { low = 0, medium = 0.5, high = 1 }

-- 0 (low), 0.5 (medium), or 1 (high).
function Levels.position(level)
	return POSITION[level]
end

-- Example CVar value for a level. Reversed settings count down.
function Levels.value(setting, level)
	local t = POSITION[level]
	if setting.reverse then
		t = 1 - t
	end
	return ns.Pending.normalize(setting, setting.min + (setting.max - setting.min) * t)
end

-- The level closest to a value. Medium when the value is unknown.
function Levels.nearest(setting, value)
	if value == nil then
		return "medium"
	end
	local t = (value - setting.min) / (setting.max - setting.min)
	if setting.reverse then
		t = 1 - t
	end
	if t < 1 / 3 then
		return "low"
	elseif t < 2 / 3 then
		return "medium"
	end
	return "high"
end
