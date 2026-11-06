-- The FGT window: presets, the setting list, the detail pane with its
-- comparison panel, profiles, and the Test / Discard / Restore actions.
-- Nothing here writes a CVar except through Preview.start and
-- Profiles.restoreOriginal, both started by a click.
local _, ns = ...

local W = ns.Widgets
local Store = ns.CVarStore
local Pending = ns.Pending
local MainWindow = {}
ns.MainWindow = MainWindow

local WIDTH, HEIGHT = 880, 620
local LIST_WIDTH, ROW_HEIGHT = 410, 22
local DETAIL_X, DETAIL_WIDTH = 470, 390
local BODY_TOP, BODY_HEIGHT = -140, 420

local CLASSIC_WARNING = "You're using the Classic experience. Applying these graphical enhancements may change the original appearance of World of Warcraft. Your experience preset will not be changed."

local frame -- built on first show
local ui = {}
local selected = ns.Settings[1].cvar
local view = "detail" -- or "profiles"

local function available(cvar)
	return Store.status(cvar) == "available"
end

local function setStatus(text, isError)
	local color = isError and W.colors.error or W.colors.info
	ui.status:SetText(W.hex(color) .. (text or "") .. "|r")
end

-- Slider position <-> CVar value. Reverse settings flip, so right always
-- means more detail.
local function toSlider(setting, value)
	return setting.reverse and (setting.min + setting.max - value) or value
end
local fromSlider = toSlider

------------------------------------------------------------------------
-- Setting list

local function buildList()
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, BODY_TOP)
	scroll:SetSize(LIST_WIDTH, BODY_HEIGHT)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_WIDTH, 10)
	scroll:SetScrollChild(content)
	ui.scroll = scroll

	local heading = W.text(frame, "GameFontDisableSmall")
	heading:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", 6, 4)
	heading:SetText("Setting")
	for _, column in ipairs({ { "Current", 220 }, { "Pending", 290 }, { "Impact", 352 } }) do
		local fs = W.text(frame, "GameFontDisableSmall", column[1])
		fs:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", column[2], 4)
	end

	ui.rows = {}
	local y = 0
	for _, category in ipairs(ns.Categories) do
		local header = W.text(content, "GameFontNormal", category.label)
		header:SetPoint("TOPLEFT", 4, -y - 4)
		y = y + ROW_HEIGHT + 2
		for _, setting in ipairs(ns.Settings) do
			if setting.category == category.key then
				local row = CreateFrame("Button", nil, content)
				row:SetSize(LIST_WIDTH, ROW_HEIGHT)
				row:SetPoint("TOPLEFT", 0, -y)
				local highlight = row:CreateTexture(nil, "HIGHLIGHT")
				highlight:SetColorTexture(1, 1, 1, 0.08)
				highlight:SetAllPoints()
				row.selected = row:CreateTexture(nil, "BACKGROUND")
				row.selected:SetColorTexture(0.3, 0.55, 0.9, 0.25)
				row.selected:SetAllPoints()
				row.label = W.text(row, "GameFontHighlight")
				row.label:SetPoint("LEFT", 14, 0)
				row.label:SetWidth(200)
				row.label:SetWordWrap(false)
				row.current = W.text(row, "GameFontHighlightSmall")
				row.current:SetPoint("LEFT", 220, 0)
				row.current:SetWidth(66)
				row.current:SetWordWrap(false)
				row.pending = W.text(row, "GameFontHighlightSmall")
				row.pending:SetPoint("LEFT", 290, 0)
				row.pending:SetWidth(60)
				row.pending:SetWordWrap(false)
				row.impact = W.text(row, "GameFontHighlightSmall")
				row.impact:SetPoint("LEFT", 352, 0)
				row.setting = setting
				row.top = y
				row:SetScript("OnClick", function()
					MainWindow.select(setting.cvar)
				end)
				table.insert(ui.rows, row)
				y = y + ROW_HEIGHT
			end
		end
		y = y + 6
	end
	content:SetHeight(y)
