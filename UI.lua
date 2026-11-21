-- Fishing & Cooking Encyclopedia - Profession window integration
--
-- WoW: Forever's ProfessionsFrame (Blizzard_Professions, "Camelot" variant)
-- has a column of vertical side tabs on its right edge:
--   ProfessionsOverviewTab, then ProfessionsFrame.rightProfessionTabs[1..7].
-- We add our own side tab directly beneath the last visible Blizzard tab and
-- show our panel over the content area when it's selected.
--
-- Taint rules followed here:
--   * Never insert into or modify Blizzard tables (rightProfessionTabs etc.).
--   * Only hooksecurefunc / HookScript on Blizzard code, never replace methods.

local _, ns = ...

local UI = {}
ns.UI = UI

local SKILL_FISHING, SKILL_COOKING = 356, 185
local TAB_ICON = ns.ICON

---------------------------------------------------------------------------
-- Skill lookup. In Forever GetProfessions() returns
-- prof1, prof2, firstAid, fishing, cooking (any may be nil).
---------------------------------------------------------------------------

function ns.GetSkill(skillLineID)
	local indices = { GetProfessions() }
	for i = 1, 5 do
		local idx = indices[i]
		if idx then
			local name, _, rank, maxRank, _, _, skillLine, modifier = GetProfessionInfo(idx)
			if skillLine == skillLineID then
				return rank or 0, maxRank or 0, modifier or 0, name
			end
		end
	end
	return 0, 0, 0, nil
end

function ns.GetFishingSkill() return ns.GetSkill(SKILL_FISHING) end
function ns.GetCookingSkill() return ns.GetSkill(SKILL_COOKING) end

---------------------------------------------------------------------------
-- Pages: each page module registers { title=, Build(parent), Refresh() }.
-- UI_Fishing.lua / UI_Cooking.lua / UI_Prices.lua fill these in.
---------------------------------------------------------------------------

UI.pages = {}
UI.pageOrder = { "fishing", "cooking", "training", "prices" }
local PAGE_TITLES = { fishing = "Fishing Waters", cooking = "Cooking Recipes", training = "Training", prices = "Prices & Scan" }
local PAGE_TAB_WIDTH = { fishing = 120, cooking = 128, training = 90, prices = 110 }

function UI:RegisterPage(key, page)
	self.pages[key] = page
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function createPanel(PF)
	local panel = CreateFrame("Frame", "FCE_ProfessionPanel", PF)
	-- Occupy the same area as Blizzard's overview page when available.
	if PF.BookPage then
		panel:SetAllPoints(PF.BookPage)
	else
		panel:SetPoint("TOPLEFT", PF, "TOPLEFT", 8, -62)
		panel:SetPoint("BOTTOMRIGHT", PF, "BOTTOMRIGHT", -8, 8)
	end
	panel:SetFrameLevel((PF.BookPage and PF.BookPage:GetFrameLevel() or PF:GetFrameLevel()) + 5)
	panel:Hide()

	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.10, 0.085, 0.06, 0.97)

	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetSize(22, 22)
	logo:SetTexture(ns.ICON)
	logo:SetPoint("TOPLEFT", 12, -8)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
	title:SetText("Fishing & Cooking Encyclopedia")
	panel.title = title

	local skills = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	skills:SetPoint("TOPRIGHT", -14, -14)
	panel.skills = skills

	-- Page tabs across the top of the panel.
	panel.pageTabs = {}
	local prev
	for _, key in ipairs(UI.pageOrder) do
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(PAGE_TAB_WIDTH[key] or 120, 22)
		b:SetText(PAGE_TITLES[key])
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -36) end
		b:SetScript("OnClick", function() UI:ShowPage(key) end)
		panel.pageTabs[key] = b
		prev = b
	end

	-- Content area shared by pages.
	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 10, -64)
	content:SetPoint("BOTTOMRIGHT", -10, 10)
	panel.content = content

	-- Placeholder shown for pages that aren't built yet.
	local placeholder = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	placeholder:SetPoint("CENTER")
	panel.placeholder = placeholder

	return panel
end

