-- Fishing & Cooking Encyclopedia - "Cooking Recipes" page
-- Every recipe that uses a fished ingredient, colored by difficulty for your
-- cooking skill, with reagents, cooked-dish AH price, and where to learn it.
-- Vendors for your faction (and neutral ones) are listed first; the other
-- faction's vendors are dimmed, or hidden with the filter checkbox.

local _, ns = ...
local W = ns.Widgets

local page = {}

local VENDORS_SHOWN = 3
local TOOLBAR_HEIGHT = 52     -- y of the filter line under the two toolbar rows
local LIST_TOP = 54           -- list top when no benefit filter is active
local LIST_TOP_FILTERED = 72  -- list top when the filter line is showing

local function cookingRank()
	return (ns.GetCookingSkill())
end

-- Recipe difficulty color: red = can't learn yet, then orange/yellow/green/gray.
local function difficultyHex(r, cook)
	local lv = r.levels
	if cook < (r.skill or 0) then return "ffff4040" end
	if not lv then return "ffffffff" end
	if cook < (lv[2] or 0) then return "ffff8040" end
	if cook < (lv[3] or 0) then return "ffffff00" end
	if cook < (lv[4] or 0) then return "ff40c040" end
	return "ff808080"
end

local function isKnown(r)
	return r.spellID and IsPlayerSpell and IsPlayerSpell(r.spellID) or false
end

local function matches(r, query)
	if not query or query == "" then return true end
	if r.name:lower():find(query, 1, true) then return true end
	for _, rg in ipairs(r.reagents or {}) do
		if ns.Data:GetItemName(rg[1]):lower():find(query, 1, true) then return true end
	end
	return false
end

local function vendorTooltip(s)
	local where = s.coords and ("%s (%.1f, %.1f)"):format(s.zone or "?", s.coords[1], s.coords[2]) or (s.zone or "?")
	return W.TextTooltip(s.npc or "Vendor",
		where,
		W.FACTION_NAMES[s.faction] or "",
		s.limited and "Limited supply: restocks over time." or nil)
end

---------------------------------------------------------------------------

function page:Build(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()

	local ok, search = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
	if not ok or not search then
		search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	end
	search:SetSize(190, 20)
	search:SetPoint("TOPLEFT", 8, -2)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function(box)
		local q = (box:GetText() or ""):lower()
		if q ~= self.query then
			self.query = q
			self:Refresh()
		end
	end)
	self.search = search

	local dropdown = self:CreateBenefitFilter(f)
	dropdown:SetPoint("LEFT", search, "RIGHT", 12, 0)

	-- Second toolbar row: Unknown-only and faction filters.
	local unknown = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	unknown:SetSize(22, 22)
	unknown:SetPoint("TOPLEFT", 2, -26)
	unknown:SetScript("OnClick", function(cb)
		ns.db.settings.cookingUnknownOnly = cb:GetChecked() and true or false
		self:Refresh()
	end)
	local unknownLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	unknownLabel:SetPoint("LEFT", unknown, "RIGHT", 2, 0)
	unknownLabel:SetText("Unknown recipes only")
	self.unknownCheck = unknown

	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetPoint("LEFT", unknownLabel, "RIGHT", 16, 0)
	check:SetScript("OnClick", function(cb)
		ns.db.settings.hideOtherFaction = cb:GetChecked() and true or false
		self:Refresh()
	end)
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText("Hide other faction's vendors")
	self.check = check

	local count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	count:SetPoint("TOPRIGHT", -26, -6)
	self.countText = count

	-- Third toolbar line: names the benefits being filtered on (only while one is selected).
	local filterText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	filterText:SetPoint("TOPLEFT", 8, -TOOLBAR_HEIGHT)
	filterText:SetPoint("TOPRIGHT", -26, -TOOLBAR_HEIGHT)
	filterText:SetJustifyH("LEFT")
	filterText:SetWordWrap(false)
	filterText:Hide()
	self.filterText = filterText

	local scroll = W.CreateScroll(f)
	scroll:SetPoint("TOPLEFT", 0, -LIST_TOP)
	self.listTop = LIST_TOP
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	scroll.onResize = function() if f:IsShown() then self:Refresh() end end
	self.scroll = scroll
	self.flow = W.NewFlow(scroll)
	self.expanded = {}
	return f
