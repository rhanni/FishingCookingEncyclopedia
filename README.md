# Fishing & Cooking Encyclopedia

A World of Warcraft: Forever addon that adds an encyclopedia tab to the profession window.

- **Fishing Waters:** zones grouped by the fishing skill they need, with their fish, pools and other catches. Each fish shows the cooking recipes it's used in and its auction house price.
- **Cooking Recipes:** every recipe that uses fished ingredients, with where to buy it, what it costs, and what the dish gives you. Filter by known/unknown and by benefit.
- **Training:** where to train each rank of Fishing and Cooking, or buy the books, including quest start locations.
- **Prices & Scan:** targeted auction house scanning for the raw fish and cooked dishes only, never the whole auction house.

Target: World of Warcraft: Forever 1.60.1 (`## Interface: 16001`).

## Install

Copy the `FishingCookingEncyclopedia` folder into the game's AddOns folder for the Forever client, for example `World of Warcraft/_forever_/Interface/AddOns/`.

## Use

- Open the profession window and click the addon's tab below the other profession tabs, or type `/fce`.
- At the auction house, click **Scan Fish Prices**, or turn on auto-scan in the Prices & Scan page.

| Command | What it does |
|---|---|
| `/fce` | Open the encyclopedia |
| `/fce scan` | Scan fish and dish prices (auction house must be open) |
| `/fce stop` | Stop a running scan |
| `/fce autoscan [on\|off]` | Toggle scanning when the auction house opens |
| `/fce price <item>` | Show the stored price for an item |
| `/fce reset prices` | Wipe stored prices for this realm |
| `/fce tab [top\|bottom]` | Where the addon's tab sits in the profession window (default: bottom) |

## Repository layout

| Path | Purpose |
|---|---|
| `*.lua`, `*.toc`, `Data/`, `Media/` | The addon itself |
| `research/` | Raw research data; `tools/build-data.ps1` turns it into `Data/*.lua` |
| `tools/` | Build, packaging and offline test scripts |
| `docs/followups.md` | Open questions and unconfirmed data |

## Development

```
powershell -File tools\build-data.ps1     # regenerate Data\*.lua from research\
powershell -File tools\package.ps1        # build a release zip
```

Fix data in `research/`, never in the generated `Data/*.lua` files.

## License

All Rights Reserved. See [LICENSE](LICENSE).
