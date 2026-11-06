-- The entry under Settings > AddOns. A small launcher, because the main
-- window needs more room than a Settings canvas gives. See ADR 0001.
local _, ns = ...

local W = ns.Widgets
local SettingsEntry = {}
ns.SettingsEntry = SettingsEntry

local canvas

local function refresh()
	if not canvas then
		return
	end
	local experience, reason = ns.Experience.detect()
	local lines = {
		"Experience: " .. W.experienceText(experience) .. (reason and (" (" .. reason .. ")") or ""),
		ns.Preview.isActive() and "A test is running. Use the overlay to keep or revert it." or "No test running.",
		ns.Pending.count() .. " pending changes.",
	}
	canvas.status:SetText(table.concat(lines, "\n"))
end

local function open()
	if ns.api.inCombat() then
		ns.print("The FGT window is not available in combat.")
		return
	end
	-- Hide Settings first so the game world and the FGT window are not
	-- stacked behind it. Called from a click, out of combat.
	if SettingsPanel and SettingsPanel:IsShown() then
		pcall(HideUIPanel, SettingsPanel)
	end
	ns.MainWindow.show()
end

local function build()
	canvas = CreateFrame("Frame")
	local title = W.text(canvas, "GameFontNormalLarge", "Forever Graphics Tweaks")
	title:SetPoint("TOPLEFT", 16, -16)
	local body = W.text(canvas, "GameFontHighlight",
		"Graphics presets and individual settings, with a 15 second test before anything sticks. "
		.. "The controls open in their own window so you can see the game while you test.")
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	body:SetWidth(560)
	body:SetSpacing(2)

	local button = W.button(canvas, "Open Forever Graphics Tweaks", 240, open)
	button:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)

	local hint = W.text(canvas, "GameFontDisableSmall", "You can also type /fgt.")
	hint:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 2, -8)

	canvas.status = W.text(canvas, "GameFontHighlightSmall")
	canvas.status:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
	canvas.status:SetSpacing(3)

	canvas:SetScript("OnShow", refresh)
end

-- Called once at PLAYER_LOGIN. Registering a category writes no CVars.
function SettingsEntry.register()
	if canvas or not (Settings and Settings.RegisterCanvasLayoutCategory) then
		return
	end
	build()
	local category = Settings.RegisterCanvasLayoutCategory(canvas, "Forever Graphics Tweaks")
	Settings.RegisterAddOnCategory(category)
	SettingsEntry.category = category
end

for _, event in ipairs({ "PENDING_CHANGED", "PREVIEW_STARTED", "PREVIEW_ENDED" }) do
	ns.on(event, refresh)
end
