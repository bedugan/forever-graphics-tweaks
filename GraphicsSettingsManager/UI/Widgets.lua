-- Small frame helpers built on Blizzard templates.
local _, ns = ...

local W = {}
ns.Widgets = W

W.colors = {
	impact = { low = { 0.45, 0.9, 0.45 }, medium = { 1, 0.82, 0.25 }, high = { 1, 0.45, 0.3 } },
	experience = { classic = { 1, 0.72, 0.25 }, enhanced = { 0.35, 0.85, 0.95 }, unknown = { 0.7, 0.7, 0.75 } },
	pending = { 0.45, 0.95, 0.55 },
	muted = { 0.55, 0.55, 0.6 },
	error = { 1, 0.4, 0.35 },
	info = { 0.85, 0.85, 0.9 },
}

function W.hex(color)
	return string.format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

function W.text(parent, font, text, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if text then
		fs:SetText(text)
	end
	return fs
end

function W.button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 120, 22)
	button:SetText(text)
	if onClick then
		button:SetScript("OnClick", onClick)
	end
	return button
end

function W.fill(parent, r, g, b, a, layer)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetColorTexture(r, g, b, a or 1)
	tex:SetAllPoints()
	return tex
end

function W.tooltip(frame, title, body)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(type(title) == "function" and title() or title, 1, 1, 1)
		local text = type(body) == "function" and body() or body
		if text then
			GameTooltip:AddLine(text, nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function W.slider(parent, width)
	local slider = CreateFrame("Slider", nil, parent, "UISliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(width, 17)
	slider:SetObeyStepOnDrag(true)
	return slider
end

function W.check(parent)
	return CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
end

-- Text for a CVar value as the user should read it.
function W.formatValue(setting, value)
	if value == nil then
		return "n/a"
	end
	if setting.kind == "toggle" then
		return value == 1 and "On" or "Off"
	end
	if setting.kind == "choice" then
		return setting.choices[value - setting.min + 1] or tostring(value)
	end
	value = value + (setting.format or 0)
	if setting.step < 1 then
		return string.format("%.1f", value)
	end
	return string.format("%d", value)
end

function W.impactText(setting)
	local color = W.colors.impact[setting.impact]
	return W.hex(color) .. setting.impact:gsub("^%l", string.upper) .. "|r"
end

W.timingText = {
	immediate = "Right away",
	delayed = "As new terrain loads. Move the camera or travel a short way to see it.",
}

function W.experienceText(state)
	local labels = { classic = "Classic", enhanced = "Enhanced", unknown = "Unknown" }
	return W.hex(W.colors.experience[state]) .. labels[state] .. "|r"
end

-- Saves and restores a frame's position in SavedVariables.
function W.rememberPosition(frame, key, default)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint()
		ns.api.db().ui[key] = { point, relativePoint, x, y }
	end)
	local saved = ns.api.db().ui[key]
	frame:ClearAllPoints()
	if saved then
		frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
	else
		frame:SetPoint(unpack(default))
	end
end