function UI:ShowPage(key)
	local panel = self.panel
	if not panel then return end
	self.currentPage = key
	ns.db.settings.lastPage = key

	for k, b in pairs(panel.pageTabs) do
		if k == key then b:LockHighlight() else b:UnlockHighlight() end
	end

	for k, page in pairs(self.pages) do
		if page.frame then page.frame:SetShown(k == key) end
	end

	local page = self.pages[key]
	if page then
		panel.placeholder:Hide()
		if not page.frame and page.Build then
			page.frame = page:Build(panel.content)
		end
		if page.frame then page.frame:Show() end
		if page.Refresh then page:Refresh() end
	else
		panel.placeholder:SetText(PAGE_TITLES[key] .. " page coming soon.")
		panel.placeholder:Show()
	end
end

function UI:RefreshHeader()
	local panel = self.panel
	if not panel then return end
	local fish, fishMax, fishMod = ns.GetFishingSkill()
	local cook, cookMax = ns.GetCookingSkill()
	local fishText = fishMod and fishMod > 0 and ("%d |cff20ff20+%d|r"):format(fish, fishMod) or tostring(fish)
	panel.skills:SetText(("Fishing %s / %d    Cooking %d / %d"):format(fishText, fishMax, cook, cookMax))
end

---------------------------------------------------------------------------
-- Side tab
---------------------------------------------------------------------------

local function createSideTab(parent)
	local ok, tab = pcall(CreateFrame, "Frame", "FCE_ProfessionSideTab", parent, "LargeSideTabButtonTemplate")
	if not ok or not tab then
		-- Fallback if the template isn't available: a plain icon button.
		tab = CreateFrame("Button", "FCE_ProfessionSideTab", parent)
		tab:SetSize(44, 44)
		tab.Icon = tab:CreateTexture(nil, "ARTWORK")
		tab.Icon:SetAllPoints()
		local hl = tab:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.15)
		tab.SetChecked = function(self, checked)
			self.checked = checked
			self.Icon:SetVertexColor(checked and 1 or 0.7, checked and 1 or 0.7, checked and 1 or 0.7)
		end
		tab:SetScript("OnClick", function() UI:Select() end)
		tab:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Fishing & Cooking Encyclopedia")
			GameTooltip:Show()
		end)
		tab:SetScript("OnLeave", GameTooltip_Hide)
	else
		tab.tooltipText = "Fishing & Cooking Encyclopedia"
		if tab.SetCustomOnMouseUpHandler then
			tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
				if button == "LeftButton" and upInside then UI:Select() end
			end)
		else
			tab:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then UI:Select() end end)
		end
	end

	tab.Icon:SetTexture(TAB_ICON)
	return tab
end

-- Tab placement. Other addons add side tabs under Blizzard's too, and two
-- addons that each stack below whatever is already there can chase each other
-- off screen. So this tab never reacts to other tabs: by default it is pinned
-- to the bottom of the window's tab column, a fixed spot that tabs stacked from
-- the top won't reach. The "top" setting puts it under Blizzard's last tab.
--
-- The column is a shared frame, ProfessionsFrameTabSideBar. AllTheThings
-- creates it (if no other addon has), moves Blizzard's tabs onto it, and
-- re-anchors it to the edge of its own window when that opens. Our tab is
-- parented and anchored to the same frame so it moves with the other tabs.
local TAB_GAP = 14
local TAB_BOTTOM_INSET = 24

local function getSideBar(PF)
	local bar = _G.ProfessionsFrameTabSideBar
	if not bar then
		bar = CreateFrame("Frame", nil, PF)
		bar:SetWidth(1)
		bar:SetPoint("TOPLEFT", PF, "TOPRIGHT")
		bar:SetPoint("BOTTOMLEFT", PF, "BOTTOMRIGHT")
		bar.Tabs = {}
		bar.selTab = 0
		_G.ProfessionsFrameTabSideBar = bar
	end
	return bar
end

local function lastBlizzardTab(PF)
	local last = PF.ProfessionsOverviewTab
	for _, t in ipairs(PF.rightProfessionTabs or {}) do
		if t:IsShown() then last = t end
	end
	return last
end

