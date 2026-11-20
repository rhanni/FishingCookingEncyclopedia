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

local function createSideTab(PF)
	local ok, tab = pcall(CreateFrame, "Frame", "FCE_ProfessionSideTab", PF, "LargeSideTabButtonTemplate")
	if not ok or not tab then
		-- Fallback if the template isn't available: a plain icon button.
		tab = CreateFrame("Button", "FCE_ProfessionSideTab", PF)
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

-- Other addons (e.g. AllTheThings) also put side tabs under Blizzard's.
-- We stack ours below the lowest of them instead of overlapping it.
local TAB_GAP = 14   -- gap between Blizzard's last tab and the first addon tab
local STACK_GAP = 4  -- gap below another addon's tab

local function lastBlizzardTab(PF)
	local last = PF.ProfessionsOverviewTab
	for _, t in ipairs(PF.rightProfessionTabs or {}) do
		if t:IsShown() then last = t end
	end
	return last
end

local function isBlizzardTab(PF, f)
	if f == PF.ProfessionsOverviewTab then return true end
	for _, t in ipairs(PF.rightProfessionTabs or {}) do
		if t == f then return true end
	end
	return false
end

-- True if f is positioned relative to our tab (it would move with us, so
-- stacking below it would chase it forever).
local function anchoredTo(f, target)
	local n = f.GetNumPoints and f:GetNumPoints() or 0
	for i = 1, n do
		local _, rel = f:GetPoint(i)
		if rel == target then return true end
	end
	return false
end

-- The retail-based client protects some frames (nameplates, secure unit
-- frames): reading their position can error or return "secret" values that
-- can't be compared. Anything like that is skipped, never trusted.
local function plainNumber(v)
	return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end

-- Returns f's bottom edge (in `last`'s coordinates) if f looks like another
-- addon's side tab in Blizzard's tab column below `last`; otherwise nil.
-- Runs inside pcall, so any error just means "not a tab".
local function foreignTabBottom(PF, f, colLeft, lastBottom, lastScale)
	if f == UI.tab or f == UI.panel then return nil end
	if f.IsForbidden and f:IsForbidden() then return nil end
	if f.IsAnchoringRestricted and f:IsAnchoringRestricted() then return nil end
	if not f.IsVisible or not f:IsVisible() then return nil end
	local l, b, w, h = f:GetRect()
	local scale = f:GetEffectiveScale()
	if not (plainNumber(l) and plainNumber(b) and plainNumber(w) and plainNumber(h) and plainNumber(scale)) then return nil end
	local s = scale / lastScale
	l, b, w, h = l * s, b * s, w * s, h * s
	if w < 24 or w > 80 or h < 24 or h > 80 then return nil end -- not tab-sized
	if math.abs(l - colLeft) > 12 then return nil end            -- not in the tab column
	if b + h > lastBottom + 4 then return nil end                -- not below Blizzard's tabs
	if isBlizzardTab(PF, f) or anchoredTo(f, UI.tab) then return nil end
	return b
end

-- Performance: we never scan the whole UI when the window opens.
--   * Other addons' tabs, once found, are remembered (foreignTabs) and their
--     OnShow/OnHide are hooked, so we re-stack the moment they appear or
--     disappear instead of polling.
--   * Each re-stack only checks those remembered tabs plus the profession
--     window's direct children (a few dozen frames).
--   * A full search of every frame (for tabs parented elsewhere) runs once
--     per session, spread over many frames so it never causes a hitch.
--   * Repeated requests in the same frame collapse into one re-stack, and
--     nothing runs while the window is closed.
local foreignTabs = setmetatable({}, { __mode = "k" }) -- [frame] = true
local watched = setmetatable({}, { __mode = "k" })
local scheduleReanchor -- defined below

-- Position of Blizzard's tab column, or nil if it can't be read yet.
local function columnInfo(last)
	local l, b, s = last:GetLeft(), last:GetBottom(), last:GetEffectiveScale()
	if plainNumber(l) and plainNumber(b) and plainNumber(s) and s ~= 0 then
		return { left = l, bottom = b, scale = s }
	end
end

-- Checks one frame; remembers and watches it if it's another addon's tab.
-- Returns its bottom edge, or nil.
local function checkFrame(PF, f, col)
	local ok, b = pcall(foreignTabBottom, PF, f, col.left, col.bottom, col.scale)
	if not ok or not b then return nil end
	foreignTabs[f] = true
	if not watched[f] then
		watched[f] = true
		pcall(f.HookScript, f, "OnShow", function() scheduleReanchor() end)
		pcall(f.HookScript, f, "OnHide", function() scheduleReanchor() end)
	end
	return b
end

