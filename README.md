# FishCatchVisualizer

A WoW: Forever addon that logs every fish you catch in the **subzone** you caught it, per
character and per fishing session.

- **Catch window.** With a fishing pole in hand, a small see-through window shows what you
  caught where you stand: one bar per item, with how many and their share. Buttons pick whose
  catches it counts: this **session**, this **character**, or **all** your characters.
- **Item tooltip.** An item you caught shows where: "Crystal Lake, Elwynn Forest 45% (21)"
  means 45% of what was caught there was this item, 21 of them. Best spots first.
- **Subzone or whole zone.** The window covers the subzone you stand in, or the whole zone.

Move the window, and set its size and opacity, in the game's **Edit Mode** (Esc > Edit Mode).
Each Edit Mode layout keeps its own spot.

## Commands

| Command | Does |
|---|---|
| `/fcv options` (or `config`) | opens the options in their own window |
| `/fcv show pole\|always\|never` | when the catch window shows |
| `/fcv scope area\|zone` | the subzone you stand in, or the whole zone |
| `/fcv view session\|char\|account` | whose catches the window counts |

The same settings, plus the item tooltip and clearing the log, are in Esc > Options > AddOns >
FishCatchVisualizer.

## How it works

### What counts as a catch

`LOOT_OPENED` with `IsFishingLoot()` true: every item slot of that loot window is one catch of
its stack size, logged where the player stands. Money and anything the client hides (secret
values) are skipped. Each catch also goes out as the AceEvent message
`FISHCATCHVISUALIZER_CATCH` (itemID, quantity, mapID, area) for other addons.

### Places

A place is a **uiMapID** (`C_Map.GetBestMapForUnit`) and an **area key**. The client only gives
the subzone's name (`GetSubZoneText`); the addon turns it into the AreaTable ID by scanning
`C_Map.GetAreaInfo(1..20000)` once, on the first catch, into a name → ID table. The ID is the
same in every client language, and names are shown live in the client's own. A subzone without
an ID keeps its text as key; no subzone at all is area `0`, the zone itself.

### Saved data (`FishCatchVisualizerDB`, AceDB)

- `global.chars["Name - Realm"].zones[mapID][area][itemID] = count`: every character's catches.
- `global.sessions[]`: `{ char, start, last, zones }` with the same `zones` shape. A session
  starts when a pole comes in hand and goes on when the pole comes back within 15 minutes of the
  last catch or of putting it away (also across a `/reload`). The newest 50 are kept.
- `global.items[itemID]`: the item's name as caught, for when the client has not loaded it.
- `profile`: the settings, and `layouts[layout][window] = { point, x, y, scale, alpha }` for
  Edit Mode.

### Files

| File | |
|---|---|
| `Core\Addon.lua` | the addon object, enums, saved-data defaults, event registration |
| `Core\Place.lua` | map and area key of where the player stands, place names |
| `Core\Log.lua` | recording catches, sessions, counts at a place, an item's places |
| `Core\Detect.lua` | the fishing pole and fishing loot |
| `Core\Window.lua` | the bar list window and its Edit Mode hookup (LibEditMode) |
| `Core\CatchWindow.lua` | the catch window's content |
| `Core\Tooltip.lua` | the item tooltip lines (`TooltipDataProcessor`) |
| `Core\Commands.lua`, `Core\Options.lua` | `/fcv` and the AceConfig options |

### Renaming

Every name the game and other addons see is made from the folder's name, `Addon.NAME`
(`Core\Addon.lua`): the saved variables (`<NAME>DB`), the window's frame (`<NAME>CatchesWindow`),
the slash command (`/<name>` in lower case, plus `SLASH_ALIAS` `/fcv`), the message
(`<NAME>_CATCH`), the locale and the options pages. `tests\names_spec.lua` loads the addon as
"Tester" and checks that all of these follow. The code carries no name: the addon object is
`Addon` (`local Addon = ns`), its types are `Addon...` in `annotations\Addon.lua`.

By hand: the folder and the repository, the `.toc`'s file name, `## Title` and
`## SavedVariables`, `.wowluarc.json`'s global, the rockspec, and the texts (locales, README).
A player's saved data stays under the old `<NAME>DB`: copy `WTF\Account\<account>\SavedVariables\<Old>.lua`
to `<New>.lua` and rename the table inside.

Libraries come from the `.pkgmeta` externals: Ace3 (pinned commit, as in BattleCry) and
LibEditMode (tag 19, the first with interface 16001).

## Development

```
.lua\bin\lua.exe tests\check.lua          lint, then the tests with the coverage check
.lua\bin\lua.exe tests\check.lua test     the tests (extra arguments go to busted)
.lua\bin\lua.exe tests\check.lua format   StyLua
```

`tests\setup-lua.ps1` installs Lua 5.1, busted, luacov and StyLua into `.lua\`. The tests run the
addon in a simulated WoW: Forever client (`tests\wow.lua`) with the real Ace3; LibEditMode is
replaced there by a stand-in with the same calls, since the client has no Edit Mode. Both line
coverage and WoW Lua LS type coverage must be 100%.

## License

MIT
