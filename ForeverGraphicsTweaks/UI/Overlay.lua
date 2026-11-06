-- The 15 second Keep / Revert overlay. It lives on UIParent, apart from the
-- main window and the Blizzard Settings panel, so it stays up when they hide.
-- The countdown runs on a separate unparented frame, so hiding the UI with
-- Alt+Z still lets the timeout revert.
local _, ns = ...

local W = ns.Widgets
local Overlay = {}
ns.Overlay = Overlay

local frame

local function inCombat()
	return ns.api.inCombat()
end

-- Keep everything except our keys flowing to the game. The propagate call
-- is restricted in combat, so in combat only the mouse works.
local function setPropagate(value)
	if not inCombat() then
		pcall(frame.SetPropagateKeyboardInput, frame, value)
	end
end

local KEEP_KEYS = { ENTER = true, NUMPADENTER = true, PAD1 = true }
local REVERT_KEYS = { ESCAPE = true, PAD2 = true }

local function onKey(_, key)
	if inCombat() then
		return
	end
	if KEEP_KEYS[key] then
		setPropagate(false)
		ns.Preview.keep()
	elseif REVERT_KEYS[key] then
		setPropagate(false)
		ns.Preview.revert("manual")
	end
end

local function summary(records)
	local changed, adjusted, delayed = 0, 0, false
	for _, record in ipairs(records or {}) do
		changed = changed + 1
		if record.result == "clamped" then
			adjusted = adjusted + 1
		end
		local setting = ns.SettingsByKey[record.cvar]
		if setting and setting.timing == "delayed" then
			delayed = true
		end
	end
	local text = changed == 1 and "1 setting applied." or (changed .. " settings applied.")
	if adjusted > 0 then
		text = text .. " " .. W.hex(W.colors.impact.medium) .. adjusted .. " adjusted by the game.|r"
	end
	if delayed then
		text = text .. "\nSome changes appear as new terrain loads. Turn the camera or move a little."
	end
	return text
end

local function build()
	frame = CreateFrame("Frame", "ForeverGraphicsTweaksOverlay", UIParent, "BackdropTemplate")
	frame:SetSize(320, 150)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	if BACKDROP_DARK_DIALOG_32_32 then
		frame:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
	else
		W.fill(frame, 0.05, 0.06, 0.1, 0.92)
	end
	W.rememberPosition(frame, "overlay", { "TOP", UIParent, "TOP", 0, -120 })

	frame.title = W.text(frame, "GameFontNormal", "Keep these graphics settings?")
	frame.title:SetPoint("TOP", 0, -18)

	frame.countdown = W.text(frame, "GameFontNormalHuge")
	frame.countdown:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)

	frame.detail = W.text(frame, "GameFontHighlightSmall")
	frame.detail:SetPoint("TOPLEFT", 20, -66)
	frame.detail:SetPoint("TOPRIGHT", -20, -66)
	frame.detail:SetJustifyH("CENTER")

	frame.keep = W.button(frame, "Keep settings", 130, function() ns.Preview.keep() end)
	frame.keep:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -6, 18)
	W.tooltip(frame.keep, "Keep settings", "Enter or gamepad A.")
	frame.revert = W.button(frame, "Revert", 130, function() ns.Preview.revert("manual") end)
	frame.revert:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 6, 18)
	W.tooltip(frame.revert, "Revert", "Esc or gamepad B. Puts back the values from just before the test.")

	frame:SetScript("OnKeyDown", onKey)
	frame:SetScript("OnGamePadButtonDown", onKey)
	frame:Hide()
end

-- Drives the countdown. Not parented to UIParent.
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
	ns.Preview.tick()
	if frame and ns.Preview.isActive() then
		frame.countdown:SetText(string.format("%d", math.ceil(ns.Preview.remaining())))
	end
end)

ns.on("PREVIEW_STARTED", function(records)
	if not frame then
		build()
	end
	frame.detail:SetText(summary(records))
	frame.countdown:SetText(string.format("%d", math.ceil(ns.Preview.remaining())))
	frame:Show()
	if not inCombat() then
		pcall(frame.EnableKeyboard, frame, true)
		pcall(frame.EnableGamePadButton, frame, true)
		setPropagate(true)
	end
	driver:Show()
end)

local REOPEN = { manual = true, timeout = true, slash = true }

ns.on("PREVIEW_ENDED", function(reason)
	driver:Hide()
	if frame then
		frame:Hide()
		if not inCombat() then
			pcall(frame.EnableKeyboard, frame, false)
			pcall(frame.EnableGamePadButton, frame, false)
		end
	end
	if REOPEN[reason] then
		ns.MainWindow.show()
	end
end)

function Overlay.frame()
	return frame
end
