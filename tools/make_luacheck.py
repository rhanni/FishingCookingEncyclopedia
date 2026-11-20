"""Builds tools/luacheck.html: compiles every addon file listed in the .toc with
Fengari (Lua in the browser), then runs the addon against tools/wowmock.lua and
drives the UI and scanner. Serve the tools folder and open luacheck.html.

Usage: python -I tools/make_luacheck.py <addon root> <output html>
Note: Fengari is Lua 5.3; WoW is Lua 5.1. Syntax is nearly identical, but a
string.format("%d", 1.5) error here would be silently truncated in WoW.
"""
import json, pathlib, sys

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])

toc = root / "FishingCookingEncyclopedia.toc"
files = [l.strip().replace("\\", "/") for l in toc.read_text(encoding="utf-8").splitlines()
         if l.strip() and not l.lstrip().startswith("#")]
extra = ["tools/wowmock.lua"]

driver = r'''
local out = {}
local function say(s) out[#out + 1] = s end
local chunks, allOk = {}, true
for _, name in ipairs(ALL) do
  local f, err = load(SRC[name], "@" .. name)
  if f then chunks[name] = f else allOk = false; say("SYNTAX ERROR " .. tostring(err)) end
end
say(allOk and ("All " .. #ALL .. " files compile.") or "Compile errors above.")
if not allOk then return table.concat(out, "\n") end

local M = chunks["tools/wowmock.lua"]()
local ns = {}
for _, name in ipairs(TOC) do
  local ok, e = pcall(chunks[name], "FishingCookingEncyclopedia", ns)
  if not ok then say("LOAD ERROR " .. name .. ": " .. tostring(e)) end
end

local function step(label, fn, ...)
  local ok, e = pcall(fn, ...)
  if not ok then say("ERROR in " .. label .. ": " .. tostring(e)) end
  M.flush()
  return ok
end

step("ADDON_LOADED", M.fire, "ADDON_LOADED", "FishingCookingEncyclopedia")
local D = ns.Data
say(("Data: %d zones, %d recipes, %d scan items"):format(#D.zones, #D.recipes, #D:GetScanItemIDs()))

step("open tab (/fce)", function() SlashCmdList.FISHINGCOOKINGENCYCLOPEDIA("") end)
say("Panel shown after /fce: " .. tostring(ns.UI.panel and ns.UI.panel:IsShown()) .. ", page: " .. tostring(ns.UI.currentPage))

step("side tab stacking", function()
  local PF = ProfessionsFrame
  local last = PF.rightProfessionTabs[#PF.rightProfessionTabs]
  M.setRect(last, 800, 500, 40, 40)
  local function y() M.flush(); local _, rel, _, _, oy = ns.UI.tab:GetPoint(1); return oy, rel == last end
  ns.UI.ReanchorTab()
  local alone, relOk = y()
  -- Another addon's tab parented to UIParent, 14px below Blizzard's (where ours used to go).
  local other = CreateFrame("Button", nil, UIParent)
  M.setRect(other, 801, 446, 40, 40)
  -- Noise: anchored to our tab (moves with us), too wide, wrong column,
  -- and protected frames (geometry errors, or "secret" values).
  local follower = CreateFrame("Button")
  follower:SetPoint("TOP", ns.UI.tab, "BOTTOM", 0, -4)
  M.setRect(follower, 800, 300, 40, 40)
  local wide = CreateFrame("Frame"); M.setRect(wide, 800, 200, 300, 40)
  local offcol = CreateFrame("Frame"); M.setRect(offcol, 600, 200, 40, 40)
  local hostile = CreateFrame("Frame"); hostile.GetRect = function() error("blocked: protected frame") end
  local secretRect = CreateFrame("Frame"); M.setRect(secretRect, 800, 100, 40, 40)
  issecretvalue = function(v) return v == 100 end

  ns.UI.ReanchorTab()
  local beforeDeep = y() -- not a profession-window child, so cheap checks can't see it yet

  -- Spread-out full search (as on first window open): drive OnUpdate frames.
  local steps = 0
  ns.UI:FindAddonTabs(false)
  for _ = 1, 10000 do
    local ran = false
    for _, o in ipairs(M.all) do
      local fn = o.__scripts.OnUpdate
      if fn then fn(o, 0.016); ran = true end
    end
    if not ran then break end
    steps = steps + 1
  end
  local afterDeep = y()
  issecretvalue = nil
  say(("Side tab: alone=%s (on Blizzard tab: %s), UIParent tab before full search=%s, after=%s (search took %d frames for %d frames total)"):format(
    tostring(alone), tostring(relOk), tostring(beforeDeep), tostring(afterDeep), steps, #M.all))

  -- A tab parented to the profession window is found by the cheap check.
  local child = CreateFrame("Button", nil, ProfessionsFrame); M.setRect(child, 800, 400, 40, 40)
  M.rectCalls = 0
  ns.UI.ReanchorTab()
  local withChild, cost = y(), M.rectCalls
  -- Hiding a known tab re-stacks via its OnHide hook, with no explicit call.
  child:Hide(); M.flush()
  local afterHideHook = y()
  other:Hide(); M.flush()
  local allHidden = y()
  say(("Side tab: PF child tab=%s (cheap re-stack read %d frames), child hidden via hook=%s, all hidden=%s"):format(
    tostring(withChild), cost, tostring(afterHideHook), tostring(allHidden)))

  -- /fce tabs
  other:Show(); M.flush()
  local n0 = #M.printed
  SlashCmdList.FISHINGCOOKINGENCYCLOPEDIA("tabs")
  for i = n0 + 1, #M.printed do say("  /fce tabs: " .. M.printed[i]:gsub("^.-|r: ", "")) end
  other:Hide(); follower:Hide(); wide:Hide(); offcol:Hide(); hostile:Hide(); secretRect:Hide(); M.flush()
end)

local fishing, cooking, prices = ns.UI.pages.fishing, ns.UI.pages.cooking, ns.UI.pages.prices

local function renderAll(tag)
  local zoneErrors = 0
  for _, z in ipairs(D.zones) do
    if not step(tag .. " zone " .. z.name, fishing.Select, fishing, z.name) then zoneErrors = zoneErrors + 1 end
  end
  local recipeErrors = 0
  for _, r in ipairs(D.recipes) do
    if not step(tag .. " recipe " .. r.name, ns.UI.ShowRecipe, ns.UI, r.name) then recipeErrors = recipeErrors + 1 end
  end
  say(("%s: rendered %d zones (%d errors), focused %d recipes (%d errors)"):format(tag, #D.zones, zoneErrors, #D.recipes, recipeErrors))
end

step("fishing page", ns.UI.ShowPage, ns.UI, "fishing")
say("Default zone for Fishing 240+25: " .. tostring(fishing.selected))
renderAll("Before prices")

step("search 'salmon'", function()
  cooking.search:SetText("salmon")
  cooking.search.__scripts.OnTextChanged(cooking.search)
end)
local shown = 0
for _, r in ipairs(D.recipes) do if r.name:lower():find("salmon") then shown = shown + 1 end end
say("Search 'salmon' matches by name: " .. shown)
step("faction filter", function()
  M.click(cooking.check); cooking.check.__checked = true; M.click(cooking.check)
end)
step("expand vendors", function()
  for _, r in ipairs(D.recipes) do cooking.expanded[r.name] = true end
  cooking.search:SetText(""); cooking.search.__scripts.OnTextChanged(cooking.search)
end)
step("collapse tiers", function()
  ns.UI:ShowPage("fishing")
  for _, g in ipairs(D:GetZoneBrackets()) do ns.db.settings.collapsedTiers[g.label] = true end
  fishing:RenderZones()
  local rows = #fishing.zoneFlow.rows.used
  for k in pairs(ns.db.settings.collapsedTiers) do ns.db.settings.collapsedTiers[k] = nil end
  fishing:RenderZones()
  say(("Zone list rows: %d collapsed, %d expanded"):format(rows, #fishing.zoneFlow.rows.used))
end)
step("row styles", function()
  ns.UI:ShowPage("cooking")
  for _, s in ipairs({"A", "B", "C"}) do ns.db.settings.rowStyle = s; cooking:Refresh() end
  say("Cooking bands drawn (style C): " .. #cooking.flow.bands.used)
  ns.db.settings.rowStyle = "A"
end)
step("cooking filters", function()
  ns.UI:ShowPage("cooking")
  local function shown() local n = 0; for _, r in ipairs(D.recipes) do if cooking:PassesFilters(r) then n = n + 1 end end; return n end
  local types = D:GetBenefitTypes()
  local names = {}
  for _, b in ipairs(types) do names[#names + 1] = b.label .. "=" .. b.count end
  say("Benefit types: " .. table.concat(names, ", "))

  say("Benefits per recipe:")
  for _, r in ipairs(D.recipes) do
    local labels = {}
    for _, b in ipairs(types) do if D:GetRecipeBenefits(r)[b.key] then labels[#labels + 1] = b.label end end
    say(("  %-26s %s%s"):format(r.name, table.concat(labels, ", "), r.effectSource == "forever" and "" or "  [" .. tostring(r.effectSource) .. "]"))
  end

  -- Native menu path: build the menu and tick Attack Power + Spell Power.
  local menu = M.buildMenu(cooking.benefitDropdown)
  local ticked = {}
  for _, c in ipairs(menu.checks) do
    if c.text:find("^Attack Power") or c.text:find("^Spell Power") then c.setSelected(); ticked[#ticked + 1] = c.text end
  end
  local ap, sp, both, union = 0, 0, 0, 0
  for _, r in ipairs(D.recipes) do
    local s = D:GetRecipeBenefits(r)
    if s.ap then ap = ap + 1 end
    if s.spell then sp = sp + 1 end
    if s.ap and s.spell then both = both + 1 end
    if s.ap or s.spell then union = union + 1 end
  end
  say(("Ticked %s -> %d shown (expected union %d: AP %d + SP %d - both %d)"):format(table.concat(ticked, " + "), shown(), union, ap, sp, both))
  menu.buttons[1].fn()
  say("After clear: " .. shown() .. " shown")

  -- Unknown-only (mock knows only Brilliant Smallfish, spell 7751)
  M.click(cooking.unknownCheck); cooking.unknownCheck.__checked = true; M.click(cooking.unknownCheck)
  say("Unknown only: " .. shown() .. " of " .. #D.recipes)
  cooking.unknownCheck.__checked = false; M.click(cooking.unknownCheck)

  -- Fallback popup path
  local holder = CreateFrame("Frame")
  cooking:CreateBenefitPopup(holder)
  M.click(cooking.benefitPopup.checks[1])
  say(("Fallback popup: ticking '%s' -> %d shown"):format(cooking.benefitPopup.checks[1].key, shown()))
  cooking:ClearBenefits()
  cooking.benefitPopup = nil
end)
local training = ns.UI.pages.training
step("training page", ns.UI.ShowPage, ns.UI, "training")
say("Training data loaded: fishing=" .. tostring(D.training and D.training.fishing ~= nil) .. " cooking=" .. tostring(D.training and D.training.cooking ~= nil))
for _, key in ipairs({"fishing", "cooking"}) do
  step("training " .. key, function()
    M.click(training.profButtons[key])
    training.showOther[key] = true
    training:Refresh()
    ns.db.settings.hideOtherFaction = true; training:Refresh()
    ns.db.settings.hideOtherFaction = false; training:Refresh()
    local t = D.training and D.training[key]
    say(("Training %s: %d ranks, %d trainers, %d quests, %d rows drawn"):format(key,
      t and #(t.ranks or {}) or 0, t and #(t.trainers or {}) or 0, t and #(t.quests or {}) or 0, #training.flow.rows.used))
  end)
end
step("prices page", ns.UI.ShowPage, ns.UI, "prices")
step("toggle auto-scan", function() M.click(prices.checks[1]) end)

-- Simulated AH scan
AuctionHouseFrame:Show()
step("AUCTION_HOUSE_SHOW", M.fire, "AUCTION_HOUSE_SHOW")
say("AH panel created: " .. tostring(ns.ScanPanel.frame ~= nil) .. ", auto-scan running: " .. tostring(ns.Scanner:IsRunning()))
local function runScan(label)
  ns.Prices:WipeRealm()
  if ns.Scanner:IsRunning() then ns.Scanner:Stop("restart") end
  -- No step() here: its timer flush would fire timeouts before results arrive.
  local ok, e = pcall(ns.Scanner.Start, ns.Scanner, false)
  if not ok then say("ERROR in scan start: " .. tostring(e)) end
  local rounds, requests = 0, 0
  while ns.Scanner:IsRunning() and rounds < 500 do
    rounds = rounds + 1
    -- Answer pending requests before running timers, as the real AH would.
    if M.lastKeys then
      M.browseKeys = M.lastKeys; M.lastKeys = nil; requests = requests + 1
      M.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    end
    if M.lastQuery then
      local q = M.lastQuery; M.lastQuery = nil; requests = requests + 1
      M.fire("COMMODITY_SEARCH_RESULTS_UPDATED", q)
    end
    M.flush(1)
  end
  M.flush()
  local priced, listed = 0, 0
  for _, id in ipairs(D:GetScanItemIDs()) do
    local v, p = ns.Prices:GetValue(id)
    if p then priced = priced + 1 end
    if p and p.listed then listed = listed + 1 end
  end
  say(("%s: finished=%s, %d AH requests, %d items recorded, %d listed"):format(label, tostring(not ns.Scanner:IsRunning()), requests, priced, listed))
end

ns.db.settings.detailedScan = false
runScan("Quick scan (batch)")
ns.db.settings.detailedScan = true
runScan("Detailed scan (per item)")
ns.db.settings.detailedScan = false

-- Passive capture: user browses; tracked items in the results get recorded.
ns.Prices:WipeRealm()
M.browseKeys = { { itemID = 13888 }, { itemID = 13889 }, { itemID = 2589 } } -- lobster, salmon, linen cloth
M.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
say(("Passive capture: lobster=%s salmon=%s linen(untracked)=%s"):format(
  tostring(ns.Prices:GetValue(13888)), tostring(ns.Prices:GetValue(13889)), tostring(ns.Prices:GetValue(2589))))
runScan("Quick scan again (for later checks)")
local sample = D:GetScanItemIDs()[1]
local p = ns.Prices:Get(sample)
say(("Sample item %d: min=%s market=%s qty=%s"):format(sample, tostring(p and p.min), tostring(p and p.market), tostring(p and p.quantity)))

renderAll("With prices")
step("prices page with data", ns.UI.ShowPage, ns.UI, "prices")
step("close AH", M.fire, "AUCTION_HOUSE_CLOSED")

say("Reported errors: " .. #M.errors)
for i = 1, math.min(#M.errors, 30) do say("  " .. M.errors[i]) end
say("Chat output:")
for i = 1, math.min(#M.printed, 12) do say("  " .. M.printed[i]) end
return table.concat(out, "\n")
'''

