-- Caption band across the bottom of the screen, shown in each screenshot so
-- a person can tell the shots apart. It sits on WorldFrame, so it stays
-- visible when the rest of the interface is hidden. The import script crops
-- it off using fraction(). Knows nothing about GSM.
local _, ns = ...

local Band = {}
ns.Band = Band

Band.HEIGHT = 64
local GOLD = { 1, 0.82, 0.2 }
local TEXT = { 0.95, 0.95, 1 }
local MUTED = { 0.7, 0.74, 0.9 }

local function text(parent, font, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(color[1], color[2], color[3])
	return fs
end

-- cells: how many label/value pairs to the right of the title.
function Band.create(cells)
	local frame = CreateFrame("Frame", "GraphicsSettingsManagerCaptureBand", WorldFrame)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT")
	frame:SetPoint("BOTTOMRIGHT", WorldFrame, "BOTTOMRIGHT")
	frame:SetHeight(Band.HEIGHT)

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.06, 0.13, 0.9)
	local rule = frame:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT")
	rule:SetPoint("TOPRIGHT")
	rule:SetHeight(2)
	rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)

	local title = text(frame, "GameFontNormalLarge", TEXT)
	title:SetPoint("TOPLEFT", 16, -12)
	local subtitle = text(frame, "GameFontHighlightSmall", MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

	-- Title takes the left 30%. Cells share the rest.
	local slots = {}
	for i = 1, cells do
		local label = text(frame, "GameFontHighlightSmall", MUTED)
		label:SetPoint("TOPLEFT", frame, "TOP", 0, -12)
		local value = text(frame, "GameFontNormalLarge", TEXT)
		value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
		slots[i] = { label = label, value = value }
	end

	local function layout()
		local width = frame:GetWidth()
		local left = width * 0.3
		local each = (width - left - 16) / cells
		for i, slot in ipairs(slots) do
			slot.label:ClearAllPoints()
			slot.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left + (i - 1) * each, -12)
		end
	end
	frame:SetScript("OnSizeChanged", layout)

	local band = { frame = frame }

	-- content: { title, subtitle, cells = { { label, value, color } } }
	function band:set(content)
		layout()
		title:SetText(content.title or "")
		subtitle:SetText(content.subtitle or "")
		for i, slot in ipairs(slots) do
			local cell = content.cells and content.cells[i]
			slot.label:SetText(cell and cell.label or "")
			slot.value:SetText(cell and cell.value or "")
			local color = cell and cell.color or TEXT
			slot.value:SetTextColor(color[1], color[2], color[3])
		end
		frame:Show()
	end

	function band:hide()
		frame:Hide()
	end

	-- Band height as a fraction of the screen, for the import script.
	function band:fraction()
		local height = WorldFrame:GetHeight()
		if not height or height <= 0 then
			return nil
		end
		return frame:GetHeight() / height
	end

	frame:Hide()
	return band
end

Band.GOLD = GOLD
