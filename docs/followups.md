# Fishing & Cooking Encyclopedia: follow-ups, unconfirmed data, assumptions

Started 2026-11-19. Target: WoW: Forever 1.60.1 (TOC `16001`).

**How to use this file**
- Tick an item when it's resolved, and add a note saying what you found and where.
- Data fixes go in the research files under `research/`, never in the generated `Data/*.lua` files.
- After a data fix, rebuild with `powershell -File tools\build-data.ps1`.
- The code and research files carry no follow-up comments. Every open question is listed here: sections 1-6 for general checks, and the **Data map** at the end for the specific entries in each research file (look an entry up by its name or ID).
- `source = "classic-baseline"` in the research data means the entry comes from Classic and no Forever source has confirmed it yet.
- When an entry is confirmed, fix it in the research file, rebuild, and delete its row from the map.

---

## 1. In-game checks (code assumptions)

These were tested against a mock of the WoW API, never the real client.

**Profession window and tab**
- [ ] The side tab (`LargeSideTabButtonTemplate`) appears directly below Blizzard's profession side tabs. It must move correctly when tabs show or hide. (`UI.lua`, `reanchorTab`)
- [ ] Our panel covers the same area as `ProfessionsFrame.BookPage`, with no overlap and no gaps.
- [ ] Clicking any Blizzard tab, or the Overview tab, hides our panel. Reopening the window starts on Blizzard's page.
- [ ] `/fce` opens the profession window and selects our tab. This relies on `ToggleProfessionsBook()` being allowed from a slash command.

**Skill and recipe lookups**
- [ ] Fishing is skill line `356` and Cooking is `185` in Forever.
- [ ] `GetProfessions()` returns professions in the order prof1, prof2, First Aid, Fishing, Cooking.
- [ ] The skill modifier from `GetProfessionInfo` includes pole, lure and food bonuses. Zone colors use rank plus modifier.
- [ ] **Profession window tab position:** our tab is parented to the shared `ProfessionsFrameTabSideBar` frame (created if no other addon has) and pinned to its bottom, so it moves with the other tabs when AllTheThings opens its window. Check, with ATT and TrainerSpells installed: (1) our tab is visible at the bottom; (2) clicking the ATT tab moves our tab out with the rest; (3) clicking a profession tab afterwards leaves our tab beside the others; (4) TrainerSpells sits under ours. `/fce tab top` puts the tab under Blizzard's last tab, which is where ATT's own tab goes, so expect them to overlap in that mode. The bottom offset is `TAB_BOTTOM_INSET` in `UI.lua`. Also confirm opening and closing the window causes no FPS hitch.
- [ ] **Idea, try another day: automatic tab position.** With few professions, the bottom-pinned tab sits well apart from the Blizzard tabs. An automatic mode could place it directly under the last Blizzard tab when nothing else is there, and under AllTheThings' tab when ATT is present (ATT lists its tab in `ProfessionsFrameTabSideBar.Tabs`, so no frame scanning is needed). Re-place it on `RefreshRightTabs` and window open. Risk: an addon that neither registers its tab there nor adapts to ours (TrainerSpells adapts) could overlap us, so keep `bottom` as the fallback setting. Test with ATT only, TrainerSpells only, both, and neither.
- [ ] The **Known** badge works. It uses `IsPlayerSpell(spellID)`, so Forever's recipe spell IDs must match the research data.

**Rendering**
- [ ] Scroll frames: `ScrollFrameTemplate` exists and shows a scrollbar, and the mouse wheel scrolls.
- [ ] Item icons and names load. Names fall back to the research data until the client caches them.
- [ ] Collapse icons (`UI-PlusButton-Up` and `UI-MinusButton-Up`) render.
- [ ] **New icon** (`Media/TabIcon.tga`) shows on the side tab, the panel header, the AH panel, chat messages and the AddOns list.
  - **New texture files** only load after a full game restart, not a `/reload`.
  - **Double border on the side tab:** if Blizzard's frame clashes with the icon's own bevel, crop the bevel off with `SetTexCoord(0.06, 0.94, 0.06, 0.94)`.
