-- FishingCookingEncyclopedia - raw TRAINING research data (how Fishing and Cooking ranks are learned)
-- Target: World of Warcraft: Forever (Classic+, patch 1.60.1, launched 2026-11-04).
--
-- Conventions:
--   source = "forever"          -> confirmed by a Forever-specific source (see below)
--   source = "classic-baseline" -> only Classic/vanilla sources; not confirmed for Forever
--   Open questions for individual entries are tracked in docs/followups.md.
--   cost / price are in copper (100 = 1s, 10000 = 1g)
--   coords are {x, y} on the zone map. For NPCs that have several spawn points or walk a path,
--   the first/main point is given and the others go in a comment.
--
-- Sources (fetched 2026-11-19):
--   Forever: nether.wowhead.com/forever/tooltip/{npc,item,quest}/<id> (Forever NPC IDs, levels, map coords,
--              item tooltips); wowhead.com/forever/quest=<id> pages (Camping 101 quests, 6607, 6610);
--            timesaver.gg/tools/wow-forever/professions/{fishing,cooking} (trainer lists with NPC IDs, rank costs);
--            warcrafttavern.com/forever/guides/profession-trainers + /cooking-leveling;
--            wow-professions.com/forever/{fishing-trainers,cooking-trainers,how-to-fish,npc/*};
--            warcraft.wiki.gg (Forever_fishing_techniques, Camping_101:_Fishing, Camping_101:_Cooking,
--              Lee_Brown, Gilbert_Gray, Shiny_Silver_Coin, Gritta_Chumwater, Baelann_Swiftcurrent, Expert_Cookbook);
--            allthings.how (Camping 101: Cooking, Fishin' Time walkthroughs).
--   Classic baseline: warcraft.wiki.gg quest pages for 6607 / 6610 (step details, ingredient sources).
--   Not used: forever.warcraftdb.com (pages render client-side, no data reachable), metaforge and
--     icy-veins (HTTP 403). Wowhead pages were only read through their tooltip/quest endpoints; no CAPTCHA was attempted.

FCE_Research_Training = {
  professions = {

    ------------------------------------------------------------------------------------------------
    -- FISHING
    ------------------------------------------------------------------------------------------------
    fishing = {
      ranks = {
        { rank = "Apprentice", cap = 75, reqSkill = 0, reqLevel = 0, method = "trainer", cost = 100, source = "forever",
          note = "Forever: no level requirement (wow-professions). Classic required level 5. Cost 1s (timesaver.gg). Any fishing trainer." },
        { rank = "Journeyman", cap = 150, reqSkill = 50, reqLevel = 10, method = "trainer", cost = 500, source = "forever",
          note = "Every fishing trainer in Forever teaches up to Journeyman. Cost 5s (timesaver.gg, wow-professions)." },
        { rank = "Expert", cap = 225, reqSkill = 125, reqLevel = 20, method = "book", cost = 10000, source = "forever",
          book = { itemID = 16083, name = "Expert Fishing - The Bass and You",
                   tooltip = "Requires Level 20, Requires Fishing (125). Teaches Expert Fisherman (max 225). Sells to vendor for 25s." },
          sources = {
            { npc = "Old Man Heming", npcID = 2626, title = "Fisherman", zone = "Stranglethorn Vale", subzone = "Booty Bay",
              coords = {27.4, 77.0}, faction = "N", price = 10000, source = "forever",
              note = "Lowest level of Booty Bay, near the fishing sign. Price 1g per timesaver.gg / wow-professions; tooltip sell price 25s is consistent." },
          },
          note = "No trainer teaches Expert Fishing in Forever. Heming is the only vendor found; the book is tradeable (Auction House)." },
        { rank = "Artisan", cap = 300, reqSkill = 225, reqLevel = 35, method = "quest", cost = 0, source = "forever",
          quest = { id = 6607, name = "Nat Pagle, Angler Extreme", npc = "Nat Pagle", npcID = 12919,
                    zone = "Dustwallow Marsh", subzone = "Small island SW of Theramore Isle", coords = {58.6, 60.0}, faction = "N",
                    reqLevel = 35, reqSkill = 225,
                    summary = "Catch four quest fish and bring them back to Nat Pagle: Misty Reed Mahi Mahi (Misty Reed Strand, Swamp of Sorrows, ~93,40), "
                           .. "Sar'theris Striker (Sar'theris Strand, Desolace, ~25,77), Feralas Ahi (Verdantis River, Feralas, ~62,51) and "
                           .. "Savage Coast Blue Sailfin (Savage Coast, Stranglethorn Vale, ~33,32). Each fish is an extra loot on top of the normal catch. "
                           .. "The hard parts: the fish only drop in those exact water spots, you need fishing skill high enough for those zones "
                           .. "(Feralas and the Swamp of Sorrows coast are the toughest), and quest fish cannot drop while you are in a raid group.",
                    reward = "Artisan Fishing (spell 18248)",
                    source = "forever",
                    note = "Forever: wowhead.com/forever/quest=6607 exists and rewards spell 18248; the four fish are confirmed by the Forever tooltip. "
                        .. "Level 35 is per warcraft.wiki.gg Forever_fishing_techniques. Fish-spot coordinates are classic-baseline (warcraft.wiki.gg). "
                        .. "wow-professions could not test this quest during the beta." } },
      },

      -- 25 unique fishing trainers (timesaver.gg and warcrafttavern Forever lists agree on the set).
      -- All teach Apprentice + Journeyman only. NPC IDs are from timesaver.gg / warcraft.wiki.gg, and coords are from the
      -- Forever wowhead tooltip, unless noted.
      trainers = {
        -- Alliance
        { npc = "Lee Brown", npcID = 1651, zone = "Elwynn Forest", subzone = "Crystal Lake (Goldshire)", coords = {47.6, 62.2}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Paxton Ganter", npcID = 1700, zone = "Dun Morogh", subzone = "Iceflow Lake", coords = {35.6, 40.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Androl Oakhand", npcID = 3607, zone = "Teldrassil", subzone = "Rut'theran Village", coords = {55.8, 93.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Astaia", npcID = 4156, zone = "Darnassus", subzone = "Temple Gardens", coords = {47.4, 56.6}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Arnold Leland", npcID = 5493, zone = "Stormwind City", subzone = "The Canals (Trade District dock)", coords = {55.0, 69.6}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Grimnur Stonebrand", npcID = 5161, zone = "Ironforge", subzone = "The Forlorn Cavern", coords = {48.4, 6.4}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- also 48.2,8.0
        { npc = "Warg Deepwater", npcID = 1683, zone = "Loch Modan", subzone = "The Loch", coords = {40.4, 39.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Matthew Hooper", npcID = 1680, zone = "Redridge Mountains", subzone = "Lakeshire", coords = {21.4, 51.0}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- also spawns ~26.4,50.4
        { npc = "Harold Riggs", npcID = 3179, zone = "Wetlands", subzone = "Menethil Harbor", coords = {8.0, 58.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Donald Rabonne", npcID = 2367, zone = "Hillsbrad Foothills", subzone = "Southshore", coords = {50.4, 64.2}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- also 50.4,61.0
        { npc = "Hunter Moore", npcID = 255877, zone = "Hillsbrad Foothills", subzone = "Island off the Southshore coast", coords = {54.0, 80.2}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Brannock", npcID = 7946, zone = "Feralas", subzone = "Feathermoon Stronghold", coords = {32.2, 41.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        -- Horde
        { npc = "Lumak", npcID = 3332, zone = "Orgrimmar", subzone = "Valley of Honor", coords = {69.6, 29.2}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Kah Mistrunner", npcID = 3028, zone = "Thunder Bluff", subzone = "Middle Rise", coords = {56.0, 46.8}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- also 55.8,47.6
        { npc = "Armand Cromwell", npcID = 4573, zone = "Undercity", subzone = "The Magic Quarter", coords = {81.0, 29.8}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- wanders 80.4-81.6, 29.8-32.0
        { npc = "Lau'Tiki", npcID = 5941, zone = "Durotar", subzone = "Sen'jin Village", coords = {53.2, 81.4}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- warcraft.wiki.gg Camping 101 page says 63.2,45.2 (likely a typo)
        { npc = "Uthan Stillwater", npcID = 5938, zone = "Mulgore", subzone = "Stonebull Lake (by Bloodhoof Village)", coords = {44.4, 60.6}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- also a spawn point at 44.2,63.8
        { npc = "Clyde Kellen", npcID = 5690, zone = "Tirisfal Glades", subzone = "Brightwater Lake", coords = {67.2, 51.0}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Kil'Hiwana", npcID = 12961, zone = "Ashenvale", subzone = "Zoram'gar Outpost", coords = {10.8, 33.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Lui'Mala", npcID = 12032, zone = "Desolace", subzone = "Shadowprey Village", coords = {22.6, 72.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Katoom the Angler", npcID = 14740, zone = "The Hinterlands", subzone = "Revantusk Village", coords = {80.4, 81.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        -- Neutral
        { npc = "Myizz Luckycatch", npcID = 2834, zone = "Stranglethorn Vale", subzone = "Booty Bay (under the hanging shark)", coords = {27.6, 77.0}, faction = "N", maxRank = "Journeyman", source = "forever" },
        { npc = "Krix", npcID = 260558, zone = "Riverglades", subzone = "Powderfuse Port", coords = {79.2, 54.8}, faction = "N", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Superior Fisherman>, level 43
        { npc = "Baelann Swiftcurrent", npcID = 257008, zone = "Zephras Isle", subzone = "Valanaar", coords = {63.2, 75.6}, faction = "N", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Fisher>. Also sells lures, poles and the Chef's Knife
        { npc = "Fenn Fairweather", npcID = 251992, zone = "Zephras Isle", subzone = "Shen'dar Village", coords = {45.0, 48.4}, faction = "N", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Fisherman>
      },

      quests = { -- extra starter/side quests that teach or advance the profession
        { id = nil, name = "Camping 101: Fishing", level = 6, reqLevel = 4, reqSkill = 20, faction = "A/H",
          npc = "Starting-zone adventurer (see givers)", zone = "Starting zones", coords = nil,
          givers = {
            { npc = "Eric Brighthammer", zone = "Dun Morogh", coords = {46.6, 53.8}, faction = "A" },
            { npc = "Lyreena Duskblade", zone = "Teldrassil", coords = {57.6, 56.6}, faction = "A" },
            { npc = "Sam Sarsaparilla", zone = "Elwynn Forest", coords = {44.8, 63.2}, faction = "A" },
            { npc = "Brakk", zone = "Durotar", coords = {52.0, 47.4}, faction = "H" },
            { npc = "Eleanor Shackleton", zone = "Tirisfal Glades", coords = {57.3, 55.5}, faction = "H" },
            { npc = "Kaga Wildhoof", zone = "Mulgore", coords = {46.2, 67.2}, faction = "H" },
            { npc = "Raan Wildwind", zone = "Zephras Isle", coords = {41.6, 44.8}, faction = "N" },
          },
          enders = { -- one quest ID per variant (wowhead Forever)
            { id = 96050, npc = "Paxton Ganter", npcID = 1700, zone = "Dun Morogh", coords = {35.4, 40.2} },
            { id = 97943, npc = "Astaia", npcID = 4156, zone = "Darnassus", coords = {47.4, 56.6} },
            { id = nil,   npc = "Lee Brown", npcID = 1651, zone = "Elwynn Forest", coords = {47.6, 62.2} }, -- quest ID not found
            { id = 97904, npc = "Lau'Tiki", npcID = 5941, zone = "Durotar", coords = {53.2, 81.4} },
            { id = 97956, npc = "Clyde Kellen", npcID = 5690, zone = "Tirisfal Glades", coords = {67.2, 51.0} },
            { id = 97932, npc = "Uthan Stillwater", npcID = 5938, zone = "Mulgore", coords = {44.4, 60.6} },
            { id = 97967, npc = "Fenn Fairweather", npcID = 251992, zone = "Zephras Isle", coords = {45.0, 48.4} },
          },
          summary = "Follows 'The Great Outdoors'. Raise Fishing to 20, then speak with your starting-zone fishing trainer. "
                 .. "It does not teach a fishing rank; it unlocks the camping side of the profession.",
          reward = "Recipe: Fish Bowl (spell 1229745, camp item: +8% stats to nearby seated players) and 270 XP",
          source = "forever" },
        { id = nil, name = "Bottles and Baubles", level = 7, faction = "A",
          npc = "Lee Brown", npcID = 1651, zone = "Elwynn Forest", subzone = "Crystal Lake (Goldshire)", coords = {47.6, 62.2},
          summary = "Forever-only fishing quest from Lee Brown (warcraft.wiki.gg lists it on his page). Objectives not documented yet.",
          reward = "Shiny Silver Coin (item 286732): toss into water for +30 Fishing for 30 min, stacks to 20, BoP",
          source = "forever" },
        { id = nil, name = "Fishin' Time", level = 12, faction = "A",
          npc = "Gilbert Gray", npcID = 267118, zone = "Stormwind City", subzone = "Stormwind Harbor pier", coords = {26.2, 47.0},
          summary = "Buy 1 Shiny Bauble and 3 Nightcrawlers from Catherine Leland <Fishing Supplier> (npcID 5494, Stormwind canals, 55.0, 69.4) "
                 .. "and return them. Nothing to catch and no pole needed. Objectives come from a walkthrough that does not name the game version.",
          reward = "Not documented",
          source = "forever" },
      },
    },

    ------------------------------------------------------------------------------------------------
    -- COOKING
    ------------------------------------------------------------------------------------------------
    cooking = {
      ranks = {
        { rank = "Apprentice", cap = 75, reqSkill = 0, reqLevel = 0, method = "trainer", cost = 100, source = "forever",
          note = "Cost 1s (allthings.how Camping 101: Cooking walkthrough, wow-professions). Any cooking trainer; the 'Camping 101: Cooking' quest sends new characters to one." },
        { rank = "Journeyman", cap = 150, reqSkill = 50, reqLevel = 0, method = "trainer", cost = 500, source = "forever",
          note = "Every cooking trainer teaches up to Journeyman. Cost 5s (wow-professions, which does not name the unit; silver assumed, matching fishing). "
              .. "wow-professions and warcrafttavern list no level requirement; Classic required level 10." },
        { rank = "Expert", cap = 225, reqSkill = 125, reqLevel = 0, method = "book", cost = 10000, source = "forever",
          book = { itemID = 16072, name = "Expert Cookbook",
                   tooltip = "Requires Cooking (125), no level requirement. Teaches Expert Cook (max 225). Sells to vendor for 25s." },
          sources = {
            { npc = "Shandrina", npcID = 3955, title = "Trade Goods", zone = "Ashenvale", subzone = "Silverwind Refuge (Mystral Lake)",
              coords = {49.6, 67.0}, faction = "A", price = 10000, source = "forever" },
            { npc = "Wulan", npcID = 12033, title = "Cooking Supplies", zone = "Desolace", subzone = "Shadowprey Village (top floor, easternmost building)",
              coords = {26.2, 69.8}, faction = "H", price = 10000, source = "forever" },
          },
          note = "No trainer teaches Expert Cooking in Forever. Price 1g (wow-professions, timesaver; warcraft.wiki.gg Expert_Cookbook says it is still sold in Forever). "
              .. "warcrafttavern's walkthrough says the book is learned at 150, but its own table says 125, as does the item tooltip. The book is tradeable." },
        { rank = "Artisan", cap = 300, reqSkill = 225, reqLevel = 35, method = "quest", cost = 0, source = "forever",
          quest = { id = 6610, name = "Clamlette Surprise", npc = "Dirge Quikcleave", npcID = 8125, title = "Butcher",
                    zone = "Tanaris", subzone = "Gadgetzan (inside the inn)", coords = {52.6, 28.0}, faction = "N",
                    reqLevel = 35, reqSkill = 225,
                    summary = "Bring Dirge 12 Giant Egg (item 12207), 10 Zesty Clam Meat (item 7974) and 20 Alterac Swiss (item 8932). "
                           .. "Giant Eggs drop from Rocs and Fire Rocs in Tanaris (level 41-43+) and from owlbeasts in the Hinterlands, Felwood and Winterspring. "
                           .. "This is the hard part at level 35, so most players buy them on the Auction House or get help. "
                           .. "Zesty Clam Meat comes from Big-mouth Clams dropped by coastal mobs level 35+ (Tidal Striders south of Gadgetzan are the easiest; also Azshara). "
                           .. "Alterac Swiss is sold by Food & Drink vendors, e.g. Ben Trias, Stormwind (66.4, 73.7) for Alliance and Innkeeper Pala, Thunder Bluff (45.9, 64.8) for Horde. "
                           .. "Gather everything before accepting the quest.",
                    reward = "Artisan Cooking (spell 18260) and a Clamlette Surprise (item 16971)",
                    source = "forever",
                    note = "Forever: wowhead.com/forever/quest=6610 lists the 12/10/20 objectives and the spell 18260 reward. Level 35 per wow-professions and warcrafttavern Forever guides. "
                        .. "Item drop sources are classic-baseline (warcraft.wiki.gg). In Classic, players exalted with the Bloodsail Buccaneers (hostile to Gadgetzan) cannot get the quest." } },
      },

      -- 22 unique cooking trainers (timesaver.gg and warcrafttavern Forever lists agree). All teach up to Journeyman.
      trainers = {
        -- Alliance
        { npc = "Tomas", npcID = 1430, zone = "Elwynn Forest", subzone = "Goldshire (Lion's Pride Inn)", coords = {44.2, 66.0}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Stephen Ryback", npcID = 5482, zone = "Stormwind City", subzone = "Old Town (Pig and Whistle Tavern)", coords = {78.2, 53.0}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Gremlock Pilsnor", npcID = 1699, zone = "Dun Morogh", subzone = "Kharanos (Thunderbrew Distillery)", coords = {47.6, 52.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Cook Ghilm", npcID = 1355, zone = "Dun Morogh", subzone = "Gol'Bolar Quarry", coords = {68.4, 54.4}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Daryl Riknussun", npcID = 5159, zone = "Ironforge", subzone = "The Great Forge", coords = {60.0, 36.8}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- also 60.4,38.0
        { npc = "Zarrin", npcID = 6286, zone = "Teldrassil", subzone = "Dolanaar", coords = {57.0, 61.2}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Alegorn", npcID = 4210, zone = "Darnassus", subzone = "Craftsmen's Terrace", coords = {49.0, 21.2}, faction = "A", maxRank = "Journeyman", source = "forever" },
        { npc = "Crystal Boughman", npcID = 3087, zone = "Redridge Mountains", subzone = "Lakeshire", coords = {17.6, 43.6}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- also a spawn point at 22.8,43.4
        { npc = "Katherine Lee", npcID = 252084, zone = "Alterac Mountains", subzone = "City of Dalaran", coords = {12.6, 65.8}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- Forever-new (new ID). wow-professions puts her in 'A Hero's Welcome'
        { npc = "Hnaz Blunderflame", npcID = 249968, zone = "Mount Hyjal", subzone = "Elderwild", coords = {15.6, 50.2}, faction = "A", maxRank = "Journeyman", source = "forever" }, -- Forever-new. Tooltip shows 'Gnomeregan Exiles', not a cook title; listed as a trainer by timesaver + warcrafttavern
        -- Horde
        { npc = "Zamja", npcID = 3399, zone = "Orgrimmar", subzone = "The Drag", coords = {57.4, 53.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Aska Mistrunner", npcID = 3026, zone = "Thunder Bluff", subzone = "Middle Rise", coords = {50.8, 52.4}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Eunice Burch", npcID = 4552, zone = "Undercity", subzone = "Trade Quarter", coords = {62.4, 44.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Cook Torka", npcID = 3191, zone = "Durotar", subzone = "Razor Hill", coords = {51.2, 42.6}, faction = "H", maxRank = "Journeyman", source = "forever" },
        { npc = "Pyall Silentstride", npcID = 3067, zone = "Mulgore", subzone = "Bloodhoof Village (Great Tent, NW corner)", coords = {45.0, 61.6}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- second spawn 45.6,58.0 (warcraft.wiki.gg Camping 101 uses this one)
        { npc = "William Pickman", npcID = 265944, zone = "Tirisfal Glades", subzone = "Brill (Gallows' End Tavern kitchen)", coords = {61.8, 51.4}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- Forever-new
        { npc = "Duhng", npcID = 8306, zone = "The Barrens", subzone = "The Crossroads (east tower)", coords = {55.2, 31.8}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- timesaver says both factions
        { npc = "Mudduk", npcID = 1382, zone = "Stranglethorn Vale", subzone = "Grom'gol Base Camp", coords = {31.4, 28.0}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- title <Superior Cook>
        { npc = "Gorg", npcID = 256655, zone = "Riverglades", subzone = "Rog'mar", coords = {58.6, 44.4}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Cook>
        { npc = "Ortak Lomgok", npcID = 244512, zone = "Mount Hyjal", subzone = "Elderwild", coords = {13.0, 52.8}, faction = "H", maxRank = "Journeyman", source = "forever" }, -- Forever-new. Tooltip title is <Innkeeper>; listed as a trainer by timesaver + warcrafttavern
        -- Neutral (Zephras Isle, usable by both factions)
        { npc = "Zerril Softbreeze", npcID = 251905, zone = "Zephras Isle", subzone = "Shen'dar Village", coords = {43.8, 43.8}, faction = "N", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Cook>
        { npc = "Nyalah Brightfire", npcID = 257006, zone = "Zephras Isle", subzone = "Valanaar", coords = {60.6, 72.6}, faction = "N", maxRank = "Journeyman", source = "forever" }, -- Forever-new, title <Cook>
      },

      quests = {
        { id = nil, name = "Camping 101: Cooking", level = 6, reqLevel = 4, faction = "A/H",
          npc = "Starting-zone adventurer (see givers)", zone = "Starting zones", coords = nil,
          givers = {
            { npc = "Eric Brighthammer", zone = "Dun Morogh", coords = {46.6, 53.8}, faction = "A" },
            { npc = "Lyreena Duskblade", zone = "Teldrassil", coords = {57.6, 56.6}, faction = "A" },
            { npc = "Sam Sarsaparilla", zone = "Elwynn Forest", coords = {44.8, 63.2}, faction = "A" },
            { npc = "Brakk", zone = "Durotar", coords = {52.0, 47.4}, faction = "H" },
            { npc = "Eleanor Shackleton", zone = "Tirisfal Glades", coords = {57.3, 55.5}, faction = "H" },
            { npc = "Kaga Wildhoof", zone = "Mulgore", coords = {46.2, 67.2}, faction = "H" },
            { npc = "Raan Wildwind", zone = "Zephras Isle", coords = {41.6, 44.8}, faction = "N" },
          },
          enders = { -- the trainer you learn from; one quest ID per variant (wowhead Forever)
            { id = 96629, npc = "Gremlock Pilsnor", npcID = 1699, zone = "Dun Morogh", subzone = "Kharanos", coords = {47.6, 52.4} },
            { id = 96634, npc = "Zarrin", npcID = 6286, zone = "Teldrassil", subzone = "Dolanaar", coords = {57.0, 61.2} },
            { id = nil,   npc = "Tomas", npcID = 1430, zone = "Elwynn Forest", subzone = "Goldshire", coords = {44.2, 66.0} }, -- quest ID not found
            { id = 96655, npc = "Cook Torka", npcID = 3191, zone = "Durotar", subzone = "Razor Hill", coords = {51.2, 42.6} },
            { id = nil,   npc = "William Pickman", npcID = 265944, zone = "Tirisfal Glades", subzone = "Brill", coords = {61.8, 51.6} }, -- quest ID not found
            { id = 96661, npc = "Pyall Silentstride", npcID = 3067, zone = "Mulgore", subzone = "Bloodhoof Village", coords = {45.6, 58.0} },
            { id = 96646, npc = "Zerril Softbreeze", npcID = 251905, zone = "Zephras Isle", subzone = "Shen'dar Village", coords = {43.8, 43.8} },
          },
          summary = "Follows 'The Great Outdoors'. The only objective is to learn Cooking (Apprentice, 1s) from the starting-zone cooking trainer and turn the quest in to them. "
                 .. "This is the Forever route into Apprentice Cooking. It also unlocks the camp system: the Basic Campfire Kit (3 camp objects) "
                 .. "is crafted from Flint and Tinder + Simple Wood.",
          reward = "270 XP (and the Apprentice Cooking you trained for the objective)",
          source = "forever" },
      },
    },
  },

  foreverChanges = {
    "Rank structure matches Classic: trainers teach only Apprentice (1-75) and Journeyman (75-150). Expert comes from a book (Expert Fishing - The Bass and You / Expert Cookbook). Artisan comes from a quest (Nat Pagle, Angler Extreme / Clamlette Surprise). No Forever source shows a rank above Artisan or a trainer that teaches Expert.",
    "Apprentice Fishing has no level requirement in Forever (Classic: level 5). Journeyman Fishing needs skill 50 and level 10.",
    "The Expert Fishing book's Forever tooltip says Requires Level 20 (Classic had a level requirement until 2.4.0). The Expert Cookbook tooltip shows no level requirement.",
    "Costs per timesaver.gg: Apprentice 1s, Journeyman 5s, Expert book 1g, Artisan quest free (1g 6s total for fishing). Cooking follows the same pattern per wow-professions.",
    "Fishing is not in the spellbook in Forever. You drag it to your action bar from the Professions window.",
    "New Forever fishing trainers: Krix <Superior Fisherman> (Powderfuse Port, Riverglades, neutral), Baelann Swiftcurrent <Fisher> (Valanaar, Zephras Isle), Fenn Fairweather <Fisherman> (Shen'dar Village, Zephras Isle) and Hunter Moore <Fisherman> (island off the Hillsbrad coast).",
    "New Forever cooking trainers: Gorg (Rog'mar, Riverglades, Horde), Katherine Lee (City of Dalaran, Alterac Mountains, Alliance), Hnaz Blunderflame (Elderwild, Mount Hyjal, Alliance), Ortak Lomgok (Elderwild, Mount Hyjal, Horde), William Pickman (Brill, Horde, replaces the Classic Brill cook), and Zerril Softbreeze and Nyalah Brightfire (Zephras Isle, neutral).",
    "No fishing trainer was found in Riverglades' Horde town, City of Dalaran, Mount Hyjal or Shen'dralas, and no cooking trainer in Powderfuse Port or Shen'dralas. Absence is not confirmed.",
    "New Forever starter quests: 'The Great Outdoors' leads to 'Camping 101: Cooking' (learn Apprentice Cooking at the starting-zone cook, level 6, requires 4) and 'Camping 101: Fishing' (reach Fishing 20, rewards the Fish Bowl recipe).",
    "New Forever fishing side quests: 'Bottles and Baubles' (Lee Brown, Elwynn; rewards Shiny Silver Coin, +30 Fishing for 30 min) and 'Fishin' Time' (Gilbert Gray, Stormwind Harbor). Quest IDs and levels are not verified.",
    "Fishing camp items (Fish Bowl at skill 20, Fishing Rack, Fishing Hut) are learned from fishing trainers or recipes. Campfire kits (Basic; Journeyman at Cooking 140; Expert at Cooking 220 from blueprints) are tied to Cooking.",
    "Powderfuse Port also has Gritta Chumwater <Fisherman> (npcID 260487, 78.4, 55.0), a fishing vendor (lures, poles, Chef's Knife, Fresh Chum, recipes). She does not train.",
  },
}
