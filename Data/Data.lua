-- Fishing & Cooking Encyclopedia - Data access layer
-- The data tables (items, zones, pools, recipes, vendors) are filled in by
-- Data\Fishing.lua and Data\Cooking.lua, generated from the research folder.
-- Everything else in the addon reads data only through these accessors.

local _, ns = ...

local Data = {
	items = {},    -- [itemID] = { name=, kind="fish"|"chest"|"junk"|"quest"|"misc"|"dish"|"recipe", ... }
	zones = {},    -- array of { name=, continent=, faction=, skill=, noGetaway=, fish={}, pools={}, extras={}, notes= }
	pools = {},    -- [poolName] = { yields = {itemIDs}, notes= }
	recipes = {},  -- array of { name=, spellID=, createsID=, skill=, levels={}, reagents={{id,n}}, learn={...} }
	vendors = {},  -- [npcID] = { name=, zone=, coords={x,y}, faction="A"|"H"|"N" }
}
ns.Data = Data

-- Indexes built lazily on first use.
local recipesByReagent, recipeByCreated

local function buildIndexes()
	recipesByReagent, recipeByCreated = {}, {}
	for _, r in ipairs(Data.recipes) do
		if r.createsID then recipeByCreated[r.createsID] = r end
		for _, reagent in ipairs(r.reagents or {}) do
			local id = reagent[1]
			recipesByReagent[id] = recipesByReagent[id] or {}
			table.insert(recipesByReagent[id], r)
		end
	end
end

function Data:InvalidateIndexes()
	recipesByReagent, recipeByCreated = nil, nil
end

-- Recipes that use the given fish as a reagent.
function Data:GetRecipesUsing(itemID)
	if not recipesByReagent then buildIndexes() end
	return recipesByReagent[itemID] or {}
end

function Data:GetRecipeCreating(itemID)
	if not recipeByCreated then buildIndexes() end
	return recipeByCreated[itemID]
end

---------------------------------------------------------------------------
-- Recipe benefits: classified from each recipe's effect text so the Cooking
-- page can filter by them. Order here is the order shown in the filter.
---------------------------------------------------------------------------

local BENEFITS = {
	{ key = "ap",        label = "Attack Power",        patterns = { "attack power" } },
	{ key = "spell",     label = "Spell Power",         patterns = { "spell damage", "spell power" } },
	{ key = "healing",   label = "Healing Power",       patterns = { "healing power", "healing" } },
	{ key = "crit",      label = "Critical Strike",     patterns = { "critical strike" } },
	{ key = "str",       label = "Strength",            patterns = { "strength" } },
	{ key = "agi",       label = "Agility",             patterns = { "agility" } },
	{ key = "stam",      label = "Stamina",             patterns = { "stamina" } },
	{ key = "int",       label = "Intellect",           patterns = { "intellect" } },
	{ key = "spirit",    label = "Spirit",              patterns = { "spirit" } },
	{ key = "armor",     label = "Armor",               patterns = { "%d+ armor" } },
	{ key = "mana",      label = "Mana Regeneration",   patterns = { "mana every", "mana per", "mp5" } },
	{ key = "hpregen",   label = "Health Regeneration", patterns = { "health every" } },
	{ key = "fishing",   label = "Fishing Skill",       patterns = { "fishing skill" } },
	{ key = "xp",        label = "Experience Bonus",    patterns = { "experience" } },
	{ key = "transform", label = "Transformation",      patterns = { "eat me", "transform" } },
}
Data.BENEFITS = BENEFITS

local NOBUFF = { key = "none", label = "No Stat Buff" }

-- Returns a set { [key] = true } for the recipe (cached on the recipe).
function Data:GetRecipeBenefits(r)
	if r._benefits then return r._benefits end
	-- Match tooltip wording only: drop "-- comments" and (parenthetical notes)
	-- so a research remark like "(removed the old Stamina buff)" can't add a
	-- benefit the food doesn't have.
	local text = (r.effect or ""):lower():gsub("%-%-.*$", ""):gsub("%b()", "")
	local set, statBuff = {}, false
	for _, b in ipairs(BENEFITS) do
		for _, p in ipairs(b.patterns) do
			if text:find(p) then
				set[b.key] = true
				if b.key ~= "xp" then statBuff = true end
				break
			end
		end
	end
	if r.fishingSkillBonus then set.fishing = true; statBuff = true end
	if not statBuff then set.none = true end
	r._benefits = set
	return set
end

