-- Minimal test runner for Lua 5.1. Usage: lua tests/run.lua [root]
ROOT = arg[1] or "."

local passed, failed = 0, {}
local current

function test(name, fn)
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		table.insert(failed, name .. "\n    " .. tostring(err))
	end
end

local function show(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function eq(actual, expected, msg)
	if actual ~= expected then
		error((msg and (msg .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function truthy(value, msg)
	if not value then
		error(msg or "expected a truthy value", 2)
	end
end

function contains(list, value, msg)
	for _, v in ipairs(list) do
		if v == value then
			return
		end
	end
	error((msg or "list") .. " does not contain " .. show(value), 2)
end

dofile(ROOT .. "/tests/mocks.lua")

local files = {
	"tests/test_cvarstore.lua",
	"tests/test_experience.lua",
	"tests/test_pending.lua",
	"tests/test_preview.lua",
	"tests/test_profiles.lua",
	"tests/test_definitions.lua",
	"tests/test_ui_smoke.lua",
	"tests/test_capture.lua",
}
for _, file in ipairs(files) do
	dofile(ROOT .. "/" .. file)
end

print(string.format("%d passed, %d failed", passed, #failed))
for _, f in ipairs(failed) do
	print("FAIL " .. f)
end
os.exit(#failed == 0 and 0 or 1)
