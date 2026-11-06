-- Events, chat messages, and the /fgt command. Loaded last.
-- Nothing here writes a CVar at load or login.
local _, ns = ...

local function label(cvar)
	local setting = ns.SettingsByKey[cvar]
	return setting and setting.label or cvar
end

local function names(cvars)
	local out = {}
	for _, cvar in ipairs(cvars) do
		table.insert(out, label(cvar))
	end
	return table.concat(out, ", ")
end

ns.on("PREVIEW_STARTED", function(records)
	for _, record in ipairs(records) do
		if record.result == "clamped" then
			ns.print(string.format("The game adjusted %s: asked for %s, got %s.",
				label(record.cvar), tostring(record.requested), tostring(record.actual)))
		end
	end
end)

local endMessages = {
	keep = "Settings kept.",
	manual = "Test reverted.",
	slash = "Test reverted.",
	timeout = "Time ran out, so the test was reverted.",
}

ns.on("PREVIEW_ENDED", function(reason, records, skipped)
	if endMessages[reason] then
		ns.print(endMessages[reason])
	end
	if skipped and #skipped > 0 then
		ns.print("Left these alone because something else changed them during the test: " .. names(skipped) .. ".")
	end
	local failed = {}
	for _, record in ipairs(ns.Preview.failures(records)) do
		table.insert(failed, record.cvar)
	end
	if #failed > 0 then
		ns.print("Could not put these back: " .. names(failed) .. ". Run /fgt diag.")
	end
end)

ns.on("PREVIEW_FAILED", function(message)
	ns.print(message)
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "CVAR_UPDATE" }) do
	-- Event names can differ between client builds. Skip any the client rejects.
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		local db = ns.api.db()
		db.loads = (db.loads or 0) + 1
		ns.SettingsEntry.register()
	elseif event == "PLAYER_LOGOUT" then
		-- Also fires on /reload. Leaves the pre-test values in Config.wtf.
		ns.Preview.revert("logout")
	elseif event == "CVAR_UPDATE" then
		ns.emit("LIVE_CHANGED", ...)
	end
end)

local help = {
	"/fgt  open or close the window",
	"/fgt diag  print a read-only compatibility report",
	"/fgt revert  end a running test and put the old values back",
}

SLASH_FOREVERGRAPHICSTWEAKS1 = "/fgt"
SlashCmdList.FOREVERGRAPHICSTWEAKS = function(msg)
	local command = (msg or ""):match("^%s*(.-)%s*$"):lower()
	if command == "" then
		ns.MainWindow.toggle()
	elseif command == "diag" then
		for _, line in ipairs(ns.Diagnostics.lines()) do
			ns.print(line)
		end
	elseif command == "revert" then
		if not ns.Preview.revert("slash") then
			ns.print("No test is running.")
		end
	else
		for _, line in ipairs(help) do
			ns.print(line)
		end
	end
end
