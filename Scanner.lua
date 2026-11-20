-- Fishing & Cooking Encyclopedia - Targeted auction house scanner
--
-- Unlike a full-AH scanner, this only looks at the items the encyclopedia
-- cares about (fish, dishes made from fish, optionally recipe scrolls), using
-- the modern C_AuctionHouse API that WoW: Forever's commodity AH uses.
--
-- Two modes:
--   Batch (default, the Auctionator approach): one SearchForItemKeys request
--     for every tracked item at once. The server answers with one summary row
--     per listed item (lowest price + total quantity) via BROWSE_RESULTS_UPDATED;
--     items absent from the answer have no listings. Takes a few seconds.
--   Detailed (setting): one SendSearchQuery per item, reading every listing so
--     the "market" price can be the average of the cheapest 25% of units.
--     Slower because each query waits on the AH throttle.
-- Also: passive capture records prices for tracked items whenever you browse
-- the AH yourself (also an Auctionator technique).

local _, ns = ...

local Scanner = {}
ns.Scanner = Scanner

local ITEM_TIMEOUT = 2.5       -- detailed mode: seconds to wait per item before "no listings"
local STEP_DELAY = 0.05        -- detailed mode: pause between queries
local BATCH_TIMEOUT = 15       -- batch mode: give up waiting for more pages after this
local MARKET_SLICE = 0.25      -- market price = avg of cheapest 25% of listed units

local state = {
	running = false,
	mode = nil,             -- "batch" or "detailed"
	queue = nil,
	wanted = nil,           -- [itemID] = true for the current scan
	index = 0,
	current = nil,          -- detailed mode: itemID being searched
	waitingThrottle = false,
	timer = nil,
}

local function ahAvailable()
	return C_AuctionHouse and C_AuctionHouse.SendSearchQuery and AuctionHouseFrame and AuctionHouseFrame:IsShown()
end

function Scanner:IsRunning() return state.running end
function Scanner:GetProgress() return state.index, state.queue and #state.queue or 0 end

---------------------------------------------------------------------------
-- Price math
---------------------------------------------------------------------------

-- rows: array of { unitPrice, quantity } sorted cheapest first.
local function summarize(rows)
	local total = 0
	for i = 1, #rows do total = total + rows[i].quantity end
	if total == 0 then return nil, nil, 0 end

	local target = math.max(1, math.ceil(total * MARKET_SLICE))
	local taken, cost = 0, 0
	for i = 1, #rows do
		local take = math.min(rows[i].quantity, target - taken)
		cost = cost + take * rows[i].unitPrice
		taken = taken + take
		if taken >= target then break end
	end
	return rows[1].unitPrice, cost / taken, total
end