end

function page:Refresh()
	local flow = self.flow
	flow:Reset()
	self.check:SetChecked(ns.db.settings.hideOtherFaction and true or false)

	local cook = cookingRank()
	local me = W.PlayerFactionCode()
	local hideOther = ns.db.settings.hideOtherFaction

	self.unknownCheck:SetChecked(ns.db.settings.cookingUnknownOnly and true or false)
	self:UpdateBenefitFilterText()

	local list = {}
	for _, r in ipairs(ns.Data.recipes) do
		if self:PassesFilters(r) then list[#list + 1] = r end
	end
	table.sort(list, function(a, b)
		if (a.skill or 0) ~= (b.skill or 0) then return (a.skill or 0) < (b.skill or 0) end
		return a.name < b.name
	end)
	self.countText:SetText(("%d of %d recipes  -  your Cooking: %d"):format(#list, #ns.Data.recipes, cook))

	local focusY
	for i, r in ipairs(list) do
		if self.focus == r.name then focusY = flow.y end
		local top = flow.y
		flow:Space(4)
		self:RenderRecipe(r, cook, me, hideOther)
		flow:Space(4)
		flow:Band(top, W.RowStyle(i)) -- alternating background per recipe
	end
	if #list == 0 then
		flow:Text("|cff808080No recipes match your search.|r", { font = "GameFontDisable" })
	end
	flow:Finish()

	if focusY then
		W.ScrollTo(self.scroll, focusY - 4)
		local focused = self.focus
		C_Timer.After(2.5, function()
			if self.focus == focused then
				self.focus = nil
				if self.frame and self.frame:IsShown() then self:Refresh() end
			end
		end)
	end
end

function page:RenderRecipe(r, cook, me, hideOther)
	local flow = self.flow
	local D = ns.Data

	local tags = ("  |cff999999Cooking %d|r"):format(r.skill or 0)
	if isKnown(r) then tags = tags .. "  |cff20ff20Known|r" end
	if r.foreverOnly then tags = tags .. "  |cff5ec8e5Forever|r" end

	flow:Row({
		icon = W.ItemIcon(r.createsID),
		left = W.Color(difficultyHex(r, cook), r.name) .. tags,
		right = ns.FormatMoney((ns.Prices:GetValue(r.createsID))),
		font = "GameFontNormal",
		height = 20,
		selected = (self.focus == r.name),
		tooltip = W.ItemTooltip(r.createsID, r.effect),
	})

	local uses = {}
	for _, rg in ipairs(r.reagents or {}) do
		uses[#uses + 1] = ("%dx %s"):format(rg[2] or 1, D:GetItemName(rg[1]))
	end
	flow:Text("|cff999999Uses:|r " .. table.concat(uses, ", "), { indent = 22, gap = 2 })
	local benefits = {}
	local set = D:GetRecipeBenefits(r)
	for _, b in ipairs(D:GetBenefitTypes()) do
		if set[b.key] and b.key ~= "none" then
			local label = b.label
			if b.key == "fishing" and r.fishingSkillBonus then label = ("+%d %s"):format(r.fishingSkillBonus, label) end
			benefits[#benefits + 1] = label
		end
	end
	if #benefits > 0 then
		local unconfirmed = r.effectSource == "unverified" and "  |cff808080(not confirmed for Forever)|r" or ""
		flow:Text("|cff999999Benefits:|r |cff5ec8e5" .. table.concat(benefits, ", ") .. "|r" .. unconfirmed, { indent = 22, gap = 2 })
	end

	local learn = r.learn or {}
	if learn.type == "vendor" and learn.sources then
		self:RenderVendors(r, learn.sources, me, hideOther)
	elseif learn.type == "trainer" then
		flow:Row({ indent = 22, left = "Taught by cooking trainers", right = learn.cost and ns.FormatMoney(learn.cost) or "" })
	else
		local how = ({ drop = "Drops", object = "Found in a chest", quest = "Quest reward" })[learn.type] or "Source not confirmed"
		local where = learn.zone and (" in " .. learn.zone) or ""
		if learn.coords then where = where .. (" (%.1f, %.1f)"):format(learn.coords[1], learn.coords[2]) end
		flow:Text(how .. where, { indent = 22, gap = 2 })
		if learn.note then flow:Text("|cff999999" .. learn.note .. "|r", { indent = 22, gap = 2 }) end
	end
end

function page:RenderVendors(r, sources, me, hideOther)
	local flow = self.flow
	local function rank(s)
		if s.faction == me then return 0 elseif s.faction == "N" then return 1 end
		return 2
	end

	local srcs = {}
	for _, s in ipairs(sources) do
		if not hideOther or rank(s) < 2 then srcs[#srcs + 1] = s end
	end
	table.sort(srcs, function(a, b)
		if rank(a) ~= rank(b) then return rank(a) < rank(b) end
		return (a.npc or "") < (b.npc or "")
	end)

	if #srcs == 0 then
		flow:Text("|cff808080No vendor for your faction. Untick the filter to see all.|r", { indent = 22, gap = 2 })
		return
	end

	local open = self.expanded[r.name]
	local shown = open and #srcs or math.min(#srcs, VENDORS_SHOWN)
	for i = 1, shown do
		local s = srcs[i]
		local tag = W.Color(W.FACTION_COLORS[s.faction] or "ffc9b27a", "[" .. (s.faction or "?") .. "]")
		local where = s.coords and ("%s (%.1f, %.1f)"):format(s.zone or "?", s.coords[1], s.coords[2]) or (s.zone or "?")
		local text = ("%s %s  |cff999999%s|r"):format(tag, s.npc or "?", where)
		local right = ns.FormatMoney(s.price) .. (s.limited and "  |cffff8040limited|r" or "")
		if rank(s) == 2 then
			text = "|cff707070" .. W.Plain(text) .. "|r"
		end
		flow:Row({ indent = 22, left = text, right = right, tooltip = vendorTooltip(s) })
	end

	if #srcs > VENDORS_SHOWN then
		flow:Row({
			indent = 22,
			left = open and "|cff9fb4ffShow fewer vendors|r" or ("|cff9fb4ff+%d more vendors|r"):format(#srcs - VENDORS_SHOWN),
			onClick = function()
				self.expanded[r.name] = not open
				self:Refresh()
			end,
		})
	end
end

---------------------------------------------------------------------------
-- Filters
---------------------------------------------------------------------------

-- Search, Unknown-only, and benefit filter (union: a recipe passes if it has
-- ANY selected benefit).
function page:PassesFilters(r)
	if not matches(r, self.query) then return false end
	if ns.db.settings.cookingUnknownOnly and isKnown(r) then return false end
	local selected = ns.db.settings.cookingBenefits
	if next(selected) then
		local set = ns.Data:GetRecipeBenefits(r)
		for key in pairs(selected) do
			if set[key] then return true end
		end
		return false
	end
	return true
end

function page:IsBenefitSelected(key)
	return ns.db.settings.cookingBenefits[key] and true or false
end

function page:ToggleBenefit(key)
	local sel = ns.db.settings.cookingBenefits
	sel[key] = not sel[key] or nil
	self:Refresh()
end

function page:ClearBenefits()
	wipe(ns.db.settings.cookingBenefits)
	self:Refresh()
end

function page:BenefitFilterText()
	local n = 0
	for _ in pairs(ns.db.settings.cookingBenefits) do n = n + 1 end
	return n == 0 and "Benefits" or ("Benefits (%d)"):format(n)
end

function page:UpdateBenefitFilterText()
	if self.setFilterText then self.setFilterText(self:BenefitFilterText()) end
	if self.benefitPopup and self.benefitPopup:IsShown() then self:RefreshBenefitPopup() end
	self:UpdateFilterLine()
end

-- Shows "Benefit filter (2): Attack Power, Spell Power" under the toolbar while
-- any benefit is selected, and moves the list down to make room for it.
function page:UpdateFilterLine()
	if not self.filterText then return end
	local names = {}
	for _, b in ipairs(ns.Data:GetBenefitTypes()) do
		if ns.db.settings.cookingBenefits[b.key] then names[#names + 1] = b.label end
	end
	local top = LIST_TOP
	if #names > 0 then
		self.filterText:SetText(("|cff9fb4ffBenefit filter (%d):|r |cffffffff%s|r"):format(#names, table.concat(names, ", ")))
		self.filterText:Show()
		top = LIST_TOP_FILTERED
	else
		self.filterText:SetText("")
		self.filterText:Hide()
	end
	if self.listTop ~= top then
		self.listTop = top
		self.scroll:SetPoint("TOPLEFT", 0, -top)
	end
end

-- Native filter dropdown (Blizzard menu system) when available, otherwise a
-- small popup checklist. Both call the same IsBenefitSelected/ToggleBenefit.
function page:CreateBenefitFilter(f)
	local ok, dd = pcall(CreateFrame, "DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate")
	if ok and dd and dd.SetupMenu then
		dd:SetSize(140, 22)
		-- Keep the label clear of the template's arrow on the right.
		if dd.Text then
			dd.Text:ClearAllPoints()
			dd.Text:SetPoint("LEFT", dd, "LEFT", 10, 0)
			dd.Text:SetPoint("RIGHT", dd, "RIGHT", -24, 0)
			dd.Text:SetJustifyH("CENTER")
			dd.Text:SetWordWrap(false)
		end
		dd:SetupMenu(function(_, root)
			root:CreateButton("Show all (clear filter)", function() self:ClearBenefits() end)
			for _, b in ipairs(ns.Data:GetBenefitTypes()) do
				root:CreateCheckbox(("%s (%d)"):format(b.label, b.count),
					function() return self:IsBenefitSelected(b.key) end,
					function()
						self:ToggleBenefit(b.key)
						return MenuResponse and MenuResponse.Refresh -- keep the menu open
					end)
			end
		end)
		self.setFilterText = function(text)
			if dd.OverrideText then dd:OverrideText(text)
			elseif dd.Text then dd.Text:SetText(text)
			elseif dd.SetText then dd:SetText(text) end
		end
		self.benefitDropdown = dd
		return dd
	end
	return self:CreateBenefitPopup(f)
end

function page:CreateBenefitPopup(f)
	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetSize(150, 22)
	self.setFilterText = function(text) button:SetText(text) end

	local popup = CreateFrame("Frame", nil, f, "BackdropTemplate")
	popup:SetFrameStrata("DIALOG")
	popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	popup:EnableMouse(true)
	popup:Hide()

	local clear = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	clear:SetSize(170, 20)
	clear:SetPoint("TOPLEFT", 8, -8)
	clear:SetText("Show all (clear filter)")
	clear:SetScript("OnClick", function() self:ClearBenefits() end)

	popup.checks = {}
	local types = ns.Data:GetBenefitTypes()
	for i, b in ipairs(types) do
		local cb = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
		cb:SetSize(20, 20)
		cb:SetPoint("TOPLEFT", 6, -32 - (i - 1) * 20)
		cb:SetScript("OnClick", function() self:ToggleBenefit(b.key) end)
		local label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		label:SetText(("%s (%d)"):format(b.label, b.count))
		cb.key = b.key
		popup.checks[#popup.checks + 1] = cb
	end
	popup:SetSize(190, 40 + #types * 20)

	button:SetScript("OnClick", function()
		popup:SetShown(not popup:IsShown())
		if popup:IsShown() then self:RefreshBenefitPopup() end
	end)
	f:HookScript("OnHide", function() popup:Hide() end)

	self.benefitPopup = popup
	return button
end

function page:RefreshBenefitPopup()
	for _, cb in ipairs(self.benefitPopup.checks) do
		cb:SetChecked(self:IsBenefitSelected(cb.key))
	end
end

ns.UI:RegisterPage("cooking", page)