end

local function refreshList()
	for _, row in ipairs(ui.rows) do
		local setting = row.setting
		local status = Store.status(setting.cvar)
		row.selected:SetShown(setting.cvar == selected)
		row.label:SetText(setting.label)
		if status ~= "available" then
			row.label:SetTextColor(unpack(W.colors.muted))
			row.current:SetText(W.hex(W.colors.muted) .. status .. "|r")
			row.pending:SetText("")
			row.impact:SetText("")
		else
			row.label:SetTextColor(1, 1, 1)
			row.current:SetText(W.formatValue(setting, Store.get(setting.cvar)))
			local pending = Pending.get(setting.cvar)
			row.pending:SetText(pending and (W.hex(W.colors.pending) .. W.formatValue(setting, pending) .. "|r") or "")
			row.impact:SetText(W.impactText(setting))
		end
	end
end

local function scrollTo(cvar)
	for _, row in ipairs(ui.rows) do
		if row.setting.cvar == cvar then
			local offset = ui.scroll:GetVerticalScroll()
			if row.top < offset then
				ui.scroll:SetVerticalScroll(row.top)
			elseif row.top + ROW_HEIGHT > offset + BODY_HEIGHT then
				ui.scroll:SetVerticalScroll(row.top + ROW_HEIGHT - BODY_HEIGHT)
			end
		end
	end
end

------------------------------------------------------------------------
-- Detail pane

local function buildDetail()
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetPoint("TOPLEFT", DETAIL_X, BODY_TOP)
	pane:SetSize(DETAIL_WIDTH, BODY_HEIGHT)
	ui.detail = pane

	pane.title = W.text(pane, "GameFontNormalLarge")
	pane.title:SetPoint("TOPLEFT")
	pane.summary = W.text(pane, "GameFontHighlight")
	pane.summary:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -6)
	pane.summary:SetWidth(DETAIL_WIDTH)
	pane.summary:SetSpacing(2)

	local controls = CreateFrame("Frame", nil, pane)
	controls:SetPoint("TOPLEFT", pane.summary, "BOTTOMLEFT", 0, -12)
	controls:SetSize(DETAIL_WIDTH, 30)
	pane.controls = controls

	pane.slider = W.slider(controls, 220)
	pane.slider:SetPoint("LEFT", 4, 0)
	pane.slider:SetScript("OnValueChanged", function(self, position)
		if ui.updating then
			return
		end
		local setting = ns.SettingsByKey[selected]
		Pending.set(selected, fromSlider(setting, position))
	end)

	pane.check = W.check(controls)
	pane.check:SetPoint("LEFT", 0, 0)
	pane.check:SetScript("OnClick", function(self)
		Pending.set(selected, self:GetChecked() and 1 or 0)
	end)

	pane.value = W.text(controls, "GameFontHighlight")
	pane.value:SetPoint("LEFT", 236, 0)
	pane.value:SetWidth(80)

	pane.useCurrent = W.button(controls, "Use current", 70, function()
		Pending.set(selected, Store.get(selected))
	end)
	pane.useCurrent:SetPoint("RIGHT")
	W.tooltip(pane.useCurrent, "Use current", "Drop the pending value for this setting.")

	pane.info = W.text(pane, "GameFontHighlightSmall")
	pane.info:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -10)
	pane.info:SetWidth(DETAIL_WIDTH)
	pane.info:SetSpacing(3)

	pane.comparison = ns.Comparison.create(pane, DETAIL_WIDTH, 200)
	pane.comparison.panel:SetPoint("BOTTOMLEFT")
end

local EVIDENCE = {
	source = "Blizzard UI source for this build",
	wiki = "warcraft.wiki.gg (Retail)",
}

