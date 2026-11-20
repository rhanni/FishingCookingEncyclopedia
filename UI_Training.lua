-- Fishing & Cooking Encyclopedia - "Training" page
-- For Fishing and Cooking: each skill rank and how to get it (trainer, book
-- from a vendor, or quest with its start NPC and coordinates), every trainer
-- (your faction and neutral first), and related side quests.

local _, ns = ...
local W = ns.Widgets

local page = {}

local PROFS = { { key = "fishing", label = "Fishing" }, { key = "cooking", label = "Cooking" } }
local METHOD_LABEL = { trainer = "Trainer", book = "Book", quest = "Quest" }

local function rankFor(maxSkill)
	if not maxSkill or maxSkill <= 0 then return "Not learned" end
	if maxSkill <= 75 then return "Apprentice" end
	if maxSkill <= 150 then return "Journeyman" end
	if maxSkill <= 225 then return "Expert" end
	return "Artisan"
end

local function skillFor(key)
	if key == "fishing" then return ns.GetFishingSkill() end
	return ns.GetCookingSkill()
end

local function where(s)
	local place = s.subzone and (s.subzone .. ", " .. (s.zone or "?")) or (s.zone or "?")
	if s.coords and s.coords[1] then
		place = place .. (" (%.1f, %.1f)"):format(s.coords[1], s.coords[2])
	end
	return place
end

local function factionTag(f)
	if f == nil then return "" end
	return W.Color(W.FACTION_COLORS[f] or "ffc9b27a", "[" .. f .. "]")
end

-- 0 = your faction (incl. "A/H" both-faction entries), 1 = neutral/unknown, 2 = other faction
local function factionRank(f, me)
	if f == me then return 0 end
	if f == nil or f == "N" then return 1 end
	if type(f) == "string" and f:find(me, 1, true) then return 0 end
	return 2
end

---------------------------------------------------------------------------

function page:Build(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()

	self.profButtons = {}
	local prev
	for _, p in ipairs(PROFS) do
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(100, 22)
		b:SetText(p.label)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 6, -2) end
		b:SetScript("OnClick", function()
			self.prof = p.key
			ns.db.settings.trainingProf = p.key
			self:Refresh()
			self.scroll:SetVerticalScroll(0)
		end)
		self.profButtons[p.key] = b
		prev = b
	end

	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetPoint("LEFT", prev, "RIGHT", 14, 0)
	check:SetScript("OnClick", function(cb)
		ns.db.settings.hideOtherFaction = cb:GetChecked() and true or false
		self:Refresh()
	end)
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText("Hide other faction")
	self.check = check

	local scroll = W.CreateScroll(f)
	scroll:SetPoint("TOPLEFT", 0, -30)
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	scroll.onResize = function() if f:IsShown() then self:Refresh() end end
	self.scroll = scroll
	self.flow = W.NewFlow(scroll)
	self.showOther = {}
	return f
end

function page:Refresh()
	self.prof = self.prof or ns.db.settings.trainingProf or "fishing"
	for key, b in pairs(self.profButtons) do
		if key == self.prof then b:LockHighlight() else b:UnlockHighlight() end
	end
	self.check:SetChecked(ns.db.settings.hideOtherFaction and true or false)

	local flow = self.flow
	flow:Reset()
	local data = ns.Data.training and ns.Data.training[self.prof]
	if not data then
		flow:Text("|cff808080Training data for this profession isn't available yet.|r", { font = "GameFontDisable" })
		return flow:Finish()
	end

	local me = W.PlayerFactionCode()
	local hideOther = ns.db.settings.hideOtherFaction
	local rank, maxRank, modifier = skillFor(self.prof)
	local profLabel = self.prof == "fishing" and "Fishing" or "Cooking"
	local bonus = (modifier and modifier > 0) and (" |cff20ff20+%d|r"):format(modifier) or ""
	flow:Text(("Your %s: |cffffffff%d / %d|r%s  -  %s"):format(profLabel, rank or 0, maxRank or 0, bonus, rankFor(maxRank)),
		{ font = "GameFontHighlight", gap = 8 })

	self:RenderRanks(data.ranks or {}, maxRank or 0, me, hideOther)
	flow:Space(10)
	self:RenderTrainers(data.trainers or {}, me, hideOther, profLabel)
	if data.quests and #data.quests > 0 then
		flow:Space(10)
		self:RenderQuests(data.quests, me, hideOther)
	end
	flow:Finish()
end

---------------------------------------------------------------------------
-- Ranks
---------------------------------------------------------------------------

