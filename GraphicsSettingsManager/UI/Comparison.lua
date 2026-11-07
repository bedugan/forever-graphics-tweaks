-- Low / Medium / High comparison panel. Shows a packaged screenshot when the
-- manifest has one, otherwise a schematic drawn from color textures and lines.
local _, ns = ...

local W = ns.Widgets
local Comparison = {}
ns.Comparison = Comparison

local SCHEMATIC = "Schematic illustration, not an in-game screenshot."
local LEVELS = ns.Levels.order
local LEVEL_LABELS = ns.Levels.labels

local SKY = { 0.32, 0.45, 0.62 }
local GROUND = { 0.22, 0.32, 0.16 }
local GRASS = { 0.45, 0.75, 0.3 }
local MARK = { 1, 0.35, 0.3 }

-- Deterministic pseudo-random numbers so drawings do not flicker.
local function rng(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local Canvas = {}
Canvas.__index = Canvas

function Canvas:reset()
	for _, pool in pairs(self.pools) do
		for i = 1, pool.used do
			pool.items[i]:Hide()
		end
		pool.used = 0
	end
	for _, label in ipairs(self.labels) do
		label:Hide()
	end
	self.labelsUsed = 0
end

function Canvas:acquire(kind, layer)
	local key = kind .. layer
	local pool = self.pools[key]
	if not pool then
		pool = { items = {}, used = 0 }
		self.pools[key] = pool
	end
	pool.used = pool.used + 1
	local item = pool.items[pool.used]
	if not item then
		if kind == "line" then
			item = self.frame:CreateLine(nil, layer)
		else
			item = self.frame:CreateTexture(nil, layer)
		end
		pool.items[pool.used] = item
	end
	item:Show()
	return item
end

-- Rectangle from bottom-left corner, in canvas pixels.
function Canvas:rect(x, y, w, h, color, alpha, layer)
	local tex = self:acquire("tex", layer or "ARTWORK")
	tex:ClearAllPoints()
	tex:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	tex:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, y)
	tex:SetSize(math.max(1, w), math.max(1, h))
	return tex
end

function Canvas:line(x1, y1, x2, y2, color, thickness, alpha, layer)
	local line = self:acquire("line", layer or "ARTWORK")
	line:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	line:SetThickness(thickness or 2)
	line:SetStartPoint("BOTTOMLEFT", self.frame, x1, y1)
	line:SetEndPoint("BOTTOMLEFT", self.frame, x2, y2)
	return line
end

function Canvas:label(text, x, y, color)
	self.labelsUsed = self.labelsUsed + 1
	local fs = self.labels[self.labelsUsed]
	if not fs then
		fs = W.text(self.frame, "GameFontHighlightSmall")
		self.labels[self.labelsUsed] = fs
	end
	fs:ClearAllPoints()
	fs:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, y)
	fs:SetText(text)
	color = color or MARK
	fs:SetTextColor(color[1], color[2], color[3])
	fs:Show()
	return fs
end

-- Labeled arrow pointing at (x, y) from a label position.
function Canvas:callout(text, lx, ly, x, y)
	self:line(lx, ly, x, y, MARK, 2, 1, "OVERLAY")
	self:rect(x - 3, y - 3, 6, 6, MARK, 1, "OVERLAY")
	self:label(text, lx + 4, ly - 6)
end

function Canvas:landscape(horizonFraction)
	local w, h = self.w, self.h
	local horizon = h * horizonFraction
	self:rect(0, horizon, w, h - horizon, SKY, 1, "BACKGROUND")
	self:rect(0, 0, w, horizon, GROUND, 1, "BACKGROUND")
	return horizon
end

-- t is 0 (low), 0.5 (medium), or 1 (high).
local drawers = {}

function drawers.density(c, t)
	local horizon = c:landscape(0.55)
	local random = rng(7)
	local count = ({ 14, 40, 90 })[t * 2 + 1]
	for _ = 1, count do
		local x, y = random() * (c.w - 10) + 5, random() * (horizon - 20) + 4
		local height = 8 + random() * 10
		c:line(x, y, x + (random() - 0.5) * 6, y + height, GRASS, 2)
	end
	c:callout(({ "Sparse grass", "Fuller grass", "Dense grass" })[t * 2 + 1], c.w - 120, c.h - 20, c.w * 0.6, horizon * 0.5)
end

function drawers.distance(c, t)
	local horizon = c:landscape(0.6)
	local random = rng(11)
	local limit = horizon * (0.3 + 0.55 * t)
	for _ = 1, 120 do
		local y = random() * horizon
		if y < limit then
			local x = random() * (c.w - 10) + 5
			local scale = 1 - y / horizon
			c:line(x, y, x, y + 4 + 12 * scale, GRASS, 1 + scale)
		end
	end
	c:line(0, limit, c.w, limit, MARK, 2, 0.9, "OVERLAY")
	c:label("Grass stops here", 8, limit + 4)
end