local function refreshDetail()
	local pane = ui.detail
	local setting = ns.SettingsByKey[selected]
	local status = Store.status(setting.cvar)
	local live = Store.get(setting.cvar)
	local pending = Pending.get(setting.cvar)
	local value = pending or live

	pane.title:SetText(setting.label)
	pane.summary:SetText(setting.summary)

	local usable = status == "available" and not ns.Preview.isActive()
	ui.updating = true
	if setting.kind == "toggle" then
		pane.slider:Hide()
		pane.check:Show()
		pane.check:SetChecked(value == 1)
		pane.check:SetEnabled(usable)
	else
		pane.check:Hide()
		pane.slider:Show()
		pane.slider:SetMinMaxValues(setting.min, setting.max)
		pane.slider:SetValueStep(setting.step)
		if value then
			pane.slider:SetValue(toSlider(setting, value))
		end
		pane.slider:SetEnabled(usable)
	end
	ui.updating = false

	if status ~= "available" then
		pane.value:SetText(W.hex(W.colors.error) .. status .. "|r")
	elseif pending then
		pane.value:SetText(W.hex(W.colors.pending) .. W.formatValue(setting, pending) .. "|r")
	else
		pane.value:SetText(W.formatValue(setting, live))
	end
	pane.useCurrent:SetEnabled(usable and pending ~= nil)

	local baseline = ns.Profiles.baseline()
	local original = baseline and baseline.values[setting.cvar]
	local lines = {
		string.format("Range %s to %s. Current %s. Game default %s. Your original %s.",
			W.formatValue(setting, setting.min), W.formatValue(setting, setting.max),
			W.formatValue(setting, live), W.formatValue(setting, Store.default(setting.cvar)),
			original and W.formatValue(setting, original) or "not captured yet"),
		"Estimated impact: " .. W.impactText(setting) .. ". An estimate, not a measurement.",
		"Takes effect: " .. W.timingText[setting.timing],
		"Evidence: " .. EVIDENCE[setting.evidence] .. ". Not yet verified in game.",
	}
	if status ~= "available" then
		table.insert(lines, 1, W.hex(W.colors.error) .. "This setting is " .. status .. " on this client, so FGT will not change it.|r")
	end
	pane.info:SetText(table.concat(lines, "\n"))
	pane.comparison:show(setting, value)
end

------------------------------------------------------------------------
-- Profiles view

local MAX_PROFILE_ROWS = 10

local function saveProfile()
	local name = ui.profiles.name:GetText()
	local function save()
		local ok, message = ns.Profiles.save(name)
		setStatus(message, not ok)
		if ok then
			ui.profiles.name:SetText("")
			ui.profiles.name:ClearFocus()
		end
	end
	if ns.Profiles.validName(name) and ns.Profiles.exists(name) then
		ns.Dialogs.confirm({
			title = "Replace profile?",
			text = "A profile with this name already exists. Replace it?",
			accept = "Replace",
			onAccept = save,
		})
	else
		save()
	end
end

