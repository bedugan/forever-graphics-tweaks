-- The timed test. See docs/adr/0002-preview-transaction.md.
-- idle -> previewing -> idle through Keep, Revert, or timeout.
local _, ns = ...

local Store = ns.CVarStore
local Preview = {}
ns.Preview = Preview

Preview.DURATION = 15

local state -- nil when idle

function Preview.isActive()
	return state ~= nil
end

function Preview.remaining()
	if not state then
		return 0
	end
	return math.max(0, state.deadline - ns.api.clock())
end

function Preview.records()
	return state and state.records or {}
end

local function failures(records)
	local out = {}
	for _, record in ipairs(records or {}) do
		if record.result ~= "ok" and record.result ~= "clamped" then
			table.insert(out, record)
		end
	end
	return out
end
Preview.failures = failures

-- Returns ok, message, records.
function Preview.start()
	if state then
		return false, "A test is already running."
	end
	if ns.api.inCombat() then
		return false, "Not available in combat."
	end
	local changes = ns.Pending.changes()
	if #changes == 0 then
		return false, "No pending changes to test."
	end
	local valid, errors = ns.Pending.validate(changes)
	if not valid then
		return false, errors[1], nil, errors
	end

	ns.Profiles.ensureBaseline()
	local snapshot = Store.readAll()
	local ok, records, failed, rollback = Store.transaction(changes, snapshot)
	if not ok then
		local label = ns.SettingsByKey[failed.cvar].label
		local message = label .. " was " .. failed.result .. " by the game. All changes were undone."
		if #failures(rollback) > 0 then
			message = label .. " was " .. failed.result .. " by the game, and some values could not be put back. Run /fgt diag."
		end
		ns.emit("PREVIEW_FAILED", message, records, rollback)
		return false, message, records
	end

	state = {
		snapshot = snapshot,
		applied = Store.readAll(),
		records = records,
		deadline = ns.api.clock() + Preview.DURATION,
	}
	ns.emit("PREVIEW_STARTED", records)
	return true, nil, records
end

-- Accept the previewed values.
function Preview.keep()
	if not state then
		return false
	end
	state = nil
	ns.Pending.clear()
	ns.emit("PREVIEW_ENDED", "keep")
	return true
end

-- Put the snapshot back. Skips any CVar that something else changed
-- after FGT applied it. reason: "manual" | "timeout" | "logout" | "slash".
function Preview.revert(reason)
	if not state then
		return false
	end
	local current = state
	state = nil

	-- Decide what is ours before writing, because writing a quality-level
	-- parent rewrites its children.
	local restorable, skipped = {}, {}
	for cvar in pairs(current.snapshot) do
		local live, applied = Store.get(cvar), current.applied[cvar]
		if live ~= nil and applied ~= nil and not Store.near(live, applied) then
			table.insert(skipped, cvar)
		else
			restorable[cvar] = true
		end
	end
	local records = Store.writeValues(current.snapshot, restorable)
	ns.emit("PREVIEW_ENDED", reason or "manual", records, skipped)
	return true, records, skipped
end

-- Called from an OnUpdate driver. Uses elapsed clock time, not frames.
function Preview.tick()
	if state and ns.api.clock() >= state.deadline then
		Preview.revert("timeout")
	end
end
