-- Loads every file in TOC order against a permissive fake frame API and
-- drives the main flows by clicking buttons. This checks wiring and state,
-- not layout or looks. Only the real client can check those.

local frames

local noop = function() end
local Widget = {}
local mt = {
	-- Unknown client methods (capitalized) are no-ops. Plain fields stay nil.
	__index = function(_, key)
		return Widget[key] or (key:find("^%u") and noop) or nil
	end,
}

local function widget(kind, name, parent)
	local w = setmetatable({ kind = kind, name = name, parent = parent, shown = true,
		scripts = {}, events = {}, enabled = true, value = 0, min = 0, max = 1 }, mt)
	table.insert(frames, w)
	if name then
		_G[name] = w
	end
	return w
end

function Widget:Show()
	if not self.shown then
		self.shown = true
		self:fire("OnShow")
	end
end
function Widget:Hide()
	if self.shown then
		self.shown = false
		self:fire("OnHide")
	end
end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown end
function Widget:SetShown(show) if show then self:Show() else self:Hide() end end
function Widget:SetScript(event, fn) self.scripts[event] = fn end
function Widget:GetScript(event) return self.scripts[event] end
function Widget:fire(event, ...)
	local fn = self.scripts[event]
	if fn then
		return fn(self, ...)
	end
end
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:GetName() return self.name end
function Widget:GetStringHeight() return 20 end
function Widget:GetVerticalScroll() return 0 end
function Widget:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Widget:SetEnabled(enabled) self.enabled = not not enabled end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:IsEnabled() return self.enabled end
function Widget:SetChecked(checked) self.checked = not not checked end
function Widget:GetChecked() return self.checked end
function Widget:SetMinMaxValues(min, max) self.min, self.max = min, max end
function Widget:SetValue(value)
	self.value = math.max(self.min, math.min(self.max, value))
	self:fire("OnValueChanged", self.value, false)
end
function Widget:GetValue() return self.value end
function Widget:CreateTexture() return widget("Texture", nil, self) end
function Widget:CreateFontString() return widget("FontString", nil, self) end
function Widget:CreateLine() return widget("Line", nil, self) end
-- Simulated user click. Disabled buttons ignore clicks, like the client.
function Widget:Click()
	if not self.enabled then
		return false
	end
	if self.kind == "CheckButton" then
		self.checked = not self.checked
	end
	self:fire("OnClick", "LeftButton")
	return true
end

local function visible(w)
	while w do
		if not w.shown then
			return false
		end
		w = w.parent
	end
	return true
end

local function find(text)
	for _, w in ipairs(frames) do
		if w.kind == "Button" and w.text == text and visible(w) then
			return w
		end
	end
	error("no visible button " .. text, 2)
end

local function fire(event, ...)
	for _, w in ipairs(frames) do
		if w.events[event] then
			w:fire("OnEvent", event, ...)
		end
	end
end

local function update()
	for _, w in ipairs(frames) do
		if w.shown and w.scripts.OnUpdate then
			w:fire("OnUpdate", 0.016)
		end
	end
end

local function tocFiles()
	local out = {}
	for line in io.lines(ROOT .. "/ForeverGraphicsTweaks/ForeverGraphicsTweaks.toc") do
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" and not line:find("^#") then
			table.insert(out, (line:gsub("\\", "/")))
		end
	end
	return out
end

local function newUI(opts)
	for _, w in ipairs(frames or {}) do
		if w.name then
			_G[w.name] = nil
		end
	end
	frames = {}
	opts = opts or {}
	UIParent = widget("Frame", "UIParent")
	GameTooltip = widget("GameTooltip", "GameTooltip")
	SettingsPanel = widget("Frame", "SettingsPanel")
	SettingsPanel.shown = false
	UISpecialFrames = {}
	SlashCmdList = {}
	tinsert = table.insert
	date = os.date
	HideUIPanel = function(f) f:Hide() end
	Settings = {
		RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name } end,
		RegisterAddOnCategory = function(category) Settings.registered = category end,
	}
	CreateFrame = function(kind, name, parent)
		return widget(kind, name, parent)
	end
	opts.files = tocFiles()
	local ns, env = newAddon(opts)
	fire("PLAYER_LOGIN")
	env.slash = SlashCmdList.FOREVERGRAPHICSTWEAKS
	return ns, env
end

local function window()
	return ForeverGraphicsTweaksFrame
end
local function overlay()
	return ForeverGraphicsTweaksOverlay
end

