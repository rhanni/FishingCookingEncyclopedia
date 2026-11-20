-- Fishing & Cooking Encyclopedia - Price storage
-- Prices are stored per realm key (Forever's AH is shared per ruleset;
-- GetRealmName() is used as the key until we confirm a better identifier).

local _, ns = ...

local Prices = {}
ns.Prices = Prices

local function realmKey()
	return (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "unknown"
end

local function realmTable()
	local key = realmKey()
	ns.db.prices[key] = ns.db.prices[key] or {}
	return ns.db.prices[key]
end

-- Record one scan result. quantity == 0 means "seen no listings".
--   minUnit:    cheapest unit price (copper)
--   marketUnit: quantity-weighted average of the cheapest slice of listings
function Prices:Record(itemID, minUnit, marketUnit, quantity)
	local tbl = realmTable()
	local entry = tbl[itemID] or { history = {} }
	tbl[itemID] = entry

	local now = time()
	entry.last = { t = now, min = minUnit, market = marketUnit, quantity = quantity or 0 }

	if minUnit then
		table.insert(entry.history, { t = now, min = minUnit, market = marketUnit })
		local maxLen = ns.db.settings.historyLength or 14
		while #entry.history > maxLen do table.remove(entry.history, 1) end
	end

	ns:Fire("PRICES_UPDATED", itemID)
end

-- Returns { min, market, quantity, age, avgMarket, listed } or nil.
-- If the latest scan found nothing, min and market fall back to the most
-- recent history point and `listed` is false.
function Prices:Get(itemID)
	local entry = realmTable()[itemID]
	if not entry or not entry.last then return nil end

	local last = entry.last
	local result = {
		quantity = last.quantity,
		age = time() - last.t,
		listed = last.quantity and last.quantity > 0,
		min = last.min,
		market = last.market,
	}

	local h = entry.history
	if #h > 0 then
		if not result.min then
			result.min = h[#h].min
			result.market = h[#h].market
		end
		local sum, n = 0, 0
		for i = 1, #h do
			if h[i].market then sum = sum + h[i].market; n = n + 1 end
		end
		if n > 0 then result.avgMarket = sum / n end
	end
	return result
end

-- Market value used by the UI: latest market, else historical average.
function Prices:GetValue(itemID)
	local p = self:Get(itemID)
	if not p then return nil end
	return p.market or p.avgMarket or p.min, p
end

function Prices:WipeRealm()
	ns.db.prices[realmKey()] = {}
	ns:Fire("PRICES_UPDATED")
end

function Prices:GetLastScanTime()
	return ns.db.lastScan[realmKey()]
end

function Prices:SetLastScanTime(t)
	ns.db.lastScan[realmKey()] = t
end
