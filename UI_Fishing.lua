-- Fishing & Cooking Encyclopedia - "Fishing Waters" page
-- Left: a fish search box and the zones grouped by fishing tier, colored by your skill.
-- Right: the selected zone's fish (raw AH price, what each cooks into, cooked
-- AH price, cook-or-sell verdict), pools, other catches and notes.

local _, ns = ...
local W = ns.Widgets

local page = {}

local ZONE_LIST_WIDTH = 190
local SEARCH_HEIGHT = 26
local MATCHES_SHOWN = 3

local FACTION_HEX = { Alliance = "ff4f8fff", Horde = "ffe24a3b" }
local EXTRA_KIND = { chest = "container", quest = "quest item", junk = "trophy", misc = "", fish = "" }

local function effectiveFishing()
	local rank, _, modifier = ns.GetFishingSkill()
	return (rank or 0) + (modifier or 0), rank or 0, modifier or 0
end

-- Returns colorHex, status text for a zone at the given effective skill.
local function zoneStatus(z, skill)
	if not z.skill then return "ff808080", "Skill requirement not known yet" end
	if z.noGetaway and skill >= z.noGetaway then return "ff20ff20", "You catch everything here" end
	if skill >= z.skill then
		return "ffffd100", ("Some fish get away until skill %d"):format(z.noGetaway or z.skill)
	end
	return "ffff4040", ("Needs skill %d to catch anything"):format(z.skill)
end

local function findZone(name)
	for _, z in ipairs(ns.Data.zones) do
		if z.name == name then return z end
	end
end

-- Pick the hardest tier you can fish in without getaways (or at least catch in).
local function defaultZone(skill)
	local best
	for _, g in ipairs(ns.Data:GetZoneBrackets()) do
		if g.min and skill >= g.min and g.zones[1] then best = g.zones[1] end
	end
	return best or ns.Data.zones[1]
end