function page:RenderRanks(ranks, maxSkill, me, hideOther)
	local flow = self.flow
	flow:Row({ left = "|cffffd100Skill Ranks|r", font = "GameFontNormal" })

	local nextFound = false
	for i, r in ipairs(ranks) do
		local top = flow.y
		flow:Space(4)

		local status
		if maxSkill >= (r.cap or 0) then
			status = "|cff20ff20Learned|r"
		elseif not nextFound then
			status = "|cffffd100Next for you|r"
			nextFound = true
		else
			status = "|cff808080Later|r"
		end
		flow:Row({
			left = ("%s  |cff999999up to %d  -  %s|r"):format(r.rank or "?", r.cap or 0, METHOD_LABEL[r.method] or (r.method or "?")),
			right = status,
			font = "GameFontNormal",
			height = 20,
		})

		local req = {}
		if r.reqSkill and r.reqSkill > 0 then req[#req + 1] = "skill " .. r.reqSkill end
		if r.reqLevel and r.reqLevel > 0 then req[#req + 1] = "level " .. r.reqLevel end
		local reqText = #req > 0 and ("Requires " .. table.concat(req, ", ")) or "No requirements"
		if r.cost and r.cost > 0 then reqText = reqText .. "  -  costs " .. ns.FormatMoney(r.cost) end
		flow:Text("|cffbbbbbb" .. reqText .. "|r", { indent = 22, gap = 2 })

		if r.method == "trainer" then
			flow:Text("Any trainer listed below teaches this rank (unless noted).", { indent = 22, gap = 2 })
		elseif r.method == "book" then
			self:RenderBook(r, me, hideOther)
		elseif r.method == "quest" and r.quest then
			self:RenderQuestBlock(r.quest, 22, me, hideOther)
		end
		local note = r.notes or r.note
		if note then flow:Text("|cff999999" .. note .. "|r", { indent = 22, gap = 2 }) end

		flow:Space(4)
		flow:Band(top, W.RowStyle(i))
	end
end

function page:RenderBook(r, me, hideOther)
	local flow = self.flow
	local book = r.book or {}
	flow:Row({
		indent = 22,
		icon = book.itemID and W.ItemIcon(book.itemID) or nil,
		left = "|cffffcf6b" .. (book.name or "Skill book") .. "|r",
		tooltip = book.itemID and W.ItemTooltip(book.itemID, book.tooltip) or nil,
	})
	local srcs = {}
	for _, s in ipairs(r.sources or {}) do
		if not hideOther or factionRank(s.faction, me) < 2 then srcs[#srcs + 1] = s end
	end
	table.sort(srcs, function(a, b) return factionRank(a.faction, me) < factionRank(b.faction, me) end)
	for _, s in ipairs(srcs) do
		local text = ("%s %s  |cff999999%s|r"):format(factionTag(s.faction), s.npc or "?", where(s))
		if factionRank(s.faction, me) == 2 then text = "|cff707070" .. W.Plain(text) .. "|r" end
		flow:Row({
			indent = 40,
			left = text,
			right = s.price and ns.FormatMoney(s.price) or "",
			tooltip = W.TextTooltip(s.npc or "Vendor", where(s), W.FACTION_NAMES[s.faction] or ""),
		})
	end
	if #srcs == 0 then
		flow:Text("|cff808080No seller for your faction. Untick the filter to see all.|r", { indent = 40, gap = 2 })
	end
end

-- Lists NPCs (quest givers or turn-ins), your faction first; other faction
-- dimmed or hidden by the filter. Entries without a faction are always shown.
function page:RenderNpcList(label, npcs, indent, me, hideOther)
	local flow = self.flow
	local list = {}
	for _, n in ipairs(npcs) do
		if not hideOther or factionRank(n.faction, me) < 2 then list[#list + 1] = n end
	end
	table.sort(list, function(a, b) return factionRank(a.faction, me) < factionRank(b.faction, me) end)
	if #list == 0 then return end
	flow:Text("|cff999999" .. label .. "|r", { indent = indent, gap = 1 })
	for _, n in ipairs(list) do
		local tag = factionTag(n.faction)
		local text = (tag ~= "" and (tag .. " ") or "") .. ("|cffffffff%s|r  |cff999999%s|r"):format(n.npc or "?", where(n))
		if factionRank(n.faction, me) == 2 then text = "|cff707070" .. W.Plain(text) .. "|r" end
		flow:Row({ indent = indent + 8, left = text, tooltip = W.TextTooltip(n.npc or "NPC", where(n), W.FACTION_NAMES[n.faction] or "") })
	end
end

function page:RenderQuestBlock(q, indent, me, hideOther)
	local flow = self.flow
	local level = q.level and ("  |cff999999level %d|r"):format(q.level) or ""
	flow:Row({
		indent = indent,
		left = "|cffffd100Quest:|r " .. (q.name or "?") .. level,
		right = factionTag(q.faction),
		tooltip = W.TextTooltip(q.name or "Quest", q.summary, q.reward and ("Reward: " .. q.reward) or nil),
	})
	local inner = indent + 18
	local req = {}
	if q.reqLevel and q.reqLevel > 0 then req[#req + 1] = "level " .. q.reqLevel end
	if q.reqSkill and q.reqSkill > 0 then req[#req + 1] = "skill " .. q.reqSkill end
	if #req > 0 then flow:Text("|cffbbbbbbRequires " .. table.concat(req, ", ") .. "|r", { indent = inner, gap = 2 }) end

	if q.givers and #q.givers > 0 then
		self:RenderNpcList("Starts at any of:", q.givers, inner, me, hideOther)
	else
		flow:Text(("Starts at |cffffffff%s|r  -  %s"):format(q.npc or "?", where(q)), { indent = inner, gap = 2 })
	end
	if q.enders and #q.enders > 0 then
		self:RenderNpcList("Turn in to:", q.enders, inner, me, hideOther)
	end
	if q.summary then flow:Text("|cffbbbbbb" .. q.summary .. "|r", { indent = inner, gap = 2 }) end
	if q.reward then flow:Text("|cff999999Reward: " .. q.reward .. "|r", { indent = inner, gap = 2 }) end
end

---------------------------------------------------------------------------
-- Trainers
---------------------------------------------------------------------------

function page:RenderTrainers(trainers, me, hideOther, profLabel)
	local flow = self.flow
	local mine, other = {}, {}
	for _, t in ipairs(trainers) do
		if factionRank(t.faction, me) < 2 then mine[#mine + 1] = t else other[#other + 1] = t end
	end
	local function byZone(a, b)
		if (a.zone or "") ~= (b.zone or "") then return (a.zone or "") < (b.zone or "") end
		return (a.npc or "") < (b.npc or "")
	end
	table.sort(mine, byZone)
	table.sort(other, byZone)

	flow:Row({ left = ("|cffffd100%s Trainers|r"):format(profLabel), right = "|cff999999teaches up to|r", font = "GameFontNormal" })

	local function trainerRow(t, i, dim)
		local top = flow.y
		local text = ("%s %s  |cff999999%s|r"):format(factionTag(t.faction), t.npc or "?", where(t))
		if dim then text = "|cff707070" .. W.Plain(text) .. "|r" end
		flow:Row({
			indent = 4,
			left = text,
			right = t.maxRank or "",
			tooltip = W.TextTooltip(t.npc or "Trainer", where(t), W.FACTION_NAMES[t.faction] or "", t.notes),
		})
		flow:Band(top, W.RowStyle(i))
	end

	for i, t in ipairs(mine) do trainerRow(t, i, false) end
	if #mine == 0 then flow:Text("|cff808080No trainers recorded for your faction.|r", { indent = 4 }) end

	if not hideOther and #other > 0 then
		local open = self.showOther[self.prof]
		flow:Row({
			indent = 4,
			icon = W.CollapseIcon(not open),
			left = ("|cff9fb4ff%s other-faction trainers (%d)|r"):format(open and "Hide" or "Show", #other),
			onClick = function()
				self.showOther[self.prof] = not open
				self:Refresh()
			end,
		})
		if open then
			for i, t in ipairs(other) do trainerRow(t, i, true) end
		end
	end
end

---------------------------------------------------------------------------
-- Side quests
---------------------------------------------------------------------------

function page:RenderQuests(quests, me, hideOther)
	local flow = self.flow
	flow:Row({ left = "|cffffd100Related Quests|r", font = "GameFontNormal" })
	local list = {}
	for _, q in ipairs(quests) do
		if not hideOther or factionRank(q.faction, me) < 2 then list[#list + 1] = q end
	end
	table.sort(list, function(a, b) return (a.level or 0) < (b.level or 0) end)
	for i, q in ipairs(list) do
		local top = flow.y
		flow:Space(3)
		self:RenderQuestBlock(q, 4, me, hideOther)
		flow:Space(3)
		flow:Band(top, W.RowStyle(i))
	end
end

ns.UI:RegisterPage("training", page)