- [ ] Row bands sit behind the text and don't block clicks or tooltips.
- [ ] **Benefits filter (Cooking page).**
  - It uses Blizzard's `WowStyle1FilterDropdownTemplate` menu if Forever has it, and falls back to an addon-made checklist popup if not. Check which one you get.
  - The menu should stay open while you tick boxes.
  - The button label should update ("Benefits (2)").
- [ ] **"Unknown recipes only"** depends on `IsPlayerSpell(spellID)` knowing your recipes. If it hides recipes you don't know, the recipe spell IDs in the data are wrong for Forever.
- [ ] **Benefit categories** are read from each recipe's effect text in `cooking_raw.lua`. If an in-game tooltip shows a different buff, fix the effect text.

**Auction house**
- [ ] `C_AuctionHouse` exists in Forever. Confirm with `/dump C_AuctionHouse.SendSearchQuery`.
- [ ] Fish searches fire `COMMODITY_SEARCH_RESULTS_UPDATED`. Non-stackables fire `ITEM_SEARCH_RESULTS_UPDATED`.
- [ ] The throttle uses `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, and a full scan of 57 items finishes without stalling.
- [ ] **Quick scan.** The default mode uses one `C_AuctionHouse.SearchForItemKeys` request.
  - Check that it completes in a few seconds.
  - Check that the Blizzard browse list shows our items during the scan; that side effect is expected.
  - If Forever lacks `SearchForItemKeys`, the scanner falls back to the detailed mode on its own.
- [ ] **Passive capture.** Prices update when you search for a tracked fish yourself. This relies on the `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` event.
- [ ] **Detailed scan setting.** The per-item timeout is now 2.5 s, down from 5 s. Is that still long enough?
- [ ] (old) The 5-second timeout per item is long enough. With no listings, the item should record "none listed" rather than hang.
- [ ] The AH side panel docks to the right edge of `AuctionHouseFrame` without overlapping Blizzard's UI.
- [ ] **Price storage key.** Prices are stored per `GetNormalizedRealmName()`, but Forever's AH is shared per ruleset and region. Check whether characters on the same ruleset see the same prices. If they don't, switch the key. (`Prices.lua`)

**Test tooling**
- [ ] The offline checker uses Fengari, which is Lua 5.3; WoW runs Lua 5.1. Watch in-game for errors the checker can't catch.

## 2. Design assumptions and open decisions

- [ ] **Cook / Sell verdict** compares the cooked price to the raw price only. It ignores vendor spice and water costs. Should it subtract them?
- [ ] **Market price** is the average unit price of the cheapest 25% of listed units. The lowest buyout and 14 scans of history are also kept. Is that the right "market" number?
- [ ] **Recipe scrolls** are not scanned by default (a setting in Prices & Scan).
- [ ] **Auto-scan** runs at most once every 5 minutes.
- [ ] **Excluded from scanning:** trophy fish, quest fish, chests, bloated fish (BoP in Forever) and alchemy-only fish. Should alchemy fish be scanned?
- [ ] **Raw Spinefin Halibut** (8959) is treated as a fish for scanning. In Forever it's sold by fishing suppliers, not fished.
- [ ] **Subzones** with their own tier (Jaguero Isle, Bay of Storms, Jademir Lake) are listed as separate zones named "Parent: Subzone".
- [ ] **Default zone** is the first zone, alphabetically, in the hardest tier your skill can catch in.
- [ ] **Row striping** uses Option A (`rowStyle = "A"`). Options B and C still exist in `UI_Widgets.lua`.
- [ ] **Fish with no listed use:** Darkshore Grouper, Lightning Eel, Oil Covered Fish, Sickly Looking Fish. Do any have Forever uses, such as turn-ins or new recipes?

## 3. Fishing data (`fishing_raw.lua`)

### Mechanics
- [ ] Getaways: does Forever still have a range where some fish get away (from the zone's catch skill to that +95)? The Forever wiki says every catch succeeds once you meet the requirement. Warcraft Tavern and wow.gg still describe getaways.
- [ ] The exact catch formula (assumed: catch chance % = skill − zone level + 5).
- [ ] Time-of-day fish (Nightfin 18:00–12:00, Sunscale 06:00–24:00) and seasonal fish (Winter Squid Sep 23–Mar 19, Summer Bass Mar 20–Sep 22). Do these rules carry over to Forever?
- [ ] Big-mouth Clam: none caught 00:00–03:00?

### New Forever zones (skill tiers not published)
- [ ] **Riverglades:** placed at 130/225, but that's a guess. Its catches (Redgill, Nightfin, Sunscale) look like 205-tier fish. Also check its pools, the giant guarded wreckage and its "Mythicalbound" trunk.
- [ ] **City of Dalaran:** tier unknown, possibly the 1/75 tier. Catches: Mud Snapper, Catfish, Trout. Also the "Fountain Coins" collection.
- [ ] **Zephras Isle:** tier unknown, probably 1/25. Fish list unknown (Windsong Lake).
- [ ] **Mount Hyjal:** tier unknown (205 or 330?). The fish list comes from a single commercial site.
- [ ] **Shen'dralas:** no fishing data at all.

### Classic zones with weak fish lists
- [ ] Fish lists taken from a retail-era wiki: Deadmines, Scarlet Monastery, Maraudon, Scholomance, Stratholme.
- [ ] Wailing Caverns: Deviate Fish pools inside the dungeon?
- [ ] Blackfathom Deeps: fish list incomplete.
- [ ] Sunken Temple: fish list unknown.
- [ ] Zul'Gurub: open-water fish unknown. Is ZG even released in Forever?
- [ ] Durotar: Catfish (only one source lists it).
- [ ] Thunder Bluff: Catfish (taken from the general capital-city list).
- [ ] Ironforge: fish list taken from the general capital-city list.
- [ ] The Barrens: Iron Bound Trunk and Black Label rum (Ratchet or south coast?).
- [ ] Ashenvale: Mithril Head Trout (only one source lists it).
- [ ] Felwood: Whitescale Salmon (only one source lists it).
- [ ] Moonglade: Oily Blackmouth (only one source lists it).
- [ ] Tanaris: freshwater Brilliant Smallfish?
- [ ] Silithus: Nightfin and Redgill (retail-era wiki only).
- [ ] Burning Steppes: fishable at all? Whitescale and Lightning Eel are listed.
- [ ] STV, Jaguero Isle: Rockscale Cod and Yellowtail are assumed.
- [ ] Swamp of Sorrows: pools (none documented).
- [ ] The Hinterlands: pools (none documented).
- [ ] Redridge: is Spotted Sunfish actually a fishing catch? Can Whimsyfin be caught in open water?
- [ ] Dustwallow: Lord Angler and the Ravaged Fishing Pole.
- [ ] Not fishable, or no data: Blasted Lands, Dire Maul (the retail wiki says 425), and the battlegrounds.

### Pools
- [ ] The Floating Wreckage variant with object ID 180901: are its yields right?
- [ ] Stonescale Eel Swarm on the Riverglades coast.
- [ ] School of Deviate Fish inside Wailing Caverns.
- [ ] Patch of Elemental Water outside Azshara (Feralas, STV, Tanaris?).
- [ ] School of Tastyfish: exact source of the Extravaganza rare fish.
- [ ] School of Whimsyfin: confirm the pool name, the skill needed (~150?) and the locations.
- [ ] Blueprint: Fishing Rack (273141): which pools can it be fished from?

### Items and Forever features
- [ ] The 4 unnamed Forever bloated fish (Forever has 10 kinds, we know 6 IDs).
- [ ] Trophy fish: which weight goes with which item ID (written from memory).
- [ ] Trophy fish sell for 1 silver per pound?
- [ ] Fishing Hut rare-fish list (not published).
- [ ] Extravaganza rare fish expire after 4 hours. Also check the reward and winner details.
- [ ] Ravaged Fishing Pole (285094) source, the "Secret" Bait lure (+25), Wide-Brimmed Fishing Hat, Shiny Silver Coin.
- [ ] Where Raw Plated Armorfish (13890) is fished in Forever.

## 4. Cooking data (`cooking_raw.lua`)

- [ ] **Spinefin Halibut** (Fishing +18 food): how is it learned? Sources disagree (trainer, Desolace vendors, or reported missing).
- [ ] **Specklefin Feast and Grand Lobster Banquet:** obtainable in Forever at all? They're listed with no source and may be leftovers from Season of Discovery.
- [ ] **Jabbey** (Undermine Clam Chowder recipe): limited or unlimited stock?
- [ ] **New vendors missing coordinates or faction:** Derek Odds (Alterac), Paige (Alterac), Qujo (Hinterlands), Miranda Turner (Riverglades, faction).
- [ ] **Carrie Hearthfire** (Eastern Plaguelands): she's left out of the data. Does she sell the Sagefish recipes in Forever?
- [ ] **Clam meat sources in Forever:** Zesty Clam Meat, Clam Meat, Tangy Clam Meat, and whether Giant Clam Meat can be fished.
- [ ] **Seasonal Fish Steaks** (273295) source, needed for the Fishing Hut.
- [ ] **Trainer costs:** Boiled Clams 1s and Goblin Deviled Clams 3s (one Forever site only).
- [ ] **Plated Armorfish recipe chest** (Deadwind Pass 52.5, 34.6): confirm the location.
- [x] **New cooking uses:** Plated Armorfish food (286152) and Clam Linguine (250081) both exist in Forever. *Resolved 2026-11-19 via Wowhead Forever tooltips.*
- [x] **Food buffs:** all 33 recipe effects were checked against Wowhead Forever tooltips (`effectSource = "forever"`). Research notes moved out of the effect text into `effectNote`, which fixed the false Stamina and Spirit on Boiled Clams. *Resolved 2026-11-19.*

## 5. Training data (`training_raw.lua`)

- [ ] **Journeyman Cooking:** level requirement (none, or level 10 as in Classic?).
- [ ] **Cooking trainer costs:** assumed to be in silver.
- [ ] **Hunter Moore** (Hillsbrad fishing trainer): Alliance only, or both factions?
- [ ] **"Bottles and Baubles":** quest ID, level and objectives.
- [ ] **"Fishin' Time":** quest ID, level, objectives and reward. The only walkthrough doesn't say which game version it covers.
- [ ] **Camping 101 quest IDs** for the Lee Brown, Tomas and William Pickman versions.
- [ ] **Hnaz Blunderflame and Ortak Lomgok** (Hyjal): confirm they train cooking. Their NPC titles aren't "cook".
- [ ] **Missing trainers?** No fishing trainer found in Riverglades' Horde town, Dalaran, Hyjal or Shen'dralas. No cooking trainer found in Powderfuse Port or Shen'dralas.
- [ ] **Data shape note:** ranks use `note` and quests may use `givers`/`enders`. `UI_Training.lua` handles both.

## 6. Publishing (CurseForge)

- [ ] Find the exact Forever game version or flavor in CurseForge's upload dropdown. Forever addons already exist on CurseForge, but I found no official docs naming the flavor.
- [ ] Choose a license, and write the project description and screenshots.
- [x] Exclude the dev folders from the release zip: `tools/`, `research/` and `docs/`. Done by `tools\package.ps1`, which builds the zip from a whitelist. To clean by hand, delete those three top-level folders.
- [ ] Optional: set up automatic packaging (`.pkgmeta` plus the BigWigs packager GitHub Action, with `## X-Curse-Project-ID` in the TOC).
- [ ] Also publish on Wago Addons?