-- Lowest other-addon tab, as a (negative) offset from the bottom of
-- Blizzard's last tab; nil if there are none.
local function lowestForeignTabOffset(PF, last)
	local col = columnInfo(last)
	if not col then return nil end
	local lowest
	local function consider(f)
		local b = checkFrame(PF, f, col)
		if b and (not lowest or b < lowest) then lowest = b end
	end
	for f in pairs(foreignTabs) do consider(f) end
	for _, f in ipairs({ PF:GetChildren() }) do consider(f) end
	return lowest and (lowest - col.bottom) or nil
end

local function reanchorTab()
	local PF = ProfessionsFrame
	local tab = UI.tab
	if not PF or not tab then return end
	local last = lastBlizzardTab(PF)
	-- Work out the offset first, so the tab is never left without a position.
	local y = -TAB_GAP
	if last and PF:IsShown() then
		local ok, foreign = pcall(lowestForeignTabOffset, PF, last)
		if ok and foreign then y = math.min(y, foreign - STACK_GAP) end
	end
	tab:ClearAllPoints()
	if last then
		tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, y)
	else
		tab:SetPoint("TOPLEFT", PF, "TOPRIGHT", 0, -36)
	end
	tab:Show()
end
UI.ReanchorTab = reanchorTab -- for tests / debugging

-- Collapse any number of requests in one frame into a single re-stack on the
-- next frame (when other addons have finished creating/moving their tabs).
local reanchorPending = false
scheduleReanchor = function()
	if reanchorPending then return end
	reanchorPending = true
	C_Timer.After(0, function()
		reanchorPending = false
		if ProfessionsFrame and ProfessionsFrame:IsShown() then reanchorTab() end
	end)
end

-- Full search for tabs parented outside the profession window. Runs once per
-- session, 200 frames per rendered frame. sync=true does it all at once
-- (for /fce tabs and tests).
local FRAMES_PER_STEP = 200
local deepScanDone, deepScanner = false, nil

local function deepScanStep(budget)
	local PF = ProfessionsFrame
	local last = PF and PF:IsShown() and lastBlizzardTab(PF)
	local col = last and columnInfo(last)
	if not col then return "paused" end
	local f = deepScanner.cursor
	for _ = 1, budget do
		if not f then return "done" end
		checkFrame(PF, f, col)
		f = EnumerateFrames(f)
	end
	deepScanner.cursor = f
	return f and "more" or "done"
end

function UI:FindAddonTabs(sync)
	if not EnumerateFrames or (deepScanDone and not sync) then return end
	deepScanner = deepScanner or CreateFrame("Frame")
	deepScanner.cursor = EnumerateFrames()
	local function finish(result)
		deepScanner:SetScript("OnUpdate", nil)
		if result == "done" then deepScanDone = true; scheduleReanchor() end
		-- "paused": window closed mid-search; it restarts next time it opens.
	end
	if sync then
		finish(deepScanStep(math.huge))
		return
	end
	deepScanner:SetScript("OnUpdate", function()
		local result = deepScanStep(FRAMES_PER_STEP)
		if result ~= "more" then finish(result) end
	end)
end

-- /fce tabs: list the other addons' tabs we're stacking below.
function UI:ReportTabs()
	if not ProfessionsFrame or not ProfessionsFrame:IsShown() then
		return ns:Print("Open the profession window first, then type /fce tabs.")
	end
	self:FindAddonTabs(true)
	reanchorTab()
	local n = 0
	for f in pairs(foreignTabs) do
		local ok, l, b, w, h = pcall(f.GetRect, f)
		local name = (f.GetName and f:GetName()) or (f.GetParent and f:GetParent() and f:GetParent():GetName() and (f:GetParent():GetName() .. " child")) or "unnamed frame"
		n = n + 1
		ns:Print(("Other addon tab: %s%s"):format(name,
			ok and plainNumber(l) and (" at %d,%d size %dx%d%s"):format(l, b, w, h, f:IsVisible() and "" or " (hidden)") or ""))
	end
	if n == 0 then ns:Print("No other addons' side tabs found in the profession window.") end
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
	UI.tab = createSideTab(PF)

	-- Keep our tab beneath Blizzard's as their visibility changes.
	if PF.RefreshRightTabs then hooksecurefunc(PF, "RefreshRightTabs", scheduleReanchor) end
	-- Any Blizzard tab or page selection hides our panel.
	if PF.RightTabSelected then hooksecurefunc(PF, "RightTabSelected", deselect) end
	if PF.SelectBookPage then hooksecurefunc(PF, "SelectBookPage", deselect) end
	-- Reopening the window always starts on Blizzard's page.
	-- On open: place the tab now, re-check once next frame (other addons add
	-- their tabs in their own OnShow), and on the first open of the session
	-- start the spread-out search for tabs parented elsewhere.
	PF:HookScript("OnShow", function()
		deselect()
		reanchorTab()
		scheduleReanchor()
		UI:FindAddonTabs(false)
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