-- Benefit types present in the data, in display order, with recipe counts:
-- array of { key=, label=, count= }.
function Data:GetBenefitTypes()
	local counts = {}
	for _, r in ipairs(self.recipes) do
		for key in pairs(self:GetRecipeBenefits(r)) do counts[key] = (counts[key] or 0) + 1 end
	end
	local out = {}
	for _, b in ipairs(BENEFITS) do
		if counts[b.key] then out[#out + 1] = { key = b.key, label = b.label, count = counts[b.key] } end
	end
	if counts.none then out[#out + 1] = { key = NOBUFF.key, label = NOBUFF.label, count = counts.none } end
	return out
end

function Data:GetBenefitLabel(key)
	for _, b in ipairs(BENEFITS) do if b.key == key then return b.label end end
	return key == "none" and NOBUFF.label or key
end

-- Fallback names for non-fish reagents, used until the client caches them.
Data.reagentNames = {
	[159] = "Refreshing Spring Water", [1179] = "Ice Cold Milk", [2678] = "Mild Spices",
	[2692] = "Hot Spices", [3713] = "Soothing Spices", [3712] = "Turtle Meat",
	[3404] = "Buzzard Wing", [12184] = "Raptor Flesh", [5468] = "Soft Frenzy Flesh",
	[5503] = "Clam Meat", [5504] = "Tangy Clam Meat", [4655] = "Giant Clam Meat",
	[7974] = "Zesty Clam Meat",
}

function Data:GetItemName(itemID)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
	if name then return name end
	local entry = self.items[itemID]
	return (entry and entry.name) or self.reagentNames[itemID] or ("item:" .. itemID)
end

-- Zones grouped by fishing tier (min skill to catch / skill where nothing gets
-- away). Classic and Forever use six tiers: 1/25, 1/75, 55/150, 130/225,
-- 205/300, 330/425. Zones whose tier is unknown go in a final group.
-- Returns array of { min=, max=, label=, zones={...} } sorted by tier.
function Data:GetZoneBrackets()
	local groups, byKey = {}, {}
	for _, z in ipairs(self.zones) do
		local key = z.skill and (z.skill .. "/" .. tostring(z.noGetaway)) or "unknown"
		local g = byKey[key]
		if not g then
			local label
			if not z.skill then
				label = "Skill unknown (new in Forever)"
			elseif z.noGetaway then
				label = ("Skill %d - all catches at %d"):format(z.skill, z.noGetaway)
			else
				label = ("Skill %d"):format(z.skill)
			end
			g = { min = z.skill, max = z.noGetaway, label = label, zones = {} }
			byKey[key] = g
			groups[#groups + 1] = g
		end
		table.insert(g.zones, z)
	end
	local HUGE = math.huge
	table.sort(groups, function(a, b)
		if (a.min or HUGE) ~= (b.min or HUGE) then return (a.min or HUGE) < (b.min or HUGE) end
		return (a.max or HUGE) < (b.max or HUGE)
	end)
	for _, g in ipairs(groups) do
		table.sort(g.zones, function(a, b) return a.name < b.name end)
	end
	return groups
end

---------------------------------------------------------------------------
-- Load: turn the generated research tables (ns.RawFishing, ns.RawCooking)
-- into the runtime tables above. Subzones with their own tier (e.g. Azshara's
-- Bay of Storms) become zone entries of their own named "Parent: Subzone".
---------------------------------------------------------------------------

local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

function Data:Load()
	if self.loaded then return end
	local F, C = ns.RawFishing, ns.RawCooking

	if F then
		for id, item in pairs(F.items or {}) do self.items[id] = item end
		for name, pool in pairs(F.pools or {}) do self.pools[name] = pool end
		for _, z in ipairs(F.zones or {}) do
			z.pools = z.pools or {}
			z.extras = z.extras or {}
			table.insert(self.zones, z)
			for _, sub in ipairs(z.subzones or {}) do
				local child = copy(sub)
				child.parent = z.name
				child.shortName = sub.name
				child.name = z.name .. ": " .. sub.name
				child.continent = z.continent
				child.faction = z.faction
				child.source = z.source
				child.fishSource = z.fishSource
				child.pools = child.pools or {}
				child.extras = child.extras or {}
				table.insert(self.zones, child)
			end
		end
		self.mechanic = F.mechanic
		self.timeOfDay = F.timeOfDay or {}
		self.seasonal = F.seasonal or {}
		self.trophyOf = F.trophyOf or {}
		self.bloatedOf = F.bloatedOf or {}
		self.notFishable = F.notFishable or {}
		self.fishingChanges = F.foreverChanges or {}
	end

	if C then
		for _, r in ipairs(C.recipes or {}) do
			table.insert(self.recipes, r)
			if r.createsID and not self.items[r.createsID] then
				self.items[r.createsID] = { name = r.createsName or r.name, kind = "dish" }
			end
			local recipeItemID = r.learn and r.learn.recipeItemID
			if recipeItemID and not self.items[recipeItemID] then
				self.items[recipeItemID] = { name = "Recipe: " .. r.name, kind = "recipe" }
			end
		end
		self.otherUses = C.otherUses or {}
		self.baitAndTackle = C.baitAndTackle or {}
		self.cookingChanges = C.foreverChanges or {}
	end

	local T = ns.RawTraining
	if T and T.professions then
		self.training = T.professions -- { fishing = { ranks, trainers, quests }, cooking = {...} }
		self.trainingChanges = T.foreverChanges or {}
	end

	-- Raw Spinefin Halibut is a reagent for a Forever fishing food but is sold
	-- by fishing suppliers rather than fished.
	if not self.items[8959] then
		self.items[8959] = { name = "Raw Spinefin Halibut", kind = "fish", notes = "Sold by fishing suppliers in Forever" }
	end

	self:InvalidateIndexes()
	self.loaded = true
	-- Release the raw tables; everything now lives in Data.
	ns.RawFishing, ns.RawCooking, ns.RawTraining = nil, nil, nil
end

-- Registered before any other DB_READY listener (Data.lua loads first).
ns:Listen("DB_READY", function() Data:Load() end)

-- The only items the auction scanner looks at: fished items, the dishes
-- made from them, and (optionally) the recipe scrolls for those dishes.
function Data:GetScanItemIDs()
	local settings = ns.db and ns.db.settings or {}
	local seen, list = {}, {}
	local function add(id)
		if id and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end

	for id, item in pairs(self.items) do
		if item.kind == "fish" and not item.noAuction then add(id) end
	end
	for _, r in ipairs(self.recipes) do
		local usesFish = false
		for _, reagent in ipairs(r.reagents or {}) do
			if seen[reagent[1]] then usesFish = true break end
		end
		if usesFish then
			if settings.scanCooked ~= false then add(r.createsID) end
			if settings.scanRecipeItems and r.learn and r.learn.recipeItemID then add(r.learn.recipeItemID) end
		end
	end
	table.sort(list)
	return list
end