all_files = files + extra
scripts = []
for f in all_files:
    src = (root / f).read_text(encoding="utf-8")
    if "</script" in src.lower():
        raise SystemExit(f"{f} contains </script")
    scripts.append(f'<script type="text/plain" data-name="{f}">{src}</script>')

def lua_list(name, items):
    return f'lua.lua_newtable(L); {json.dumps(items)}.forEach((f, i) => {{ lua.lua_pushstring(L, to_luastring(f)); lua.lua_rawseti(L, -2, i + 1); }}); lua.lua_setglobal(L, to_luastring("{name}"));'

html = f'''<!doctype html><meta charset="utf-8"><title>FCE Lua check</title>
<pre id="out" style="white-space:pre-wrap;font:13px monospace">running...</pre>
{''.join(scripts)}
<script type="text/plain" id="driver">{driver}</script>
<script src="https://cdn.jsdelivr.net/npm/fengari-web@0.1.4/dist/fengari-web.js"></script>
<script>
const {{lua, lauxlib, lualib, to_luastring}} = fengari;
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
lua.lua_newtable(L);
document.querySelectorAll('script[data-name]').forEach(s => {{
  lua.lua_pushstring(L, to_luastring(s.textContent));
  lua.lua_setfield(L, -2, to_luastring(s.dataset.name));
}});
lua.lua_setglobal(L, to_luastring("SRC"));
{lua_list("TOC", files)}
{lua_list("ALL", all_files)}
const st = lauxlib.luaL_dostring(L, to_luastring(document.getElementById("driver").textContent));
document.getElementById("out").textContent = (st === 0 ? "" : "DRIVER FAILED: ") + lua.lua_tojsstring(L, -1);
</script>'''
out.write_text(html, encoding="utf-8")
print("wrote", out, "-", len(files), "addon files")