local function fishTags(id)
	local tags = {}
	local tod = ns.Data.timeOfDay and ns.Data.timeOfDay[id]
	if tod and tod.window and tod.window ~= "all day" then tags[#tags + 1] = tod.window end
	local season = ns.Data.seasonal and ns.Data.seasonal[id]
	if season and season.season then tags[#tags + 1] = season.season end
	if #tags == 0 then return "" end
	return " |cff9fb4ff(" .. table.concat(tags, ", ") .. ")|r"
end

-- Cook-or-sell verdict for one fish and one recipe (ignores vendor spice cost).
local function verdict(fishID, recipe)
	local raw = ns.Prices:GetValue(fishID)
	local dish = recipe.createsID and ns.Prices:GetValue(recipe.createsID)
	if not raw or not dish then return "" end
	local count = 1
	for _, rg in ipairs(recipe.reagents or {}) do
		if rg[1] == fishID then count = rg[2] or 1 end
	end
	if dish > raw * count then return "  |cff20ff20Cook|r" end
	return "  |cffffd100Sell raw|r"
end

---------------------------------------------------------------------------

function page:Build(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()

	-- Search box above the zone list: filters zones by the fish, catches and pools found there.
	local ok, search = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
	if not ok or not search then
		search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	end
	search:SetSize(ZONE_LIST_WIDTH + 4, 20)
	search:SetPoint("TOPLEFT", 8, -2)
	search:SetAutoFocus(false)
	if search.Instructions and search.Instructions.SetText then search.Instructions:SetText("Search for a fish") end
	search:HookScript("OnTextChanged", function(box) self:OnSearchChanged(box:GetText()) end)
	self.search = search

	local zoneScroll = W.CreateScroll(f)
	zoneScroll:SetPoint("TOPLEFT", 0, -SEARCH_HEIGHT)
	zoneScroll:SetPoint("BOTTOMLEFT", 0, 0)
	zoneScroll:SetWidth(ZONE_LIST_WIDTH)
	zoneScroll.child:SetWidth(ZONE_LIST_WIDTH)

	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(0.7, 0.55, 0.27, 0.5)
	divider:SetWidth(1)
	divider:SetPoint("TOPLEFT", zoneScroll, "TOPRIGHT", 22, SEARCH_HEIGHT)
	divider:SetPoint("BOTTOMLEFT", zoneScroll, "BOTTOMRIGHT", 22, 0)

	local detailScroll = W.CreateScroll(f)
	detailScroll:SetPoint("TOPLEFT", divider, "TOPRIGHT", 8, 0)
	detailScroll:SetPoint("BOTTOMRIGHT", -24, 0)
	detailScroll.onResize = function() if f:IsShown() then self:RenderDetail() end end

	self.zoneScroll, self.detailScroll = zoneScroll, detailScroll
	self.zoneFlow = W.NewFlow(zoneScroll)
	self.detailFlow = W.NewFlow(detailScroll)
	return f
end

function page:Refresh()
	if not self.selected then
		local saved = ns.db.settings.lastZone
		local zone = (saved and findZone(saved)) or defaultZone(effectiveFishing())
		self.selected = zone and zone.name
	end
	self:RenderZones()
	self:RenderDetail()
end

function page:Select(name)
	self.selected = name
	ns.db.settings.lastZone = name
	self:RenderZones()
	self:RenderDetail()
	self.detailScroll:SetVerticalScroll(0)
end

---------------------------------------------------------------------------
-- Zone list
---------------------------------------------------------------------------

-- Does the zone have a fish, other catch or pool whose name contains the
-- search text? Returns (true, { matching names }) or (false). With no search
-- text every zone matches.
function page:ZoneMatches(z)
	local q = self.query
	if not q or q == "" then return true end
	local D = ns.Data
	local hits = {}
	local function check(name)
		if name and name:lower():find(q, 1, true) then hits[#hits + 1] = name end
	end
	for _, id in ipairs(z.fish or {}) do check(D:GetItemName(id)) end
	for _, id in ipairs(z.extras or {}) do check(D:GetItemName(id)) end
	for _, name in ipairs(z.pools or {}) do check(name) end
	return #hits > 0, hits
end

function page:FirstMatchingZone()
	for _, g in ipairs(ns.Data:GetZoneBrackets()) do
		for _, z in ipairs(g.zones) do
			if self:ZoneMatches(z) then return z end
		end
	end
end

function page:OnSearchChanged(text)
	if not self.zoneFlow then return end
	local q = (text or ""):lower():match("^%s*(.-)%s*$")
	if q == self.query then return end
	self.query = q
	if q ~= "" then
		-- Show a zone that has the fish in the detail panel (not saved as your last zone).
		local current = self.selected and findZone(self.selected)
		if not (current and self:ZoneMatches(current)) then
			local first = self:FirstMatchingZone()
			if first then self.selected = first.name end
		end
	end
	self:RenderZones()
	self:RenderDetail()
	self.zoneScroll:SetVerticalScroll(0)
	self.detailScroll:SetVerticalScroll(0)
end

function page:RenderZones()
	local flow = self.zoneFlow
	flow:Reset()
	local skill = effectiveFishing()
	local searching = self.query and self.query ~= ""

	local collapsed = ns.db.settings.collapsedTiers
	local found = 0
	local rows = {}
	for _, g in ipairs(ns.Data:GetZoneBrackets()) do
		local zones, hits = {}, {}
		for _, z in ipairs(g.zones) do
			local ok, matched = self:ZoneMatches(z)
			if ok then zones[#zones + 1] = z; hits[z] = matched end
		end
		if #zones > 0 then
			rows[#rows + 1] = { group = g, zones = zones, hits = hits }
			found = found + #zones
		end
	end

	if searching then
		if found == 0 then
			flow:Text("|cff808080No zone has a fish, catch or pool matching your search.|r", { font = "GameFontDisable" })
		else
			flow:Text(("|cff999999%d zone%s with \"%s\"|r"):format(found, found == 1 and "" or "s", self.query),
				{ font = "GameFontDisableSmall", gap = 4 })
		end
	end

	for _, entry in ipairs(rows) do
		local g, zones = entry.group, entry.zones
		-- While searching every matching zone is shown, whatever is collapsed.
		local isCollapsed = (not searching) and collapsed[g.label] and true or false
		-- Keep the group holding the selected zone visible as a hint when collapsed.
		local hasSelected = false
		for _, z in ipairs(zones) do if z.name == self.selected then hasSelected = true end end
		flow:Row({
			icon = W.CollapseIcon(isCollapsed),
			left = (hasSelected and isCollapsed) and (g.label .. " |cffffffff*|r") or g.label,
			right = "|cff999999" .. #zones .. "|r",
			font = "GameFontNormalSmall",
			height = 18,
			gap = 2,
			tooltip = (not searching) and W.TextTooltip(g.label, isCollapsed and "Click to expand." or "Click to collapse.") or nil,
			onClick = (not searching) and function()
				collapsed[g.label] = not isCollapsed or nil
				self:RenderZones()
			end or nil,
		})
		for _, z in ipairs(isCollapsed and {} or zones) do
			local hex = zoneStatus(z, skill)
			flow:Row({
				left = z.name,
				right = W.Color(hex, z.skill or "?"),
				selected = (z.name == self.selected),
				indent = 4,
				onClick = function() self:Select(z.name) end,
			})
			local matched = entry.hits[z]
			if searching and matched and #matched > 0 then
				local shown = {}
				for i = 1, math.min(#matched, MATCHES_SHOWN) do shown[i] = matched[i] end
				local more = #matched > MATCHES_SHOWN and (" +%d more"):format(#matched - MATCHES_SHOWN) or ""
				flow:Text("|cff9fb4ff" .. table.concat(shown, ", ") .. more .. "|r", { indent = 12, gap = 1, font = "GameFontDisableSmall" })
			end
		end
		flow:Space(isCollapsed and 2 or 8)
	end

	if not searching then
		flow:Text("|cff20ff20Green|r: nothing gets away\n|cffffd100Yellow|r: some fish get away\n|cffff4040Red|r: skill too low",
			{ font = "GameFontDisableSmall" })
	end
	flow:Finish()
end

---------------------------------------------------------------------------
-- Zone detail
---------------------------------------------------------------------------

function page:RenderDetail()
	local flow = self.detailFlow
	flow:Reset()
	local z = self.selected and findZone(self.selected)
	if not z then
		flow:Text("Pick a zone on the left.", { font = "GameFontDisable" })
		return flow:Finish()
	end

	local skill, rank, modifier = effectiveFishing()
	local hex, status = zoneStatus(z, skill)
	local D = ns.Data

	-- Header
	flow:Text(z.name, { font = "GameFontNormalLarge", gap = 4 })
	local factionText = W.Color(FACTION_HEX[z.faction] or "ffc9b27a", z.faction or "?")
	local tier = z.skill and ("Catch from |cffffffff%d|r, nothing gets away at |cffffffff%s|r"):format(z.skill, tostring(z.noGetaway or "?"))
		or "Skill tier not published yet"
	flow:Text(("%s  -  %s  -  %s"):format(z.continent or "?", factionText, tier), { gap = 2 })
	local yourSkill = modifier > 0 and ("%d (+%d)"):format(rank, modifier) or tostring(rank)
	flow:Text(("Your fishing: %s  -  %s"):format(yourSkill, W.Color(hex, status)), { gap = 2 })
	if z.forever then flow:Text("|cff5ec8e5New in WoW: Forever.|r", { gap = 2 }) end
	if z.fishSource ~= "forever" then
		flow:Text("|cff808080Catches are from Classic data and not yet confirmed for Forever.|r", { gap = 2 })
	end
	flow:Space(8)

	-- Fish
	flow:Row({ left = "|cffffd100Fish|r", right = "|cffffd100Raw AH  /  Cooked AH|r", font = "GameFontNormal" })
	if not z.fish or #z.fish == 0 then
		flow:Text("|cff808080No fish list for this zone yet.|r", { indent = 4 })
	end
	for _, id in ipairs(z.fish or {}) do
		local item = D.items[id] or {}
		flow:Row({
			icon = W.ItemIcon(id),
			left = D:GetItemName(id) .. fishTags(id),
			right = ns.FormatMoney((ns.Prices:GetValue(id))),
			height = 20,
			tooltip = W.ItemTooltip(id, item.notes),
		})
		local recipes = D:GetRecipesUsing(id)
		for _, r in ipairs(recipes) do
			local cook = ns.GetCookingSkill()
			local skillText = (r.skill or 0) > cook and W.Color("ffff4040", "Cooking " .. (r.skill or 0))
				or ("|cff999999Cooking %d|r"):format(r.skill or 0)
			flow:Row({
				indent = 22,
				left = ("|cffffcf6b%s|r  %s"):format(r.name, skillText),
				right = ns.FormatMoney((ns.Prices:GetValue(r.createsID))) .. verdict(id, r),
				tooltip = W.ItemTooltip(r.createsID, "Click to see where to learn this recipe. Cook/Sell compares AH prices only, before spice costs."),
				onClick = function() ns.UI:ShowRecipe(r.name) end,
			})
		end
		if #recipes == 0 then
			local use = D.otherUses and D.otherUses[id]
			flow:Text("|cff999999" .. (use and use:gsub(" %- spell.*", "") or "No cooking use") .. "|r", { indent = 26, gap = 2 })
		end
		flow:Space(3)
	end
	flow:Space(6)

	-- Pools
	flow:Row({ left = "|cffffd100Pools & Schools|r", font = "GameFontNormal" })
	if not z.pools or #z.pools == 0 then
		flow:Text("|cff808080None recorded.|r", { indent = 4 })
	end
	for _, name in ipairs(z.pools or {}) do
		local pool = D.pools[name] or {}
		local yields = {}
		for i, id in ipairs(pool.yields or {}) do
			if i > 2 then break end
			yields[#yields + 1] = D:GetItemName(id)
		end
		flow:Row({
			indent = 4,
			left = name,
			right = "|cff999999" .. table.concat(yields, ", ") .. "|r",
			tooltip = W.TextTooltip(name, pool.notes),
		})
	end
	flow:Space(8)

	-- Other catches
	flow:Row({ left = "|cffffd100Other Catches|r", font = "GameFontNormal" })
	if not z.extras or #z.extras == 0 then
		flow:Text("|cff808080Fish only.|r", { indent = 4 })
	end
	for _, id in ipairs(z.extras or {}) do
		local item = D.items[id] or {}
		flow:Row({
			indent = 4,
			icon = W.ItemIcon(id),
			left = D:GetItemName(id),
			right = "|cff999999" .. (EXTRA_KIND[item.kind] or "") .. "|r",
			tooltip = W.ItemTooltip(id, item.notes),
		})
	end

	-- Subzones with their own tier
	if z.subzones and #z.subzones > 0 then
		flow:Space(8)
		flow:Row({ left = "|cffffd100Harder Waters Here|r", font = "GameFontNormal" })
		for _, sub in ipairs(z.subzones) do
			local fullName = z.name .. ": " .. sub.name
			flow:Row({
				indent = 4,
				left = sub.name,
				right = W.Color((zoneStatus(sub, skill)), "skill " .. (sub.skill or "?")),
				onClick = function() self:Select(fullName) end,
				tooltip = W.TextTooltip(sub.name, sub.notes, "Click to open."),
			})
		end
	end

	-- Notes
	if z.notes and z.notes ~= "" then
		flow:Space(8)
		flow:Text("|cffffd100Notes|r", { font = "GameFontNormal" })
		flow:Text("|cffbbbbbb" .. z.notes .. "|r", { indent = 4 })
	end

	flow:Finish()
end

ns.UI:RegisterPage("fishing", page)