local function reanchorTab()
	local PF = ProfessionsFrame
	local tab = UI.tab
	if not PF or not tab then return end
	tab:ClearAllPoints()
	if ns.db.settings.tabPosition == "top" then
		local last = lastBlizzardTab(PF)
		if last then
			tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -TAB_GAP)
		else
			tab:SetPoint("TOPLEFT", PF, "TOPRIGHT", 0, -36)
		end
	else
		tab:SetPoint("BOTTOMLEFT", UI.sideBar or PF, UI.sideBar and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, TAB_BOTTOM_INSET)
	end
	tab:Show()
end
UI.ReanchorTab = reanchorTab

function UI:SetTabPosition(position)
	ns.db.settings.tabPosition = position == "top" and "top" or "bottom"
	reanchorTab()
end

local function deselect()
	if UI.tab then UI.tab:SetChecked(false) end
	if UI.panel then UI.panel:Hide() end
	UI.selected = false
end

-- Select our tab: hide Blizzard's pages, uncheck their tabs, show ours.
function UI:Select()
	local PF = ProfessionsFrame
	if not PF or not self.panel then return end
	if PF.BookPage then PF.BookPage:Hide() end
	if PF.CraftingPage then PF.CraftingPage:Hide() end
	if PF.ProfessionsOverviewTab then PF.ProfessionsOverviewTab:SetChecked(false) end
	for _, t in ipairs(PF.rightProfessionTabs or {}) do t:SetChecked(false) end

	self.tab:SetChecked(true)
	self.panel:Show()
	self.selected = true
	self:RefreshHeader()
	self:ShowPage(self.currentPage or ns.db.settings.lastPage or "fishing")
end

local function setup()
	local PF = ProfessionsFrame
	if not PF or UI.panel then return end

	UI.panel = createPanel(PF)
	UI.sideBar = getSideBar(PF)
	UI.tab = createSideTab(UI.sideBar)

	-- Re-place our tab when Blizzard's tabs change (matters for the "top" position).
	if PF.RefreshRightTabs then hooksecurefunc(PF, "RefreshRightTabs", reanchorTab) end
	-- Any Blizzard tab or page selection hides our panel.
	if PF.RightTabSelected then hooksecurefunc(PF, "RightTabSelected", deselect) end
	if PF.SelectBookPage then hooksecurefunc(PF, "SelectBookPage", deselect) end
	-- Reopening the window always starts on Blizzard's page.
	PF:HookScript("OnShow", function()
		deselect()
		reanchorTab()
	end)

	reanchorTab()
end

---------------------------------------------------------------------------
-- Open from slash command (a hardware event, so opening the frame is allowed)
---------------------------------------------------------------------------

function UI:Toggle()
	if not ProfessionsFrame then
		C_AddOns.LoadAddOn("Blizzard_Professions")
	end
	if not ProfessionsFrame then
		return ns:Print("Couldn't load the profession window.")
	end
	if ProfessionsFrame:IsShown() and self.selected then
		HideUIPanel(ProfessionsFrame)
		return
	end
	if not ProfessionsFrame:IsShown() then
		if ToggleProfessionsBook then ToggleProfessionsBook() else ShowUIPanel(ProfessionsFrame) end
	end
	setup()
	C_Timer.After(0, function() UI:Select() end)
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

ns:Listen("DB_READY", function()
	if C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
		setup()
	else
		EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", setup)
	end
end)

ns:On("SKILL_LINES_CHANGED", function()
	if UI.selected then UI:RefreshHeader() end
end)

-- Jump to a recipe on the Cooking page (used by recipe links on the Fishing page).
function UI:ShowRecipe(name)
	local page = self.pages.cooking
	if not page then return end
	page.focus = name
	page.query = ""
	if page.search then page.search:SetText("") end
	self:ShowPage("cooking")
end

-- Refresh the visible page at most twice a second while prices stream in.
local refreshPending = false
local function refreshVisiblePage()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.5, function()
		refreshPending = false
		if not UI.selected then return end
		local page = UI.pages[UI.currentPage]
		if page and page.frame and page.Refresh then page:Refresh() end
	end)
end

for _, msg in ipairs({ "PRICES_UPDATED", "SCAN_STARTED", "SCAN_FINISHED", "SCAN_ABORTED" }) do
	ns:Listen(msg, refreshVisiblePage)
end
