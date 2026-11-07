-- Prints docs/SETTINGS.md from Core/Definitions.lua so the two never drift.
-- Usage: lua scripts/settings_doc.lua [root] > docs/SETTINGS.md
local root = arg[1] or "."
local ns = {}
assert(loadfile(root .. "/GraphicsSettingsManager/Core/Definitions.lua"))("GraphicsSettingsManager", ns)

local out = {}
local function add(line)
	table.insert(out, line or "")
end

local function value(setting, v)
	if v == nil then
		return "unchanged"
	end
	local text = tostring(v)
	if setting.kind == "choice" then
		text = text .. " (" .. setting.choices[v - setting.min + 1] .. ")"
	elseif setting.kind == "toggle" then
		text = text .. (v == 1 and " (on)" or " (off)")
	end
	return text
end

local function range(setting)
	if setting.kind == "toggle" then
		return "0 or 1"
	end
	local text = setting.min .. " to " .. setting.max
	if setting.step ~= 1 then
		text = text .. ", step " .. setting.step
	end
	return text
end

local EVIDENCE = { source = "Blizzard UI source, build 70790", wiki = "warcraft.wiki.gg (Retail)" }
local TIMING = {
	immediate = "Right away",
	delayed = "As new terrain and ground cover load. Turn the camera or move a short way",
}
local CATEGORY = {}
for _, c in ipairs(ns.Categories) do
	CATEGORY[c.key] = c.label
end

add("# Settings")
add()
add("Every graphics setting GSM manages. This file is generated from `GraphicsSettingsManager/Core/Definitions.lua` by `scripts/settings_doc.lua`. Edit the definitions, then regenerate.")
add()
add("Nothing here is verified in the Forever client yet. Ranges and values come from the evidence listed for each setting. Impact is an estimate, not a measurement.")
add()
add("## How to read this")
add()
add("- **Range** is what GSM allows. The client may clamp further. GSM reads the value back after every write and reports a clamp.")
add("- **Game default** is not listed. GSM reads it from the client at runtime with `C_CVar.GetCVarDefault`, because defaults can change between builds. The Default preset uses it.")
add("- **Balanced** and **Ultra** are raw CVar values. \"unchanged\" means the preset leaves the setting alone.")
add("- **Timing** is when the change shows on screen. None of these settings is documented as needing a reload or restart, so every one can use the 15 second test. The in-game checklist confirms this.")
add("- Quality levels (tier 1) use the raw range 0 to 9. Blizzard and GSM show them as 1 to 10. Changing one rewrites the detailed values it controls, so GSM applies tier 1 first.")
add()
add("## Summary")
add()
add("| Setting | CVar | Range | Balanced | Ultra | Impact | Timing |")
add("| --- | --- | --- | --- | --- | --- | --- |")
for _, s in ipairs(ns.Settings) do
	add(string.format("| %s | `%s` | %s | %s | %s | %s | %s |", s.label, s.cvar, range(s),
		value(s, s.presets.balanced), value(s, s.presets.ultra), s.impact, s.timing))
end
add()
add("## Not managed")
add()
add("- `SSAOType`: excluded. Its values are undocumented for this build, so GSM cannot validate them.")
add("- Raid graphics mirrors (`RAID*`): left alone. `/gsm diag` reports whether raid settings are enabled.")
add("- Resolution, graphics API, refresh rate, display device, and character models: out of scope.")

local current
for _, s in ipairs(ns.Settings) do
	if s.category ~= current then
		current = s.category
		add()
		add("## " .. CATEGORY[current])
	end
	add()
	add("### " .. s.label)
	add()
	add(s.summary)
	add()
	add("- CVar: `" .. s.cvar .. "`")
	add("- Range: " .. range(s))
	if s.kind == "choice" then
		local labels = {}
		for i, label in ipairs(s.choices) do
			table.insert(labels, (s.min + i - 1) .. " " .. label)
		end
		add("- Values: " .. table.concat(labels, ", "))
	end
	if s.reverse then
		add("- Direction: lower values mean more detail, so GSM's slider runs right to left")
	end
	if s.lessThan then
		add("- Constraint: must stay below `" .. s.lessThan .. "`")
	end
	if s.atMost then
		add("- Constraint: must not exceed `" .. s.atMost .. "`")
	end
	add("- Balanced: " .. value(s, s.presets.balanced))
	add("- Ultra: " .. value(s, s.presets.ultra))
	add("- Estimated impact: " .. s.impact)
	add("- Takes effect: " .. TIMING[s.timing])
	add("- Evidence: " .. EVIDENCE[s.evidence] .. ". Not verified in game")
end

io.write(table.concat(out, "\n"), "\n")
