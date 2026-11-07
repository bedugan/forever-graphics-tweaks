-- Reads the Classic/Enhanced experience preset. Never writes it.
local _, ns = ...

local Experience = {}
ns.Experience = Experience

local acknowledged -- preset value the user clicked Continue for, this session only

-- Returns "classic" | "enhanced" | "unknown", plus a reason for unknown.
function Experience.detect()
	local gameRules, enum = ns.api.gameRules, ns.api.enum
	local presets = enum and enum.ForeverExperiencePreset
	if not (gameRules and gameRules.GetForeverExperiencePreset and presets) then
		return "unknown", "API not available"
	end
	local ok, preset = pcall(gameRules.GetForeverExperiencePreset)
	if not ok then
		return "unknown", "API error"
	end
	if preset == nil then
		return "unknown", "API returned nothing"
	end
	if preset == presets.Classic then
		return "classic"
	end
	if preset == presets.Enhanced then
		return "enhanced"
	end
	return "unknown", "unexpected value " .. tostring(preset)
end

-- True when the Classic warning should show. It shows once per session and
-- again only if the detected preset changes.
function Experience.needsWarning()
	local state = Experience.detect()
	if state ~= acknowledged then
		acknowledged = nil
	end
	return state == "classic" and acknowledged == nil
end

function Experience.acknowledge()
	acknowledged = Experience.detect()
end

function Experience.resetSession()
	acknowledged = nil
end