local function buildProfiles()
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetPoint("TOPLEFT", DETAIL_X, BODY_TOP)
	pane:SetSize(DETAIL_WIDTH, BODY_HEIGHT)
	pane:Hide()
	ui.profiles = pane

	local title = W.text(pane, "GameFontNormalLarge", "Profiles")
	title:SetPoint("TOPLEFT")
	local help = W.text(pane, "GameFontHighlight",
		"A profile stores every setting's pending value, or its current value when nothing is pending. Loading a profile only fills pending values. Nothing changes until you test.")
	help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	help:SetWidth(DETAIL_WIDTH)
	help:SetSpacing(2)

	pane.name = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
	pane.name:SetSize(240, 22)
	pane.name:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 6, -14)
	pane.name:SetAutoFocus(false)
	pane.name:SetMaxLetters(ns.Profiles.MAX_NAME)
	pane.name:SetScript("OnEnterPressed", saveProfile)
	pane.name:SetScript("OnEscapePressed", pane.name.ClearFocus)
	local save = W.button(pane, "Save", 90, saveProfile)
	save:SetPoint("LEFT", pane.name, "RIGHT", 10, 0)

	pane.rows = {}
	for i = 1, MAX_PROFILE_ROWS do
		local row = CreateFrame("Frame", nil, pane)
		row:SetSize(DETAIL_WIDTH, 24)
		row:SetPoint("TOPLEFT", pane.name, "BOTTOMLEFT", -6, -14 - (i - 1) * 26)
		row.label = W.text(row, "GameFontHighlight")
		row.label:SetPoint("LEFT", 4, 0)
		row.label:SetWidth(210)
		row.label:SetWordWrap(false)
		row.load = W.button(row, "Load", 70, function()
			local ok, message = ns.Profiles.load(row.profile)
			setStatus(message, not ok)
		end)
		row.load:SetPoint("RIGHT", -84, 0)
		row.delete = W.button(row, "Delete", 70, function()
			local name = row.profile
			ns.Dialogs.confirm({
				title = "Delete profile?",
				text = "Delete the profile " .. name .. "? This cannot be undone.",
				accept = "Delete",
				onAccept = function()
					ns.Profiles.delete(name)
					setStatus("Deleted " .. name .. ".")
				end,
			})
		end)
		row.delete:SetPoint("RIGHT", -6, 0)
		pane.rows[i] = row
	end
	pane.more = W.text(pane, "GameFontDisableSmall")
	pane.more:SetPoint("TOPLEFT", pane.rows[MAX_PROFILE_ROWS], "BOTTOMLEFT", 4, -4)
end