test("ui: TOC loads every file and login writes nothing", function()
	local ns, env = newUI()
	eq(#env.cvars.writes, 0)
	eq(env.db.loads, 1)
	eq(Settings.registered.name, "Forever Graphics Tweaks")
	truthy(ns.MainWindow and ns.Overlay and ns.Comparison and ns.SettingsEntry)
end)

test("ui: /fgt opens the window; presets stay pending", function()
	local ns, env = newUI()
	env.slash("")
	truthy(window():IsShown())
	eq(find("Test settings"):IsEnabled(), false, "nothing to test yet")
	find("Balanced"):Click()
	truthy(ns.Pending.count() > 0)
	eq(#env.cvars.writes, 0, "choosing a preset writes nothing")
	truthy(find("Test settings"):IsEnabled())
	env.slash("")
	eq(window():IsShown(), false, "/fgt toggles")
end)

test("ui: Test hides windows, overlay times out and reverts, window returns", function()
	local ns, env = newUI()
	env.slash("")
	SettingsPanel:Show()
	find("Ultra"):Click()
	local before = ns.CVarStore.readAll()
	find("Test settings"):Click()
	truthy(ns.Preview.isActive())
	eq(window():IsShown(), false)
	eq(SettingsPanel:IsShown(), false)
	truthy(overlay():IsShown())
	eq(env.cvars.value("graphicsViewDistance"), 9)

	env.t = env.t + 14
	update()
	truthy(ns.Preview.isActive())
	eq(overlay().countdown.text, "1")
	env.t = env.t + 1.1
	update()
	eq(ns.Preview.isActive(), false)
	eq(overlay():IsShown(), false)
	truthy(window():IsShown(), "revert reopens the window")
	for cvar, value in pairs(before) do
		eq(env.cvars.value(cvar), value, cvar)
	end
	truthy(ns.Pending.count() > 0, "pending edits survive a revert")
end)

test("ui: Keep commits and leaves the window closed", function()
	local ns, env = newUI()
	env.slash("")
	find("Balanced"):Click()
	find("Test settings"):Click()
	find("Keep settings"):Click()
	eq(ns.Preview.isActive(), false)
	eq(overlay():IsShown(), false)
	eq(window():IsShown(), false)
	eq(env.cvars.value("groundEffectDensity"), 64)
	eq(ns.Pending.count(), 0)
	env.t = env.t + 30
	update()
	eq(env.cvars.value("groundEffectDensity"), 64, "no revert after keep")
end)

test("ui: overlay keys and gamepad buttons", function()
	local ns, env = newUI()
	env.slash("")
	find("Balanced"):Click()
	find("Test settings"):Click()
	overlay():fire("OnKeyDown", "W")
	truthy(ns.Preview.isActive(), "other keys pass through")
	overlay():fire("OnKeyDown", "ESCAPE")
	eq(ns.Preview.isActive(), false)
	eq(env.cvars.value("groundEffectDensity"), 40)

	find("Test settings"):Click()
	overlay():fire("OnGamePadButtonDown", "PAD1")
	eq(ns.Preview.isActive(), false)
	eq(env.cvars.value("groundEffectDensity"), 64)
end)

test("ui: keys do nothing in combat; mouse still works", function()
	local ns, env = newUI()
	env.slash("")
	find("Balanced"):Click()
	find("Test settings"):Click()
	env.combat = true
	overlay():fire("OnKeyDown", "ENTER")
	truthy(ns.Preview.isActive())
	find("Revert"):Click()
	eq(ns.Preview.isActive(), false)
end)

test("ui: Classic warning blocks Test until Continue", function()
	local ns, env = newUI({ experience = 0 })
	env.slash("")
	find("Balanced"):Click()
	eq(find("Test settings"):IsEnabled(), false)
	find("Continue"):Click()
	truthy(find("Test settings"):IsEnabled())
	env.slash("")
	env.slash("")
	truthy(find("Test settings"):IsEnabled(), "warning shows once per session")
	eq(ns.Experience.needsWarning(), false)
end)

test("ui: Classic warning Cancel closes the window", function()
	local _, env = newUI({ experience = 0 })
	env.slash("")
	find("Cancel"):Click()
	eq(window():IsShown(), false)
end)

test("ui: Enhanced shows no warning", function()
	local _, env = newUI({ experience = 1 })
	env.slash("")
	local ok = pcall(find, "Continue")
	eq(ok, false)
end)

test("ui: window refuses combat and closes when combat starts", function()
	local _, env = newUI()
	env.combat = true
	env.slash("")
	eq(window(), nil, "never built in combat")
	env.combat = false
	env.slash("")
	truthy(window():IsShown())
	env.combat = true
	fire("PLAYER_REGEN_DISABLED")
	eq(window():IsShown(), false)
end)

test("ui: slider and arrow keys edit pending values only", function()
	local ns, env = newUI()
	env.slash("")
	ns.MainWindow.select("lodObjectCullSize")
	local detail = window()
	local slider
	for _, w in ipairs(frames) do
		if w.kind == "Slider" and visible(w) then
			slider = w
		end
	end
	slider:SetValue(30) -- far right on a reverse slider is the smallest cull size
	eq(ns.Pending.get("lodObjectCullSize"), 4)
	detail:fire("OnKeyDown", "LEFT")
	eq(ns.Pending.get("lodObjectCullSize"), 5)
	detail:fire("OnKeyDown", "DOWN")
	detail:fire("OnKeyDown", "RIGHT")
	eq(ns.Pending.get("terrainLodDist"), 425)
	eq(#env.cvars.writes, 0)
	find("Discard"):Click()
	eq(ns.Pending.count(), 0)
end)

test("ui: Restore original asks first, then restores the baseline", function()
	local ns, env = newUI()
	env.slash("")
	find("Ultra"):Click()
	find("Test settings"):Click()
	find("Keep settings"):Click()
	eq(env.cvars.value("reflectionMode"), 3)
	env.slash("")
	find("Restore original"):Click()
	truthy(ForeverGraphicsTweaksConfirm:IsShown())
	eq(env.cvars.value("reflectionMode"), 3, "nothing before confirming")
	ForeverGraphicsTweaksConfirm.accept:Click()
	eq(env.cvars.value("reflectionMode"), 0)
	eq(env.cvars.value("graphicsViewDistance"), 5)
end)

test("ui: profiles save, load into pending, and delete", function()
	local ns, env = newUI()
	env.slash("")
	find("Balanced"):Click()
	find("Profiles"):Click()
	local box
	for _, w in ipairs(frames) do
		if w.kind == "EditBox" then
			box = w
		end
	end
	box:SetText("SteamOS Ultra")
	find("Save"):Click()
	truthy(env.db.profiles["SteamOS Ultra"])
	find("Discard"):Click()
	find("Load"):Click()
	eq(ns.Pending.get("groundEffectDensity"), 64)
	eq(#env.cvars.writes, 0, "loading a profile writes nothing")
	find("Delete"):Click()
	truthy(env.db.profiles["SteamOS Ultra"], "nothing before confirming")
	ForeverGraphicsTweaksConfirm.accept:Click()
	eq(env.db.profiles["SteamOS Ultra"], nil)
end)

test("ui: logout during a test reverts", function()
	local ns, env = newUI()
	env.slash("")
	find("Ultra"):Click()
	find("Test settings"):Click()
	fire("PLAYER_LOGOUT")
	eq(ns.Preview.isActive(), false)
	eq(env.cvars.value("graphicsViewDistance"), 5)
end)

test("ui: Settings launcher hides Settings and opens the window", function()
	local _, env = newUI()
	SettingsPanel:Show()
	Settings.registered.frame:fire("OnShow")
	find("Open Forever Graphics Tweaks"):Click()
	eq(SettingsPanel:IsShown(), false)
	truthy(window():IsShown())
	eq(#env.cvars.writes, 0)
end)

test("ui: every comparison renders each level and labels schematics", function()
	local ns = newUI()
	ns.MainWindow.show()
	for _, setting in ipairs(ns.Settings) do
		ns.MainWindow.select(setting.cvar)
		for _, level in ipairs({ "Low", "Medium", "High" }) do
			find(level):Click()
		end
	end
	local labeled = false
	for _, w in ipairs(frames) do
		if w.kind == "FontString" and w.text == ns.Comparison.SCHEMATIC then
			labeled = true
		end
	end
	truthy(labeled)
end)

test("ui: missing CVars show as unavailable and cannot be edited", function()
	local ns, env = newUI({ missing = set({ "weatherDensity" }) })
	env.slash("")
	ns.MainWindow.select("weatherDensity")
	for _, w in ipairs(frames) do
		if w.kind == "Slider" and visible(w) then
			eq(w:IsEnabled(), false)
		end
	end
	find("Ultra"):Click()
	eq(ns.Pending.get("weatherDensity"), nil)
end)