local function tree(c, x, y, scale, detailed)
	local trunk = { 0.35, 0.25, 0.15 }
	local crown = { 0.15, 0.45, 0.2 }
	c:rect(x - 2 * scale, y, 4 * scale, 10 * scale, trunk)
	if detailed then
		c:rect(x - 9 * scale, y + 8 * scale, 18 * scale, 8 * scale, crown)
		c:rect(x - 6 * scale, y + 15 * scale, 12 * scale, 7 * scale, crown)
		c:rect(x - 3 * scale, y + 21 * scale, 6 * scale, 5 * scale, crown)
	else
		c:rect(x - 7 * scale, y + 8 * scale, 14 * scale, 14 * scale, crown, 0.8)
	end
end

function drawers.lod(c, t)
	local horizon = c:landscape(0.45)
	local rows = 5
	local visible = ({ 2, 3, 5 })[t * 2 + 1]
	local detailedRows = ({ 1, 2, 4 })[t * 2 + 1]
	local farthest
	for row = 1, rows do
		local depth = (row - 1) / (rows - 1)
		local y = horizon * (1 - depth) * 0.85 + 4
		local scale = 1.6 - depth * 1.2
		if row <= visible then
			for i = 0, 4 do
				local x = 40 + i * (c.w - 80) / 4 + (row % 2) * 20
				tree(c, x, y, scale, row <= detailedRows)
			end
			farthest = y
		end
	end
	c:callout(({ "Distant trees hidden", "More trees stay visible", "Distant trees keep detail" })[t * 2 + 1],
		c.w - 170, c.h - 18, c.w * 0.5, farthest + 10)
end

function drawers.terrain(c, t)
	local w, h = c.w, c.h
	c:rect(0, 0, w, h, SKY, 1, "BACKGROUND")
	local segments = ({ 4, 9, 22 })[t * 2 + 1]
	local function height(x)
		local f = x / w
		return h * (0.35 + 0.18 * math.sin(f * 7) + 0.1 * math.sin(f * 19 + 1) + 0.05 * math.sin(f * 41))
	end
	local px, py = 0, height(0)
	for i = 1, segments do
		local x = w * i / segments
		local y = height(x)
		c:line(px, py, x, y, { 0.55, 0.42, 0.3 }, 3)
		px, py = x, y
	end
	c:rect(0, 0, w, h * 0.12, GROUND, 1, "BORDER")
	c:callout(({ "Hills look blocky", "Some shape returns", "Ridges keep their shape" })[t * 2 + 1],
		12, h - 18, w * 0.35, height(w * 0.35))
end

function drawers.clarity(c, t)
	local contrast = 0.25 + 0.75 * t
	local cols, rows = 12, 6
	local size = math.min(c.w / cols, (c.h - 10) / rows)
	local ox = (c.w - cols * size) / 2
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local light = ((row + col) % 2 == 0) and 1 or -1
			local v = 0.45 + 0.3 * contrast * light
			c:rect(ox + col * size, 5 + row * size, size, size, { v, v * 0.95, v * 0.85 })
		end
	end
	if t == 1 then
		c:callout("Crisp edges", c.w - 110, c.h - 16, ox + size * 6, 5 + size * 3)
	else
		c:callout(t == 0 and "Soft, blurry edges" or "Clearer edges", c.w - 130, c.h - 16, ox + size * 6, 5 + size * 3)
	end
end

function drawers.filtering(c, t)
	local horizon = c:landscape(0.7)
	local rows = 10
	local sharpRows = ({ 3, 6, 9 })[t * 2 + 1]
	local y = 0
	for row = 1, rows do
		local rowHeight = (horizon / 3) * (0.78 ^ (row - 1))
		local cols = 6 + row * 3
		local width = c.w / cols
		for col = 0, cols - 1 do
			local v
			if row <= sharpRows then
				v = ((row + col) % 2 == 0) and 0.62 or 0.3
			else
				v = 0.46
			end
			c:rect(col * width, y, width, rowHeight, { v * 0.8, v, v * 0.6 })
		end
		y = y + rowHeight
	end
	local blurStart = 0
	for row = 1, sharpRows do
		blurStart = blurStart + (horizon / 3) * (0.78 ^ (row - 1))
	end
	c:callout("Texture blurs from here", c.w - 160, c.h - 16, c.w * 0.5, math.min(blurStart, horizon - 4))
end

function drawers.reflection(c, t)
	local w, h = c.w, c.h
	local shore = h * 0.5
	c:rect(0, shore, w, h - shore, SKY, 1, "BACKGROUND")
	c:rect(0, 0, w, shore, { 0.12, 0.25, 0.4 }, 1, "BACKGROUND")
	tree(c, w * 0.3, shore, 1.6, true)
	tree(c, w * 0.62, shore, 1.2, true)
	local alpha = ({ 0, 0.35, 0.75 })[t * 2 + 1]
	if alpha > 0 then
		c:rect(w * 0.3 - 14, shore - 42, 28, 34, { 0.15, 0.4, 0.25 }, alpha)
		c:rect(w * 0.62 - 11, shore - 32, 22, 26, { 0.15, 0.4, 0.25 }, alpha)
	end
	c:callout(({ "No world reflection", "Faint reflection", "Clear reflection" })[t * 2 + 1], w - 140, 30, w * 0.3, shore - 24)
