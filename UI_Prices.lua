-- Fishing & Cooking Encyclopedia - "Prices & Scan" page
-- Scan settings and every tracked fish/dish with its latest AH price.

local _, ns = ...
local W = ns.Widgets

local page = {}

local OPTIONS = {
	{ key = "autoScan", label = "Auto-scan when the auction house opens",
	  hint = "At most once every 5 minutes. The Scan Fish Prices button on the AH always works." },
	{ key = "scanCooked", label = "Scan cooked dishes made from fish" },
	{ key = "scanRecipeItems", label = "Also scan recipe scrolls" },
	{ key = "passiveCapture", label = "Record prices while I browse the auction house",
	  hint = "Whenever tracked fish or dishes appear in your own AH searches, their prices are saved. No extra requests." },
	{ key = "detailedScan", label = "Detailed scan (slower, better market price)",
	  hint = "Searches each item separately and averages the cheapest 25% of listed units. The default quick scan asks for every item in one request and records the lowest price." },
}

local function makeCheck(parent, opt, anchor)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	if anchor then check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2) else check:SetPoint("TOPLEFT", 4, -2) end
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText(opt.label)
	check:SetScript("OnClick", function(cb)
		ns.db.settings[opt.key] = cb:GetChecked() and true or false
		ns:Fire("SETTINGS_CHANGED", opt.key)
	end)
	if opt.hint then
		check:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(opt.label, 1, 1, 1)
			GameTooltip:AddLine(opt.hint, 0.8, 0.8, 0.8, true)
			GameTooltip:Show()
		end)
		check:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	check.key = opt.key
	return check
end

function page:Build(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()

	self.checks = {}
	local prev
	for _, opt in ipairs(OPTIONS) do
		prev = makeCheck(f, opt, prev)
		self.checks[#self.checks + 1] = prev
	end

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, -8)
	status:SetPoint("RIGHT", f, "RIGHT", -24, 0)
	status:SetJustifyH("LEFT")
	self.status = status

	local scroll = W.CreateScroll(f)
	scroll:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -4, -10)
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	scroll.onResize = function() if f:IsShown() then self:Refresh() end end
	self.flow = W.NewFlow(scroll)
	return f
end

function page:Refresh()
	for _, check in ipairs(self.checks) do
		check:SetChecked(ns.db.settings[check.key] and true or false)
	end

	local ids = ns.Data:GetScanItemIDs()
	local priced = 0
	for _, id in ipairs(ids) do
		if ns.Prices:GetValue(id) then priced = priced + 1 end
	end
	local last = ns.Prices:GetLastScanTime()
	local scanLine
	if ns.Scanner:IsRunning() then
		local done, total = ns.Scanner:GetProgress()
		scanLine = ("|cff20ff20Scanning %d / %d...|r"):format(math.max(0, done), total)
	else
		scanLine = "Last scan: " .. (last and ns.FormatAge(time() - last) or "never")
	end
	self.status:SetText(("%s   -   %d tracked items, %d with prices.\nOpen the auction house and click |cffffd100Scan Fish Prices|r, or type |cffffd100/fce scan|r."):format(scanLine, #ids, priced))

	local D = ns.Data
	table.sort(ids, function(a, b) return D:GetItemName(a) < D:GetItemName(b) end)

	local flow = self.flow
	flow:Reset()
	flow:Row({ left = "|cffffd100Item|r", right = "|cffffd100Market price  -  scanned|r", font = "GameFontNormal" })
	for _, id in ipairs(ids) do
		local value, p = ns.Prices:GetValue(id)
		local item = D.items[id] or {}
		local name = D:GetItemName(id)
		if item.kind == "dish" then name = name .. " |cff999999(dish)|r" end
		local right
		if value then
			local qty = p.listed and "" or "  |cffff8040none listed|r"
			right = ns.FormatMoney(value) .. qty .. "  |cff808080" .. ns.FormatAge(p.age) .. "|r"
		else
			right = "|cff808080not scanned|r"
		end
		flow:Row({ icon = W.ItemIcon(id), left = name, right = right, tooltip = W.ItemTooltip(id) })
	end
	flow:Finish()
end

ns.UI:RegisterPage("prices", page)
