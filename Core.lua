-- Fishing & Cooking Encyclopedia - Core
-- Namespace, saved variables, event dispatch, internal messages, slash commands.

local addonName, ns = ...
_G.FishingCookingEncyclopedia = ns -- exposed for /dump debugging only

ns.name = addonName
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "dev"

-- Addon icon (64x64 TGA, source art in tools/art/TabIcon.svg).
ns.ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\TabIcon"

local PREFIX = "|T" .. ns.ICON .. ":0|t |cff4fc3f7Fishing & Cooking|r: "

function ns:Print(...)
	print(PREFIX .. string.join(" ", tostringall(...)))
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local DEFAULTS = {
	settings = {
		autoScan = false,          -- scan fish prices automatically when the AH opens
		autoScanCooldown = 300,    -- seconds between automatic scans
		historyLength = 14,        -- scans of history kept per item
		scanCooked = true,         -- include cooked dishes made from fish
		scanRecipeItems = false,   -- include recipe scrolls (off by default)
		detailedScan = false,      -- per-item scan (slow) instead of one batch request
		passiveCapture = true,     -- record tracked prices while you browse the AH
		hideOtherFaction = false,  -- hide the other faction's vendors/trainers
		cookingUnknownOnly = false, -- Cooking page: show only recipes you don't know
		cookingBenefits = {},      -- Cooking page: [benefit key] = true (union filter)
		rowStyle = "A",            -- alternating row style: "A", "B" or "C"
		tabPosition = "bottom",    -- profession window tab: "bottom" of the tab column, or "top" (under Blizzard's tabs)
		collapsedTiers = {},       -- [tier label] = true when collapsed on the Fishing page
	},
	prices = {},                   -- [realmKey][itemID] = { last = {...}, history = {...} }
	lastScan = {},                 -- [realmKey] = time()
}

local function applyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			applyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

---------------------------------------------------------------------------
-- Game event dispatch: ns:On("EVENT", fn)
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns:On(event, fn)
	if not eventHandlers[event] then
		eventHandlers[event] = {}
		-- pcall: an event this client doesn't know must not break loading.
		local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
		if not ok then ns.unknownEvents = ns.unknownEvents or {}; ns.unknownEvents[event] = true end
	end
	table.insert(eventHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end)

---------------------------------------------------------------------------
-- Internal messages: ns:Listen("MSG", fn) / ns:Fire("MSG", ...)
--   DB_READY, PRICES_UPDATED(itemID), SCAN_STARTED(total),
--   SCAN_PROGRESS(done, total), SCAN_FINISHED(count), SCAN_ABORTED(reason)
---------------------------------------------------------------------------

local listeners = {}

function ns:Listen(msg, fn)
	listeners[msg] = listeners[msg] or {}
	table.insert(listeners[msg], fn)
end

function ns:Fire(msg, ...)
	local list = listeners[msg]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function ns.FormatMoney(copper)
	if not copper then return "|cff808080--|r" end
	copper = math.floor(copper + 0.5)
	if GetMoneyString then
		return GetMoneyString(copper, true)
	end
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = ("|cffffd700%dg|r"):format(g) end
	if s > 0 or g > 0 then out[#out + 1] = ("|cffc7c7cf%ds|r"):format(s) end
	out[#out + 1] = ("|cffeda55f%dc|r"):format(c)
	return table.concat(out, " ")
end

function ns.FormatAge(seconds)
	if not seconds then return "never" end
	if seconds < 3600 then return ("%dm ago"):format(math.max(1, math.floor(seconds / 60))) end
	if seconds < 86400 then return ("%dh ago"):format(math.floor(seconds / 3600)) end
	return ("%dd ago"):format(math.floor(seconds / 86400))
end

-- Accepts an itemID, "12345", or an item link.
function ns.ParseItemID(input)
	if type(input) == "number" then return input end
	if type(input) ~= "string" then return nil end
	return tonumber(input:match("item:(%d+)") or input:match("^%s*(%d+)%s*$"))
end

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------

ns:On("ADDON_LOADED", function(name)
	if name ~= addonName then return end
	FCE_DB = FCE_DB or {}
	applyDefaults(FCE_DB, DEFAULTS)
	ns.db = FCE_DB
	ns:Fire("DB_READY")
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function onOff(v) return v and "|cff20ff20on|r" or "|cffff2020off|r" end

local commands = {}

commands[""] = function()
	if ns.UI and ns.UI.Toggle then
		ns.UI:Toggle()
	else
		ns:Print("The journal UI isn't built yet. Try /fce help.")
	end
end

commands.scan = function()
	if ns.Scanner then ns.Scanner:Start(false) end
end

commands.stop = function()
	if ns.Scanner then ns.Scanner:Stop("stopped by user") end
end

commands.autoscan = function(arg)
	local s = ns.db.settings
	if arg == "on" then s.autoScan = true
	elseif arg == "off" then s.autoScan = false
	else s.autoScan = not s.autoScan end
	ns:Print("Auto-scan on auction house open:", onOff(s.autoScan))
	ns:Fire("SETTINGS_CHANGED", "autoScan")
end

commands.price = function(arg)
	local itemID = ns.ParseItemID(arg)
	if not itemID then return ns:Print("Usage: /fce price <itemID or item link>") end
	local p = ns.Prices:Get(itemID)
	if not p then return ns:Print(("No price data for item %d."):format(itemID)) end
	ns:Print(("Item %d: min %s, market %s, %d listed (%s)"):format(
		itemID, ns.FormatMoney(p.min), ns.FormatMoney(p.market), p.quantity or 0, ns.FormatAge(p.age)))
end

commands.reset = function(arg)
	if arg ~= "prices" then return ns:Print("Type '/fce reset prices' to wipe price data for this realm.") end
	ns.Prices:WipeRealm()
	ns:Print("Price data for this realm wiped.")
end

commands.tab = function(arg)
	arg = (arg or ""):lower()
	if arg == "top" or arg == "bottom" then
		if ns.UI and ns.UI.SetTabPosition then ns.UI:SetTabPosition(arg) end
	end
	ns:Print("Profession window tab position:", ns.db.settings.tabPosition,
		"(use /fce tab top or /fce tab bottom to change it)")
end

commands.help = function()
	ns:Print("Commands:")
	print("  /fce - open the encyclopedia")
	print("  /fce scan - scan fish & dish prices (auction house must be open)")
	print("  /fce stop - stop a running scan")
	print("  /fce autoscan [on|off] - toggle auto-scan when the AH opens (now " .. onOff(ns.db.settings.autoScan) .. ")")
	print("  /fce price <item> - show stored price for an item")
	print("  /fce reset prices - wipe stored prices for this realm")
	print("  /fce tab [top|bottom] - where our tab sits in the profession window (now " .. ns.db.settings.tabPosition .. ")")
end

SLASH_FISHINGCOOKINGENCYCLOPEDIA1 = "/fce"
SLASH_FISHINGCOOKINGENCYCLOPEDIA2 = "/fishcook"
SlashCmdList.FISHINGCOOKINGENCYCLOPEDIA = function(input)
	local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	local fn = commands[cmd]
	if fn then fn(rest) else commands.help() end
end