end

function drawers.shadows(c, t)
	local horizon = c:landscape(0.55)
	local sharp = ({ 1, 2, 4 })[t * 2 + 1]
	for i = 1, 4 do
		local depth = (i - 1) / 4
		local x = 40 + (i - 1) * (c.w - 80) / 3
		local y = horizon * (1 - depth) * 0.75 + 4
		local scale = 1.4 - depth
		c:rect(x - 3 * scale, y, 6 * scale, 26 * scale, { 0.6, 0.55, 0.5 })
		if i <= sharp then
			c:rect(x + 3 * scale, y - 2, 26 * scale, 5 * scale, { 0, 0, 0 }, 0.7, "BORDER")
		else
			c:rect(x + 1 * scale, y - 5, 34 * scale, 10 * scale, { 0, 0, 0 }, 0.25, "BORDER")
		end
	end
	c:callout(t == 1 and "Far shadows stay sharp" or "Far shadows blur", c.w - 160, c.h - 16, c.w - 40, horizon * 0.3)
end

function drawers.weather(c, t)
	c:landscape(0.4)
	local random = rng(23)
	local count = ({ 10, 35, 80 })[t * 2 + 1]
	for _ = 1, count do
		local x, y = random() * c.w, random() * c.h
		c:line(x, y, x - 4, y - 12, { 0.75, 0.85, 1 }, 1, 0.8)
	end
	c:label(({ "Light rain", "Moderate rain", "Heavy rain" })[t * 2 + 1], 10, c.h - 16, { 1, 1, 1 })
end

-- Outlines the area a screenshot's change is in. focus is { x, y, w, h }
-- as fractions of the shown image, measured from its top-left corner.
local function outline(c, focus)
	local x, w = focus[1] * c.w, focus[3] * c.w
	local h = focus[4] * c.h
	local y = c.h - focus[2] * c.h - h
	c:rect(x, y, w, 2, MARK, 1, "OVERLAY")
	c:rect(x, y + h - 2, w, 2, MARK, 1, "OVERLAY")
	c:rect(x, y, 2, h, MARK, 1, "OVERLAY")
	c:rect(x + w - 2, y, 2, h, MARK, 1, "OVERLAY")
end

-- Builds the panel. Returns an object with :show(setting, value).
function Comparison.create(parent, width, height)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetSize(width, height)

	local tabs = {}
	local self = { panel = panel, level = "medium" }

	local canvasFrame = CreateFrame("Frame", nil, panel)
	canvasFrame:SetPoint("TOPLEFT", 0, -26)
	canvasFrame:SetSize(width, height - 26 - 34)
	canvasFrame:SetClipsChildren(true)
	local canvas = setmetatable({
		frame = canvasFrame, w = width, h = height - 60, pools = {}, labels = {}, labelsUsed = 0,
	}, Canvas)

	local image = canvasFrame:CreateTexture(nil, "ARTWORK")
	image:SetAllPoints()
	image:Hide()

	local caption = W.text(panel, "GameFontDisableSmall")
	caption:SetPoint("TOPLEFT", canvasFrame, "BOTTOMLEFT", 0, -4)
	caption:SetWidth(width)

	local example = W.text(panel, "GameFontHighlightSmall")
	example:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -2)
	example:SetWidth(width)

	function self:render()
		local setting = self.setting
		if not setting then
			return
		end
		for _, key in ipairs(LEVELS) do
			if key == self.level then
				tabs[key]:LockHighlight()
			else
				tabs[key]:UnlockHighlight()
			end
		end
		canvas:reset()
		local shots = ns.Manifest[setting.cvar]
		local path = shots and shots[self.level]
		local shown = shots and shots.values and shots.values[self.level]
		if path then
			image:SetTexture(path)
			image:SetTexCoord(unpack(shots.coords or { 0, 1, 0, 1 }))
			image:Show()
			if shots.focus then
				outline(canvas, shots.focus)
			end
			caption:SetText("In-game screenshot" .. (shots.build and (", build " .. shots.build) or "") .. ". " .. (shots.note or ""))
		else
			image:Hide()
			local draw = drawers[setting.visual] or drawers.density
			draw(canvas, ns.Levels.position(self.level))
			caption:SetText(SCHEMATIC)
		end
		local value = shown or ns.Levels.value(setting, self.level)
		example:SetText(LEVEL_LABELS[self.level] .. (shown and " in this shot: " or " example: ") .. W.formatValue(setting, value))
	end

	for i, key in ipairs(LEVELS) do
		local tab = W.button(panel, LEVEL_LABELS[key], 80, function()
			self.level = key
			self:render()
		end)
		tab:SetPoint("TOPLEFT", (i - 1) * 84, 0)
		tabs[key] = tab
	end

	function self:show(setting, value)
		self.setting = setting
		self.level = ns.Levels.nearest(setting, value)
		self:render()
	end

	return self
end

Comparison.drawers = drawers
Comparison.SCHEMATIC = SCHEMATIC