## 7. Data map: unconfirmed entries by research file

These are the notes that used to sit in the research files as `-- UNVERIFIED` comments. Each row names the entry to look up in the file. Where a note was shown in-game, the unconfirmed wording was removed from it and only its confirmed text is displayed.

### `research/fishing_raw.lua`

| Entry | What's unconfirmed | Note it applies to |
|---|---|---|
| Catch-chance formula (notes) | Catch chance = skill - Z + 5 comes from emulator cores; not confirmed as Blizzard's exact formula |  |
| Big-mouth Clam | Whole note unconfirmed | None seen 00:00-03:00 at Feathermoon. |
| Time-of-day / seasonal fish | Neither the time-of-day nor the seasonal rules are confirmed for Forever. (classic baseline only) |  |
| Spotted Sunfish | Whole note unconfirmed | Redridge, quest 'Selling Fish'. May be a murloc drop rather than fished. |
| Brownell's Blue Striped Racer | Whole note unconfirmed | Extravaganza rare fish -> Nat Pagle's Extreme Anglin' Boots (19969). Forever: expires after 4h |
| Bloated fish | The other 4 Forever bloated fish were not named in any source found. |  |
| Blueprint: Fishing Rack | Unconfirmed: which pools | Gelihast (Blackfathom Deeps) drop; Warcraft Tavern says it can also be fished from pools. |
| Trophy fish (6292-6295 and similar) | The weight-to-ID mapping is from memory, ordered to match the tavern ID lists. |  |
| Floating Wreckage (180901) | Whole note unconfirmed | Exists in the Classic DB as 'Floating Wreckage' (later renamed Bloodsail Wreckage, STV south coast). Yields assumed. |
| Stonescale Eel Swarm | Whole note unconfirmed | Coastal: Azshara, Feralas, STV (south of Grom'gol only), Tanaris. About 3.2 eels per pool. Forever: FishFry also reports them on the Riverglades co... |
| School of Deviate Fish | Unconfirmed: for WC | Barrens oases (Lushwater, Stagnant, Forgotten Pools); also reported in Wailing Caverns waters. |
| Patch of Elemental Water | Unconfirmed: outside Azshara | Azshara, Bay of Storms (330-tier water). About 2.9 catches/pool: Essence avg 1.0, Elemental Water avg 2.2, Globe avg 1.3. Never spawns as a wreckag... |
| School of Tastyfish | Unconfirmed: exact source | STV coast, Fishing Extravaganza only (Sunday 14:00-16:00). Rare fish 19803/19805/19806 can also come from event water. |
| School of Whimsyfin | Whole note unconfirmed | Forever-new. Redridge Mountains: south river below Lake Everstill and the east lake near Stonewatch Keep. About 2 up at a time. Pool name comes fro... |
| Durotar | Unconfirmed: catfish | Mostly Mackerel (about 60%) on the coast around Sen'jin. Catfish is listed only by Warcraft Tavern. |
| Ironforge | Classic data only, no Forever source | Forlorn Cavern / Mystic Ward pools. Fish list assumed from the capital aggregate. |
| Thunder Bluff | Unconfirmed: catfish | Catfish here only from the capital aggregate. Outputlag reports bloated fish in TB in Forever. |
| The Barrens | Whole note unconfirmed | Ratchet coast and the oases (Deviate Fish only from the schools). Oil Covered Fish at Sludge Fen. Tavern also lists Iron Bound Trunk/Black Label ru... |
| The Deadmines | Classic data only, no Forever source | Fish list from the retail-era wiki. |
| Wailing Caverns | Classic data only, no Forever source | Deviate Fish reported in WC waters. |
| Blackfathom Deeps | Classic data only, no Forever source | Fish list incomplete. Forever: Gelihast drops Blueprint: Fishing Rack (273141). |
| Ashenvale | Unconfirmed: trout | Classic shares: Catfish 39%, Albacore 19%, Sagefish 6%. Mithril Head Trout here is listed only by Tavern. |
| Redridge Mountains | Unconfirmed: as a fishing catch | Wiki (Forever redirect): min 55, 100% at 150. Forever-new Whimsyfin (pools; open water unconfirmed). Classic shares: Catfish 64%, Mud Snapper 35%.... |
| Dustwallow Marsh | Whole note unconfirmed | Nat Pagle (58.6, 60.0) gives the Artisan quest. Classic shares: Rockscale 27%, Trout 24%, Firefin 11%. Forever: Lord Angler (Ravaged Fishing Pole)... |
| Jaguero Isle | Whole note unconfirmed | Glossy Mightfish, Summer Bass / Winter Squid and Big-mouth Clams only here in STV. Rockscale/Yellowtail assumed. |
| Swamp of Sorrows | Unconfirmed: pools | Misty Reed Strand (Misty Reed Mahi Mahi, ~90,72). Classic shares: Rockscale 49%, Yellowtail 18%, Firefin 10%. No classic pools documented (zockify... |
| Scarlet Monastery | Classic data only, no Forever source | Fish list from the retail-era wiki (Cathedral). |
| Felwood | Unconfirmed: whitescale | Classic shares: Redgill 51%, Nightfin 19%, Trout 10%. Whitescale Salmon is listed only by Tavern. |
| The Hinterlands | Unconfirmed: pools | Revantusk coast. Katoom the Angler: 'Snapjaws, Mon!' -> Nat Pagle's Extreme Angler FC-5000 (+25, Horde). No classic pools documented. |
| Moonglade | Whole note unconfirmed | Lake Elune'ara. Classic shares: Redgill 50%, Nightfin 22%, Oily Blackmouth 10%. The Blackmouth comes from mmonster data only. |
| Tanaris | Whole note unconfirmed | Steamwheedle Port coast. Classic shares: Yellowtail 27%, Firefin 14%, Eel 14%. Tavern also lists Raw Brilliant Smallfish as 'freshwater' Tanaris. F... |
| Maraudon | Classic data only, no Forever source | Fish list from the retail-era wiki. |
| Sunken Temple | Whole note unconfirmed | Temple of Atal'Hakkar. Fish list unknown. Forever: Jammal'an the Prophet drops Blueprint: Fishing Hut (273119). |
| Silithus | Whole note unconfirmed | Classic shares: Whitescale 37%, Sunscale 22%, Armorfish 11%. Nightfin/Redgill are from the retail-era wiki only. |
| Burning Steppes | Classic data only, no Forever source | Tavern lists Whitescale + Lightning Eel. Little non-lava water; lava fishing was not possible in Classic. |
| Scholomance | Classic data only, no Forever source | Fish list from the retail-era wiki. |
| Stratholme | Classic data only, no Forever source | Fish list from the retail-era wiki. |
| Zul'Gurub | Whole note unconfirmed | Muddy Churning Waters -> Zulian Mudskunk (Gahz'ranka summon). Open-water fish list unknown (Sharptooth/Striped Lurker are Cataclysm). ZG release st... |
| Riverglades | Skill tier (baseLevel 130, skill 130, no-getaway 225) |  |
| Riverglades | Unconfirmed: trunk name | EZG calls the guarded wreckage's trunk 'Mythicalbound'. |
| Riverglades | Whole note unconfirmed | New zone (levels ~35-45), SE Khaz Modan between Redridge, Badlands, Swamp of Sorrows, Burning Steppes; Powderfuse Port (goblin) with a boat to Tana... |
| City of Dalaran | Skill tier (skill, baseLevel and noGetaway are not known yet) |  |
| City of Dalaran | Whole note unconfirmed | Non-instanced Dalaran (Alterac Mountains), unlocked after the City of Dalaran dungeon chain. FishFry addon: Eventide Fountain (14,71) Mud Snapper/C... |
| Zephras Isle | Skill tier (skill, baseLevel and noGetaway are not known yet) |  |
| Zephras Isle | Whole note unconfirmed | Skyborne starting zone (1-12) on the Elemental Plane of Air. Fishing trainers Baelann Swiftcurrent (Valanaar 63.2,75.7) and Fenn Fairweather (Shen'... |
| Mount Hyjal | Skill tier (skill, baseLevel and noGetaway are not known yet) |  |
| Mount Hyjal | Whole note unconfirmed | Level 60 zone reached through Darkwhisper Gorge (Winterspring). mmoexp (a commercial site) names Sunscale Salmon, Redgill and Lightning Eel. Skill... |
| Shen'dralas | Skill tier (skill, baseLevel and noGetaway are not known yet) |  |
| Shen'dralas | Whole note unconfirmed | New zone between Desolace, Feralas and Mulgore; level unknown (estimates 30-50). No fishing data found. |
| Blasted Lands | Whole note unconfirmed | Not in any Classic tier table (zockify mentions pools here, which is likely wrong). |
| Dire Maul | Whole note unconfirmed | Has water but is not in any Classic tier table. The retail-era wiki lists Nightfin/Sunscale/Whitescale at 425. |
| Battlegrounds (AV/WSG/AB) | Whole note unconfirmed | Not covered by any source. |
| Fishing Hut note | Whole note unconfirmed | Fishing Hut (Fishing 300): 5 Simple Wood, 2 Bolt of Runecloth, 1 Seasonal Fish Steaks (273295); 1 hour of lures + Rare fish. Blueprint 273119 from... |
| Summary notes (end of file) | Whole note unconfirmed | Bloated fish: 10 kinds are now Uncommon + Bind on Pickup and tied to the Fishing Rack (classic has 6 known IDs: 6643, 6645, 6647, 8366, 13881, 1389... |
| Summary notes (end of file) | Whole note unconfirmed | New cooking uses: Plated Armorfish (13890) -> Plated Armorfish food (286152, Cooking 225); Zesty Clam Meat -> Clam Linguine (250081, Cooking 275). |
| Summary notes (end of file) | Whole note unconfirmed | New poles/lures: Ravaged Fishing Pole (285094, +15; source given as Lord Angler in Dustwallow or a world drop; conflicting). '\"Secret\" Bait' lure... |
| Summary notes (end of file) | Unconfirmed: details | Stranglethorn Fishing Extravaganza (Sun 14:00-16:00 region time): the first 50 players per ruleset win (raised further in the Nov 13 hotfix) instea... |
| Summary notes (end of file) | Whole note unconfirmed | New fishable zones: Riverglades (4 fishing spots, coastal pools, a giant guarded wreckage), City of Dalaran (Eventide Fountain, Violet Hold, Sewers... |
| Summary notes (end of file) | Whole note unconfirmed | Trophy fish reportedly sell for 1 silver per pound. |
| Summary notes (end of file) | Classic data only, no Forever source | No Forever source confirmed the Classic time-of-day (Nightfin/Sunscale) or seasonal (Winter Squid/Summer Bass) rules; assume they carry over. |

### `research/cooking_raw.lua`

| Entry | What's unconfirmed | Note it applies to |
|---|---|---|
| Miranda Turner (vendor 272646, Riverglades) | Faction | Only the Alliance reaction ("Neutral") is listed |
| Derek Odds (252083) and Paige (267000), Alterac Mountains | Coordinates and faction |  |
| Qujo (270780, The Hinterlands) | Coordinates |  |
| Spinefin Halibut | Where the recipe is learned | No recipe item; the spell is flagged "Recipe Hidden Until Known". timesaver.gg says a trainer (fee not listed), wow.gg says Janet Hommers / Kireena (Desolace), and a Blizzard forum thread reports it missing in-game |
| Plated Armorfish | Where Raw Plated Armorfish (13890) is fished | The recipe is looted from chest object 694054 in Deadwind Pass; the fishing location itself is unconfirmed |
| Specklefin Feast (recipe 238649), Grand Lobster Banquet (238650) | Whether obtainable in Forever | In the Forever spell list with no recipe source; Classic data only |
| Giant Clam Scorcho | Giant Clam Meat fishing source |  |
| Undermine Clam Chowder (recipe 16767) | Jabbey's stock | Wowhead Forever lists stock 1 (limited), warcraftdb shows unlimited. Grizzek (Riverglades) is new and unlimited |
| Fishing Hut | Where Seasonal Fish Steaks (273295) come from |  |
| Clam meats: Zesty (7974), Clam Meat (5503), Tangy (5504), Giant (4655) | Source notes | Classic data only; for Zesty, whether it is also mob-dropped and unchanged in Forever |
| Carrie Hearthfire (NPC 240604, Eastern Plaguelands) | Whether she sells Sagefish recipes | Wowhead Forever lists her; warcraftdb Forever does not, so she is excluded |

### `research/training_raw.lua`

| Entry | What's unconfirmed | Note it applies to |
|---|---|---|
| Hunter Moore (255877, Hillsbrad Foothills) | Faction | warcrafttavern lists Alliance only, timesaver says both |
| Quest: Bottles and Baubles (Lee Brown) | Level (7) and objectives | The level is from earlier research notes; objectives are not documented |
| Quest: Fishin' Time (Gilbert Gray) | Level (12), objectives and reward | The level is from earlier research notes; objectives come from a walkthrough that does not name the game version; reward not documented. The NPC and quest are confirmed Forever-only (warcraft.wiki.gg) |
| Cooking rank: Journeyman | Required level | wow-professions and warcrafttavern list none; Classic required level 10 |
| Trainer coverage | Missing trainers | No fishing trainer found in Riverglades' Horde town, City of Dalaran, Mount Hyjal or Shen'dralas, and no cooking trainer in Powderfuse Port or Shen'dralas. Absence is not confirmed |