local function readCommodityResults(itemID)
	local rows = {}
	local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
	for i = 1, n do
		local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if r and r.unitPrice and r.quantity then
			rows[#rows + 1] = { unitPrice = r.unitPrice, quantity = r.quantity }
		end
	end
	table.sort(rows, function(a, b) return a.unitPrice < b.unitPrice end)
	return rows
end

local function readItemResults(itemKey)
	local rows = {}
	local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
	for i = 1, n do
		local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		if r and r.buyoutAmount and r.quantity and r.quantity > 0 then
			rows[#rows + 1] = { unitPrice = r.buyoutAmount / r.quantity, quantity = r.quantity }
		end
	end
	table.sort(rows, function(a, b) return a.unitPrice < b.unitPrice end)
	return rows
end

---------------------------------------------------------------------------
-- Queue processing
---------------------------------------------------------------------------

local function cancelTimer()
	if state.timer then state.timer:Cancel(); state.timer = nil end
end

local advance -- forward declaration

local function finishItem(rows)
	cancelTimer()
	local itemID = state.current
	state.current = nil
	if not itemID then return end

	local minUnit, market, qty = summarize(rows or {})
	ns.Prices:Record(itemID, minUnit, market, qty)
	ns:Fire("SCAN_PROGRESS", state.index, #state.queue)
	C_Timer.After(STEP_DELAY, advance)
end

local function sendQuery()
	if not state.running then return end
	if not ahAvailable() then return Scanner:Stop("auction house closed") end

	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		state.waitingThrottle = true -- resumed by AUCTION_HOUSE_THROTTLED_SYSTEM_READY
		return
	end
	state.waitingThrottle = false

	local itemID = state.queue[state.index]
	state.current = itemID
	local itemKey = C_AuctionHouse.MakeItemKey(itemID)
	local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
	C_AuctionHouse.SendSearchQuery(itemKey, sorts, true)

	cancelTimer()
	state.timer = C_Timer.NewTimer(ITEM_TIMEOUT, function()
		state.timer = nil
		if state.current == itemID then finishItem(nil) end -- no listings / no response
	end)
end

advance = function()
	if not state.running then return end
	state.index = state.index + 1
	if state.index > #state.queue then
		local count = #state.queue
		state.running = false
		ns.Prices:SetLastScanTime(time())
		ns:Print(("Price scan complete: %d items."):format(count))
		ns:Fire("SCAN_FINISHED", count)
		return
	end
	sendQuery()
end

---------------------------------------------------------------------------
-- Batch mode (SearchForItemKeys)
---------------------------------------------------------------------------

local function batchSupported()
	return C_AuctionHouse and C_AuctionHouse.SearchForItemKeys and C_AuctionHouse.GetBrowseResults and true or false
end

-- Reads the current browse results, keeping only items in `wanted`.
-- Returns [itemID] = { min =, quantity = } (variants of one itemID merged).
local function readBrowseResults(wanted)
	local out = {}
	for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
		local id = r.itemKey and r.itemKey.itemID
		if id and wanted[id] and r.minPrice then
			local e = out[id]
			if not e then
				out[id] = { min = r.minPrice, quantity = r.totalQuantity or 0 }
			else
				e.min = math.min(e.min, r.minPrice)
				e.quantity = e.quantity + (r.totalQuantity or 0)
			end
		end
	end
	return out
end

local function finishBatch()
	if not state.running or state.mode ~= "batch" then return end
	if state.timer then state.timer:Cancel(); state.timer = nil end
	local found = readBrowseResults(state.wanted)
	local listed = 0
	for _, id in ipairs(state.queue) do
		local e = found[id]
		if e then
			-- The summary only has the lowest price, so it stands in for "market" too.
			ns.Prices:Record(id, e.min, e.min, e.quantity)
			listed = listed + 1
		else
			ns.Prices:Record(id, nil, nil, 0)
		end
	end
	local count = #state.queue
	state.running = false
	state.index = count
	ns.Prices:SetLastScanTime(time())
	ns:Print(("Price scan complete: %d items, %d listed."):format(count, listed))
	ns:Fire("SCAN_FINISHED", count)
end

local function sendBatch()
	if not state.running then return end
	if not ahAvailable() then return Scanner:Stop("auction house closed") end
	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		state.waitingThrottle = true
		return
	end
	state.waitingThrottle = false

	local keys = {}
	for _, id in ipairs(state.queue) do keys[#keys + 1] = C_AuctionHouse.MakeItemKey(id) end
	local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
	C_AuctionHouse.SearchForItemKeys(keys, sorts)

	if state.timer then state.timer:Cancel() end
	state.timer = C_Timer.NewTimer(BATCH_TIMEOUT, function()
		state.timer = nil
		finishBatch() -- record whatever arrived
	end)
end

-- Called on BROWSE_RESULTS_UPDATED / AUCTION_HOUSE_BROWSE_RESULTS_ADDED.
local function onBrowseResults()
	if state.running and state.mode == "batch" then
		local got = 0
		for _ in pairs(readBrowseResults(state.wanted)) do got = got + 1 end
		state.index = got
		ns:Fire("SCAN_PROGRESS", got, #state.queue)
		if C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() then
			C_AuctionHouse.RequestMoreBrowseResults()
		else
			finishBatch()
		end
		return
	end

	-- Passive capture: you browsed the AH yourself; record any tracked items
	-- that showed up. Absent items are left alone (the browse wasn't for them).
	if state.running or ns.db.settings.passiveCapture == false then return end
	local wanted = {}
	for _, id in ipairs(ns.Data:GetScanItemIDs()) do wanted[id] = true end
	for id, e in pairs(readBrowseResults(wanted)) do
		ns.Prices:Record(id, e.min, e.min, e.quantity)
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- isAuto: true when triggered by the auto-scan setting.
function Scanner:Start(isAuto)
	if state.running then return ns:Print("A scan is already running.") end
	if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery then
		return ns:Print("This client has no C_AuctionHouse API; scanning is unavailable.")
	end
	if not ahAvailable() then
		if not isAuto then ns:Print("Open the auction house to scan prices.") end
		return
	end

	local queue = ns.Data:GetScanItemIDs()
	if #queue == 0 then
		return ns:Print("No fish or dishes in the database to scan yet.")
	end

	state.running = true
	state.queue = queue
	state.wanted = {}
	for _, id in ipairs(queue) do state.wanted[id] = true end
	state.index = 0
	state.current = nil
	ns:Fire("SCAN_STARTED", #queue)

	if not ns.db.settings.detailedScan and batchSupported() then
		state.mode = "batch"
		ns:Print(("Scanning prices for %d fish and dishes..."):format(#queue))
		sendBatch()
	else
		state.mode = "detailed"
		ns:Print(("Detailed scan of %d fish and dishes (slower)..."):format(#queue))
		advance()
	end
end

function Scanner:Stop(reason)
	if not state.running then return end
	cancelTimer()
	state.running = false
	state.current = nil
	state.waitingThrottle = false
	ns:Print("Scan stopped" .. (reason and (": " .. reason) or "") .. ".")
	ns:Fire("SCAN_ABORTED", reason)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

ns:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
	if state.running and itemID == state.current then
		finishItem(readCommodityResults(itemID))
	end
end)

ns:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
	if state.running and itemKey and itemKey.itemID == state.current then
		finishItem(readItemResults(itemKey))
	end
end)

ns:On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function()
	if state.running and state.waitingThrottle then
		if state.mode == "batch" then sendBatch() else sendQuery() end
	end
end)

ns:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", onBrowseResults)
ns:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", onBrowseResults)

ns:On("AUCTION_HOUSE_CLOSED", function()
	if state.running then Scanner:Stop("auction house closed") end
end)

ns:On("AUCTION_HOUSE_SHOW", function()
	-- The AH UI is load-on-demand; give it a moment to finish building.
	C_Timer.After(0.5, function()
		if ns.ScanPanel then ns.ScanPanel:Attach() end
		local s = ns.db.settings
		if not s.autoScan then return end
		local last = ns.Prices:GetLastScanTime()
		if last and (time() - last) < (s.autoScanCooldown or 300) then return end
		Scanner:Start(true)
	end)
end)

---------------------------------------------------------------------------
-- AH side panel: "Scan Fish Prices" button + auto-scan checkbox.
-- Docked to the right edge of AuctionHouseFrame so it never overlaps
-- Blizzard's own controls.
---------------------------------------------------------------------------

local ScanPanel = {}
ns.ScanPanel = ScanPanel

function ScanPanel:Create()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "FCE_ScanPanel", AuctionHouseFrame, "BackdropTemplate")
	f:SetSize(170, 92)
	f:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, -40)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOP", 8, -10)
	title:SetText("Fishing & Cooking")
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetTexture(ns.ICON)
	icon:SetPoint("RIGHT", title, "LEFT", -4, 0)

	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetSize(146, 22)
	button:SetPoint("TOP", title, "BOTTOM", 0, -6)
	button:SetText("Scan Fish Prices")
	button:SetScript("OnClick", function()
		if Scanner:IsRunning() then Scanner:Stop("stopped by user") else Scanner:Start(false) end
	end)
	f.button = button

	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -2, -4)
	check:SetScript("OnClick", function(cb)
		ns.db.settings.autoScan = cb:GetChecked() and true or false
	end)
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText("Auto-scan on open")
	f.check = check

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	status:SetPoint("BOTTOM", 0, 10)
	f.status = status

	self.frame = f
	self:Refresh()
	return f
end

function ScanPanel:Attach()
	if not AuctionHouseFrame then return end
	self:Create()
	self.frame:Show()
	self:Refresh()
end

function ScanPanel:Refresh()
	local f = self.frame
	if not f then return end
	f.check:SetChecked(ns.db.settings.autoScan)
	if Scanner:IsRunning() then
		local done, total = Scanner:GetProgress()
		f.button:SetText("Stop Scan")
		f.status:SetText(("Scanning %d / %d"):format(math.max(0, done), total))
	else
		f.button:SetText("Scan Fish Prices")
		local last = ns.Prices:GetLastScanTime()
		f.status:SetText(last and ("Last scan " .. ns.FormatAge(time() - last)) or "Never scanned")
	end
end

for _, msg in ipairs({ "SCAN_STARTED", "SCAN_PROGRESS", "SCAN_FINISHED", "SCAN_ABORTED", "SETTINGS_CHANGED" }) do
	ns:Listen(msg, function() ScanPanel:Refresh() end)
end