local function refreshProfiles()
	local pane = ui.profiles
	local names = ns.Profiles.list()
	for i, row in ipairs(pane.rows) do
		local name = names[i]
		row.profile = name
		row:SetShown(name ~= nil)
		if name then
			row.label:SetText(name)
		end
	end
	if #names == 0 then
		pane.more:SetText("No profiles yet.")
	elseif #names > MAX_PROFILE_ROWS then
		pane.more:SetText((#names - MAX_PROFILE_ROWS) .. " more not shown. Delete some to see them.")
	else
		pane.more:SetText("")
	end
end

------------------------------------------------------------------------
-- Header, presets, and footer

local function buildHeader()
	ui.experience = W.text(frame, "GameFontHighlight")
	ui.experience:SetPoint("TOPLEFT", 20, -32)
	local note = W.text(frame, "GameFontDisableSmall",
		"Version " .. ns.version .. " pre-release. Settings are not yet verified in game.")
	note:SetPoint("TOPRIGHT", -24, -34)

	local banner = CreateFrame("Frame", nil, frame)
	banner:SetPoint("TOPLEFT", 16, -52)
	banner:SetSize(WIDTH - 32, 46)
	local tint = W.colors.experience.classic
	W.fill(banner, tint[1], tint[2], tint[3], 0.15)
	banner.text = W.text(banner, "GameFontHighlight", CLASSIC_WARNING)
	banner.text:SetPoint("LEFT", 10, 0)
	banner.text:SetWidth(WIDTH - 32 - 220)
	local continue = W.button(banner, "Continue", 95, function()
		ns.Experience.acknowledge()
		MainWindow.refresh()
	end)
	continue:SetPoint("RIGHT", -110, 0)
	local cancel = W.button(banner, "Cancel", 95, function()
		MainWindow.hide()
	end)
	cancel:SetPoint("RIGHT", -8, 0)
	ui.banner = banner

	ui.intro = W.text(frame, "GameFontHighlight",
		"Pick a preset or adjust settings. Nothing changes until you click Test settings, and you get 15 seconds to keep or revert.")
	ui.intro:SetPoint("TOPLEFT", 26, -68)

	ui.presets = {}
	local label = W.text(frame, "GameFontNormal", "Preset")
	label:SetPoint("TOPLEFT", 20, -110)
	for i, preset in ipairs(ns.Presets) do
		local button = W.button(frame, preset.label, 100, function()
			Pending.applyPreset(preset.key)
			setStatus(preset.label .. " values are pending. Click Test settings to try them.")
		end)
		button:SetPoint("TOPLEFT", 74 + (i - 1) * 106, -106)
		W.tooltip(button, preset.label, preset.tip)
		ui.presets[preset.key] = button
	end
	ui.pendingCount = W.text(frame, "GameFontHighlight")
	ui.pendingCount:SetPoint("TOPLEFT", 74 + #ns.Presets * 106 + 10, -110)
end

local function test()
	-- PREVIEW_STARTED hides this window. Blizzard's panels are left alone
	-- during a test (ADR 0001).
	local ok, message = ns.Preview.start()
	if not ok then
		setStatus(message, true)
	end
end

local function restoreOriginal()
	local baseline = ns.Profiles.baseline()
	if not baseline then
		setStatus("Nothing to restore. FGT has not changed any settings yet.")
		return
	end
	ns.Dialogs.confirm({
		title = "Restore original settings?",
		text = "This puts back the graphics values you had before FGT first changed anything ("
			.. date("%Y-%m-%d %H:%M", baseline.captured)
			.. "). There is no countdown. Pending values are cleared.",
		accept = "Restore",
		onAccept = function()
			local ok, message = ns.Profiles.restoreOriginal()
			setStatus(message, not ok)
		end,
	})
end

local function buildFooter()
	ui.status = W.text(frame, "GameFontHighlightSmall")
	ui.status:SetPoint("BOTTOMLEFT", 22, 20)
	ui.status:SetWidth(380)
	ui.status:SetJustifyV("BOTTOM")

	ui.test = W.button(frame, "Test settings", 130, test)
	ui.test:SetPoint("BOTTOMRIGHT", -22, 16)
	W.tooltip(ui.test, "Test settings", "Apply the pending values for 15 seconds. Keep them or they revert. Enter key.")
	ui.discard = W.button(frame, "Discard", 90, function()
		Pending.clear()
		setStatus("Pending values discarded.")
	end)
	ui.discard:SetPoint("RIGHT", ui.test, "LEFT", -6, 0)
	W.tooltip(ui.discard, "Discard", "Drop all pending values. Live settings stay as they are.")
	ui.restore = W.button(frame, "Restore original", 130, restoreOriginal)
	ui.restore:SetPoint("RIGHT", ui.discard, "LEFT", -6, 0)
	W.tooltip(ui.restore, "Restore original", "Put back the values you had before FGT first changed anything. Asks first.")
	ui.profilesButton = W.button(frame, "Profiles", 90, function()
		view = view == "profiles" and "detail" or "profiles"
		MainWindow.refresh()
	end)
	ui.profilesButton:SetPoint("RIGHT", ui.restore, "LEFT", -6, 0)
end

------------------------------------------------------------------------
-- Keyboard and gamepad. Our keys stop at the window; the rest reach the game.

local function availableIndex(step)
	local index
	for i, setting in ipairs(ns.Settings) do
		if setting.cvar == selected then
			index = i
		end
	end
	for _ = 1, #ns.Settings do
		index = (index - 1 + step) % #ns.Settings + 1
		if available(ns.Settings[index].cvar) then
			return ns.Settings[index].cvar
		end
	end
	return selected
end

local function nudge(direction)
	local setting = ns.SettingsByKey[selected]
	local value = Pending.effective(selected)
	if not value or not available(selected) then
		return
	end
	if setting.reverse then
		direction = -direction
	end
	Pending.set(selected, value + direction * setting.step)
end

local KEYS = {
	UP = function() MainWindow.select(availableIndex(-1)) end,
	DOWN = function() MainWindow.select(availableIndex(1)) end,
	LEFT = function() nudge(-1) end,
	RIGHT = function() nudge(1) end,
	ENTER = function()
		if ui.test:IsEnabled() then
			test()
		end
	end,
}
KEYS.NUMPADENTER = KEYS.ENTER
KEYS.PADDUP, KEYS.PADDDOWN, KEYS.PADDLEFT, KEYS.PADDRIGHT, KEYS.PAD1 = KEYS.UP, KEYS.DOWN, KEYS.LEFT, KEYS.RIGHT, KEYS.ENTER
KEYS.PAD2 = function() MainWindow.hide() end

local function onKey(self, key)
	if ns.api.inCombat() then
		return
	end
	local handler = KEYS[key]
	pcall(self.SetPropagateKeyboardInput, self, handler == nil)
	if handler then
		handler()
	end
end

------------------------------------------------------------------------

local function build()
	frame = CreateFrame("Frame", "ForeverGraphicsTweaksFrame", UIParent, "DefaultPanelFlatTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetTitle("Forever Graphics Tweaks")
	W.rememberPosition(frame, "main", { "CENTER", UIParent, "CENTER", 0, 0 })
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 0, 0)
	tinsert(UISpecialFrames, frame:GetName())

	buildHeader()
	buildList()
	buildDetail()
	buildProfiles()
	buildFooter()

	pcall(frame.EnableKeyboard, frame, true)
	pcall(frame.EnableGamePadButton, frame, true)
	frame:SetScript("OnKeyDown", onKey)
	frame:SetScript("OnGamePadButtonDown", onKey)
	frame:SetScript("OnHide", function()
		ns.Dialogs.hide()
	end)
	frame:Hide()
end

function MainWindow.refresh()
	if not (frame and frame:IsShown()) then
		return
	end
	local experience, reason = ns.Experience.detect()
	ui.experience:SetText("Experience: " .. W.experienceText(experience)
		.. (reason and (W.hex(W.colors.muted) .. " (" .. reason .. ")|r") or ""))
	local warning = ns.Experience.needsWarning()
	ui.banner:SetShown(warning)
	ui.intro:SetShown(not warning)

	local active = Pending.activePreset()
	for key, button in pairs(ui.presets) do
		if key == active then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end
	ui.presets.custom:SetEnabled(active == "custom" or Pending.hasCustom())

	local count = Pending.count()
	ui.pendingCount:SetText(count == 0 and (W.hex(W.colors.muted) .. "No pending changes|r")
		or (W.hex(W.colors.pending) .. count .. (count == 1 and " pending change" or " pending changes") .. "|r"))
	ui.test:SetEnabled(count > 0 and not warning and not ns.Preview.isActive())
	ui.discard:SetEnabled(count > 0)
	ui.restore:SetEnabled(ns.Profiles.baseline() ~= nil)
	ui.profilesButton:SetText(view == "profiles" and "Settings" or "Profiles")

	refreshList()
	ui.detail:SetShown(view == "detail")
	ui.profiles:SetShown(view == "profiles")
	if view == "detail" then
		refreshDetail()
	else
		refreshProfiles()
	end
end

function MainWindow.select(cvar)
	selected = cvar
	view = "detail"
	scrollTo(cvar)
	MainWindow.refresh()
end

function MainWindow.show()
	if ns.api.inCombat() then
		ns.print("The FGT window is not available in combat.")
		return false
	end
	if ns.Preview.isActive() then
		ns.print("Finish the current test first. Use the Keep or Revert buttons, or /fgt revert.")
		return false
	end
	if not frame then
		build()
	end
	frame:Show()
	MainWindow.refresh()
	return true
end

function MainWindow.hide()
	if frame then
		frame:Hide()
	end
end

function MainWindow.toggle()
	if frame and frame:IsShown() then
		MainWindow.hide()
	else
		MainWindow.show()
	end
end

function MainWindow.isShown()
	return frame ~= nil and frame:IsShown()
end

for _, event in ipairs({ "PENDING_CHANGED", "LIVE_CHANGED", "PROFILES_CHANGED" }) do
	ns.on(event, MainWindow.refresh)
end
ns.on("PREVIEW_STARTED", MainWindow.hide)

-- Never hold keyboard focus in combat.
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", MainWindow.hide)
