-- A single confirm dialog owned by GSM. Avoids StaticPopup so GSM never
-- shares a Blizzard dialog frame.
local _, ns = ...

local W = ns.Widgets
local Dialogs = {}
ns.Dialogs = Dialogs

local frame, pending

local function finish(accepted)
	local current = pending
	pending = nil
	frame:Hide()
	if current then
		local fn = accepted and current.onAccept or current.onCancel
		if fn then
			fn()
		end
	end
end

local function build()
	frame = CreateFrame("Frame", "GraphicsSettingsManagerConfirm", UIParent, "BackdropTemplate")
	frame:SetSize(380, 150)
	frame:SetPoint("CENTER", 0, 120)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	if BACKDROP_DIALOG_32_32 then
		frame:SetBackdrop(BACKDROP_DIALOG_32_32)
	else
		W.fill(frame, 0.08, 0.08, 0.12, 0.95)
	end

	frame.title = W.text(frame, "GameFontNormalLarge")
	frame.title:SetPoint("TOP", 0, -20)
	frame.title:SetJustifyH("CENTER")

	frame.body = W.text(frame, "GameFontHighlight")
	frame.body:SetPoint("TOPLEFT", 24, -46)
	frame.body:SetPoint("TOPRIGHT", -24, -46)
	frame.body:SetJustifyH("CENTER")
	frame.body:SetSpacing(2)

	frame.accept = W.button(frame, "OK", 130, function() finish(true) end)
	frame.accept:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -6, 18)
	frame.cancel = W.button(frame, "Cancel", 130, function() finish(false) end)
	frame.cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 6, 18)

	-- Esc closes it, which counts as Cancel.
	tinsert(UISpecialFrames, frame:GetName())
	frame:SetScript("OnHide", function()
		if pending then
			finish(false)
		end
	end)
	frame:Hide()
end

-- opts: title, text, accept, cancel, onAccept, onCancel.
function Dialogs.confirm(opts)
	if not frame then
		build()
	end
	if pending then
		finish(false)
	end
	pending = opts
	frame.title:SetText(opts.title)
	frame.body:SetText(opts.text)
	frame.accept:SetText(opts.accept or "OK")
	frame.cancel:SetText(opts.cancel or "Cancel")
	frame:SetHeight(math.max(150, frame.body:GetStringHeight() + 110))
	frame:Show()
end

function Dialogs.hide()
	if frame and frame:IsShown() then
		finish(false)
	end
end
