-- Fishing & Cooking Encyclopedia - shared UI building blocks
--   W.CreateScroll(parent)  -> scroll frame + child, with mouse-wheel support
--   W.NewFlow(scroll)       -> top-down layout of pooled rows and wrapped text
--   W.ItemTooltip(id, extra) -> tooltip function showing the item plus AH prices

local _, ns = ...

local W = {}
ns.Widgets = W

local unpack = unpack or table.unpack -- WoW (5.1) global; table.unpack for offline tests

W.FACTION_COLORS = { A = "ff4f8fff", H = "ffe24a3b", N = "ffc9b27a" }
W.FACTION_NAMES = { A = "Alliance", H = "Horde", N = "Neutral" }

-- Alternating background styles for grouped rows (see the row-striping mock).
-- Pick with ns.db.settings.rowStyle = "A" | "B" | "C".
local function rgb(hex, a)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, a or 1 }
end
W.ROW_STYLES = {
	A = { odd = { bg = rgb("241e16", 0.95) }, even = {} },
	B = { odd = { bg = rgb("2a2216", 0.95), edge = rgb("b08a46") }, even = { bg = rgb("17140f", 0.95), edge = rgb("3a3022") } },
	C = { odd = { bg = rgb("1e2026", 0.95) }, even = { bg = rgb("1a160f", 0.95) } },
}

function W.RowStyle(index)
	local style = W.ROW_STYLES[ns.db.settings.rowStyle or "A"] or W.ROW_STYLES.A
	return (index % 2 == 1) and style.odd or style.even
end

local COLLAPSE_ICON = "Interface\\Buttons\\UI-MinusButton-Up"
local EXPAND_ICON = "Interface\\Buttons\\UI-PlusButton-Up"
function W.CollapseIcon(collapsed)
	return collapsed and EXPAND_ICON or COLLAPSE_ICON
end

function W.Color(hex, text)
	return "|c" .. hex .. tostring(text) .. "|r"
end

function W.PlayerFactionCode()
	local f = UnitFactionGroup("player")
	if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
	return "N"
end

local QUESTION_MARK = 134400 -- INV_Misc_QuestionMark

function W.ItemIcon(itemID)
	if not itemID then return QUESTION_MARK end
	local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
	return icon or QUESTION_MARK
end

-- Strips color codes so a line can be re-colored (used to dim rows).
function W.Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0

