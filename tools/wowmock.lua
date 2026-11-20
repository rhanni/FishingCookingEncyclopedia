-- Minimal stand-in for the WoW client API, for offline smoke tests only.
-- Frames are permissive objects: unknown setter-style methods are no-ops,
-- getters return nil, and a few methods keep real state (text, shown,
-- scripts, sizes, checked) so the addon's logic can run end to end.
-- Not shipped with the addon (not listed in the .toc).

local M = { errors = {}, timers = {}, events = {}, printed = {} }

local function err(msg) M.errors[#M.errors + 1] = tostring(msg) end
M.err = err

local methods = {}
local mt = {}
local METHOD_PREFIX = { "Set", "Get", "Is", "Create", "Hook", "Register", "Unregister", "Enable", "Disable",
	"Show", "Hide", "Clear", "Lock", "Unlock", "Update", "Add", "Cancel", "Click", "Raise", "Lower" }

mt.__index = function(o, k)
	local m = methods[k]
	if m then return m end
	if type(k) ~= "string" then return nil end
	for _, p in ipairs(METHOD_PREFIX) do
		if k:sub(1, #p) == p then
			if p == "Get" then return function() return nil end end
			if p == "Is" then return function() return false end end
			if p == "Create" then return function() return M.new(k) end end
			return function() end
		end
	end
	return nil -- unknown fields (e.g. frame.Icon) are nil, like the real client
end

M.all = {}
function M.new(kind)
	local o = setmetatable({ __kind = kind, __scripts = {}, __shown = true, __points = {} }, mt)
	M.all[#M.all + 1] = o
	return o
end

-- Geometry: frames have no position unless a test gives them one.
function M.setRect(o, l, b, w, h) o.__rect = { l, b, w, h } end
M.rectCalls = 0
function methods.GetRect(o) M.rectCalls = M.rectCalls + 1; if o.__rect then return table.unpack(o.__rect) end end
function methods.GetLeft(o) return o.__rect and o.__rect[1] end
function methods.GetBottom(o) return o.__rect and o.__rect[2] end
function methods.GetEffectiveScale() return 1 end
function methods.IsVisible(o) return o.__shown end
function methods.SetPoint(o, ...) o.__points[#o.__points + 1] = { ... } end
function methods.ClearAllPoints(o) o.__points = {} end
function methods.GetNumPoints(o) return #o.__points end
function methods.GetPoint(o, i) return table.unpack(o.__points[i or 1] or {}) end

function methods.SetScript(o, name, fn) o.__scripts[name] = fn end
function methods.GetScript(o, name) return o.__scripts[name] end
function methods.HookScript(o, name, fn)
	local prev = o.__scripts[name]
	o.__scripts[name] = prev and function(...) prev(...); fn(...) end or fn
end
function methods.Show(o)
	local was = o.__shown; o.__shown = true
	if not was and o.__scripts.OnShow then o.__scripts.OnShow(o) end
end
function methods.Hide(o)
	local was = o.__shown; o.__shown = false
	if was and o.__scripts.OnHide then o.__scripts.OnHide(o) end
end
function methods.GetChildren(o) return table.unpack(o.__children or {}) end
function methods.GetParent(o) return o.__parent end
function methods.IsShown(o) return o.__shown end
function methods.SetShown(o, v) o.__shown = v and true or false end
function methods.RegisterEvent(o, e)
	M.events[e] = M.events[e] or {}
	table.insert(M.events[e], o)
end
function methods.SetText(o, t) o.__text = t end
function methods.GetText(o) return o.__text or "" end
function methods.SetChecked(o, v) o.__checked = v end
function methods.GetChecked(o) return o.__checked end
function methods.SetTexture(o, t) o.__tex = t; return true end
function methods.SetWidth(o, w) o.__w = w end
function methods.SetHeight(o, h) o.__h = h end
function methods.SetSize(o, w, h) o.__w = w; o.__h = h end
function methods.GetWidth(o) return o.__w or 420 end
function methods.GetHeight(o) return o.__h or 24 end
function methods.GetFrameLevel() return 1 end
function methods.SetVerticalScroll(o, v) o.__vs = v end
function methods.GetVerticalScroll(o) return o.__vs or 0 end
function methods.GetVerticalScrollRange() return 500 end
function methods.SetScrollChild(o, c) o.__child = c end
function methods.SetupMenu(o, generator) o.__menu = generator end

-- Runs a dropdown's menu generator against a fake menu description and
-- returns the checkboxes it created: { text=, isSelected=fn, setSelected=fn }.
function M.buildMenu(dropdown)
	local items = { buttons = {}, checks = {} }
	local root = {}
	function root:CreateButton(text, fn) items.buttons[#items.buttons + 1] = { text = text, fn = fn } end
	function root:CreateCheckbox(text, isSel, setSel) items.checks[#items.checks + 1] = { text = text, isSelected = isSel, setSelected = setSel } end
	dropdown.__menu(dropdown, root)
	return items
end
function methods.GetStringHeight(o)
	local len = #(o.__text or "")
	local per = math.max(10, math.floor((o.__w or 300) / 6))
	return 12 * math.max(1, math.ceil(len / per))
end

-- Fire a game event at every frame that registered it.
function M.fire(event, ...)
	for _, f in ipairs(M.events[event] or {}) do
		local fn = f.__scripts.OnEvent
		if fn then
			local ok, e = pcall(fn, f, event, ...)
			if not ok then err(event .. ": " .. tostring(e)) end
		end
	end
end

-- Run queued C_Timer callbacks (rounds = how many waves of new timers to run).
function M.flush(rounds)
	for _ = 1, rounds or 5 do
		if #M.timers == 0 then return end
		local batch = M.timers
		M.timers = {}
		for _, fn in ipairs(batch) do
			local ok, e = pcall(fn)
			if not ok then err("timer: " .. tostring(e)) end
		end
	end
end

function M.click(o, button)
	local fn = o.__scripts.OnClick
	if fn then fn(o, button or "LeftButton") end
end

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------

CreateFrame = function(kind, name, parent, template)
	local o = M.new(kind)
	if template == "LargeSideTabButtonTemplate" then o.Icon = M.new("Texture") end
	if type(parent) == "table" then
		o.__parent = parent
		parent.__children = parent.__children or {}
		table.insert(parent.__children, o)
	end
	if name then _G[name] = o end
	return o
end

local PROFS = {
	{ "Herbalism", 0, 210, 300, 0, 0, 182, 0 },
	{ "Alchemy", 0, 195, 300, 0, 0, 171, 0 },
	{ "First Aid", 0, 300, 300, 0, 0, 129, 0 },
	{ "Fishing", 0, 240, 300, 0, 0, 356, 25 },
	{ "Cooking", 0, 225, 300, 0, 0, 185, 0 },
}
GetProfessions = function() return 1, 2, 3, 4, 5 end
GetProfessionInfo = function(i) return table.unpack(PROFS[i]) end
UnitFactionGroup = function() return "Alliance" end
IsPlayerSpell = function(id) return id == 7751 end
GetRealmName = function() return "Mock Realm" end
GetNormalizedRealmName = function() return "MockRealm" end
GetMoneyString = function(c) return tostring(c) .. "c" end
time = os.time

string.join = function(sep, ...) return table.concat({ ... }, sep) end
tostringall = function(...)
	local n = select("#", ...)
	local t = { ... }
	for i = 1, n do t[i] = tostring(t[i]) end
	return table.unpack(t, 1, n)
end
geterrorhandler = function() return err end
EnumerateFrames = function(prev)
	if not prev then return M.all[1] end
	for i, o in ipairs(M.all) do
		if o == prev then return M.all[i + 1] end
	end
end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }
print = function(...) M.printed[#M.printed + 1] = table.concat({ tostringall(...) }, " ") end
SlashCmdList = {}

C_Item = {
	GetItemIconByID = function() return 134400 end,
	GetItemNameByID = function() return nil end,
}
C_AddOns = {
	GetAddOnMetadata = function() return "test" end,
	IsAddOnLoaded = function() return true end,
	LoadAddOn = function() end,
}
EventUtil = { ContinueOnAddOnLoaded = function(_, fn) fn() end }
C_Timer = {
	After = function(_, fn) M.timers[#M.timers + 1] = fn end,
	NewTimer = function(_, fn)
		local h = { cancelled = false }
		function h:Cancel() self.cancelled = true end
		M.timers[#M.timers + 1] = function() if not h.cancelled then fn() end end
		return h
	end,
}
hooksecurefunc = function(t, name, fn)
	if type(t) == "string" then t, name, fn = _G, t, name end
	local orig = t[name]
	t[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return table.unpack(r)
	end
end

GameTooltip = M.new("GameTooltip")
GameTooltip_Hide = function() end
ShowUIPanel = function(f) f:Show() end
HideUIPanel = function(f) f:Hide() end

Enum = { AuctionHouseSortOrder = { Price = 0 } }
C_AuctionHouse = {
	MakeItemKey = function(id) return { itemID = id } end,
	SendSearchQuery = function(itemKey) M.lastQuery = itemKey.itemID end,
	IsThrottledMessageSystemReady = function() return true end,
	GetNumCommoditySearchResults = function() return 2 end,
	GetCommoditySearchResultInfo = function(id, i)
		return { unitPrice = ((id % 97) + 1) * 10 * i, quantity = 5 * i }
	end,
	GetNumItemSearchResults = function() return 0 end,
	-- Batch/browse: every 5th item ID has no listings.
	SearchForItemKeys = function(keys) M.lastKeys = keys end,
	HasFullBrowseResults = function() return true end,
	RequestMoreBrowseResults = function() end,
	GetBrowseResults = function()
		local out = {}
		for _, k in ipairs(M.browseKeys or {}) do
			if k.itemID % 5 ~= 0 then
				out[#out + 1] = { itemKey = k, minPrice = ((k.itemID % 97) + 1) * 10, totalQuantity = 7 }
			end
		end
		return out
	end,
}
AuctionHouseFrame = M.new("Frame")
AuctionHouseFrame:Hide()

ProfessionsFrame = M.new("Frame")
ProfessionsFrame.BookPage = M.new("Frame")
ProfessionsFrame.CraftingPage = M.new("Frame")
ProfessionsFrame.ProfessionsOverviewTab = M.new("Frame")
ProfessionsFrame.rightProfessionTabs = { M.new("Frame"), M.new("Frame") }
ProfessionsFrame.RefreshRightTabs = function() end
ProfessionsFrame.RightTabSelected = function() end
ProfessionsFrame.SelectBookPage = function() end
ProfessionsFrame:Hide()
ToggleProfessionsBook = function() ProfessionsFrame:Show() end

return M