function W.AddPriceLines(tt, itemID)
	local p = itemID and ns.Prices:Get(itemID)
	if not p then
		tt:AddLine("No auction data yet. Scan at the auction house.", 0.6, 0.6, 0.6, true)
		return
	end
	tt:AddDoubleLine("AH lowest", ns.FormatMoney(p.min), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
	tt:AddDoubleLine("AH market", ns.FormatMoney(p.market), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
	if p.avgMarket then
		tt:AddDoubleLine("Average of recent scans", ns.FormatMoney(p.avgMarket), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
	end
	local listed = p.listed and tostring(p.quantity) or "none"
	tt:AddDoubleLine("Listed", listed .. " (" .. ns.FormatAge(p.age) .. ")", GOLD_R, GOLD_G, GOLD_B, 0.7, 0.7, 0.7)
end

function W.ItemTooltip(itemID, extra)
	return function(tt)
		if itemID then tt:SetItemByID(itemID) end
		tt:AddLine(" ")
		W.AddPriceLines(tt, itemID)
		if extra and extra ~= "" then
			tt:AddLine(" ")
			tt:AddLine(extra, 0.75, 0.75, 0.75, true)
		end
	end
end

function W.TextTooltip(title, ...)
	local lines = { ... }
	return function(tt)
		tt:SetText(title, 1, 1, 1)
		for _, l in ipairs(lines) do
			if l and l ~= "" then tt:AddLine(l, 0.8, 0.8, 0.8, true) end
		end
	end
end

---------------------------------------------------------------------------
-- Object pools
---------------------------------------------------------------------------

function W.NewPool(create)
	local pool = { free = {}, used = {} }
	function pool:Acquire(parent)
		local o = table.remove(self.free) or create(parent)
		o:SetParent(parent)
		o:ClearAllPoints()
		o:Show()
		self.used[#self.used + 1] = o
		return o
	end
	function pool:ReleaseAll()
		for i = #self.used, 1, -1 do
			local o = self.used[i]
			o:Hide()
			o:ClearAllPoints()
			self.free[#self.free + 1] = o
			self.used[i] = nil
		end
	end
	return pool
end

---------------------------------------------------------------------------
-- Row: one line with optional icon, left text (truncated) and right text.
---------------------------------------------------------------------------

local function createRow(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(18)

	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(1, 0.82, 0, 0.16)

	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(1, 1, 1, 0.07)

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(16, 16)
	b.icon:SetPoint("LEFT", 1, 0)

	b.right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.right:SetPoint("RIGHT", -2, 0)
	b.right:SetJustifyH("RIGHT")

	b.left = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.left:SetJustifyH("LEFT")
	b.left:SetWordWrap(false)

	b:SetScript("OnEnter", function(self)
		if not self.tooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		self.tooltip(GameTooltip, self)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self, button)
		if self.onClick then self.onClick(self, button) end
	end)
	return b
end

local function setupRow(r, o)
	if o.icon then
		r.icon:SetTexture(o.icon)
		r.icon:Show()
	else
		r.icon:Hide()
	end
	r.left:SetFontObject(o.font or "GameFontHighlightSmall")
	r.left:ClearAllPoints()
	if o.icon then
		r.left:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
	else
		r.left:SetPoint("LEFT", r, "LEFT", 2, 0)
	end
	r.left:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
	r.left:SetText(o.left or "")
	r.right:SetText(o.right or "")
	r.tooltip = o.tooltip
	r.onClick = o.onClick
	r.sel:SetShown(o.selected and true or false)
	r:EnableMouse(o.tooltip ~= nil or o.onClick ~= nil)
end

local function createText(parent)
	local f = CreateFrame("Frame", nil, parent)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("TOPLEFT")
	f.text:SetJustifyH("LEFT")
	f.text:SetJustifyV("TOP")
	f.text:SetWordWrap(true)
	return f
end

---------------------------------------------------------------------------
-- Scroll frame
---------------------------------------------------------------------------

function W.CreateScroll(parent)
	local scroll
	for _, template in ipairs({ "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" }) do
		local ok, f = pcall(CreateFrame, "ScrollFrame", nil, parent, template)
		if ok and f then scroll = f break end
	end
	scroll = scroll or CreateFrame("ScrollFrame", nil, parent)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll.child = child

	scroll:EnableMouseWheel(true)
	if not scroll:GetScript("OnMouseWheel") then
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange()
			local value = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40))
			self:SetVerticalScroll(value)
		end)
	end

	scroll:HookScript("OnSizeChanged", function(self, width)
		if width and width > 0 then child:SetWidth(width) end
		if self.onResize and not self.resizePending then
			self.resizePending = true
			C_Timer.After(0, function()
				self.resizePending = false
				self.onResize()
			end)
		end
	end)
	return scroll, child
end

function W.ScrollTo(scroll, y)
	C_Timer.After(0, function()
		local range = scroll:GetVerticalScrollRange() or 0
		scroll:SetVerticalScroll(math.max(0, math.min(range, y)))
	end)
end

---------------------------------------------------------------------------
-- Flow layout: stacks rows and text top-down inside a scroll child.
---------------------------------------------------------------------------

function W.NewFlow(scroll)
	local child = scroll.child
	local flow = {
		scroll = scroll,
		child = child,
		y = 0,
		rows = W.NewPool(createRow),
		texts = W.NewPool(createText),
	}

	flow.bands = W.NewPool(function(parent)
		local f = CreateFrame("Frame", nil, parent)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.edge = f:CreateTexture(nil, "BORDER")
		f.edge:SetPoint("TOPLEFT")
		f.edge:SetPoint("BOTTOMLEFT")
		f.edge:SetWidth(3)
		return f
	end)

	-- Paints a background band behind everything laid out since startY.
	-- style = { bg = {r,g,b,a} or nil, edge = {r,g,b,a} or nil }
	function flow:Band(startY, style)
		if not style or (not style.bg and not style.edge) then return end
		local band = self.bands:Acquire(self.child)
		band:SetFrameLevel(self.child:GetFrameLevel()) -- below rows and text
		band:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -startY)
		band:SetPoint("RIGHT", self.child, "RIGHT", 0, 0)
		band:SetHeight(math.max(1, self.y - startY))
		if style.bg then band.bg:SetColorTexture(unpack(style.bg)); band.bg:Show() else band.bg:Hide() end
		if style.edge then band.edge:SetColorTexture(unpack(style.edge)); band.edge:Show() else band.edge:Hide() end
	end

	function flow:Reset()
		self.rows:ReleaseAll()
		self.texts:ReleaseAll()
		self.bands:ReleaseAll()
		local w = self.scroll:GetWidth()
		if w and w > 0 then self.child:SetWidth(w) end
		self.y = 2
	end

	function flow:Space(h)
		self.y = self.y + (h or 6)
	end

	-- opts: font, indent, gap
	function flow:Text(str, opts)
		opts = opts or {}
		local indent = opts.indent or 0
		local line = self.texts:Acquire(self.child)
		line.text:SetFontObject(opts.font or "GameFontHighlightSmall")
		local w = math.max(60, self.child:GetWidth() - indent - 8)
		line.text:SetWidth(w)
		line.text:SetText(str or "")
		local h = math.max(1, line.text:GetStringHeight())
		line:SetSize(w, h)
		line:SetPoint("TOPLEFT", self.child, "TOPLEFT", indent, -self.y)
		self.y = self.y + h + (opts.gap or 3)
		return line
	end

	-- opts: icon, left, right, font, tooltip, onClick, selected, indent, height, gap
	function flow:Row(opts)
		local r = self.rows:Acquire(self.child)
		setupRow(r, opts)
		local h = opts.height or 18
		r:SetHeight(h)
		r:SetPoint("TOPLEFT", self.child, "TOPLEFT", opts.indent or 0, -self.y)
		r:SetPoint("RIGHT", self.child, "RIGHT", -4, 0)
		self.y = self.y + h + (opts.gap or 1)
		return r
	end

	function flow:Finish()
		self.child:SetHeight(math.max(1, self.y + 8))
		if self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end
	end

	return flow
end
