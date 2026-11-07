# FishCatchVisualizer

A WoW: Forever addon that logs every fish you catch in the **subzone** you caught it, per
character and per fishing session.

- **Catch window.** With a fishing pole in hand, a small see-through window shows what you
  caught where you stand: one bar per item, with how many and their share, and how many kinds
  ("3/5 kinds": in this view, out of every kind your account caught here). Buttons pick whose
  catches it counts: this **session**, this **character**, **all** your characters, or all of
  them plus your **guild**.
- **New here!** The first catch of an item at a place, over your whole account, says so in chat
  and is marked "new" in the window until you leave.
- **Item tooltip.** An item you caught shows where: "Crystal Lake, Elwynn Forest 45% (21)"
  means 45% of what was caught there was this item, 21 of them. Best spots first. Then its
  biggest stack, and when it seems to bite: "Only at night", "Only in winter and spring".
- **Records.** Biggest stack per item, most catches in a session, longest session; beating one
  says so in chat.
- **Data broker.** "12 caught" this session in Titan Panel, ChocolateBar, ElvUI's datatexts; its
  tooltip has the session, the rarest catch where you stand and the records.
- **Guild.** Guildmates with the addon swap their counts (numbers only), so the Guild view and
  the tooltips show where they caught what too. Can be switched off.
- **Subzone or whole zone.** The window covers the subzone you stand in, or the whole zone.

Move the window, and set its size and opacity, in the game's **Edit Mode** (Esc > Edit Mode).
Each Edit Mode layout keeps its own spot. Its background is see-through until you raise the
opacity.

**Text:** any font LibSharedMedia knows (ElvUI's and SharedMedia's too), a size, an outline
(none, thin, thick), high quality Slug rendering on top of any outline, a title and a text colour
(gold and pure white), items in their quality's colour, and a shadow with its own colour and x/y
offset (fractions too). The same settings are in the options and in the window's Edit Mode
dialog.

## Commands

| Command | Does |
|---|---|
| `/fcv options` (or `config`) | opens the options in their own window |
| `/fcv show pole\|always\|never` | when the catch window shows |
| `/fcv scope area\|zone` | the subzone you stand in, or the whole zone |
| `/fcv view session\|char\|account\|guild` | whose catches the window counts |

The same settings, plus the item tooltip, the guild and clearing the log, are in Esc > Options >
AddOns > FishCatchVisualizer.

## How it works

### What counts as a catch

`LOOT_READY` or `LOOT_OPENED` with `IsFishingLoot()` true: every item slot of that loot window is
one catch of its stack size, logged where the player stands. Both events are read because
fast-loot addons (GogoLoot, ElvUI plugins, TweaksForever) loot on `LOOT_READY` and may close the
window before `LOOT_OPENED`, and `LOOT_READY` can come twice with slots the first lacked; each slot
counts once per window (`LOOT_CLOSED`, or a quiet second, starts over). Money and anything the
client hides (secret values) are skipped. `OnLoot` handles each item in a fixed order: whether it is new at the
place, the log, the time of day and season, the records, "New here", the data broker, then the
AceEvent message `FISHCATCHVISUALIZER_CATCH` (itemID, quantity, mapID, area), which also refreshes
the window. `FISHCATCHVISUALIZER_NEW_HERE` (itemID, mapID, area) goes out on an item's first catch
at a place.

### Day and night, seasons

`Core\Times.lua`: each catch is counted in `global.times[itemID]` and `global.times[0]` (all
catches) by `day`/`night` (server time from `GetGameTime`, day from 6 to 18) and by season
(`C_DateAndTime.GetCurrentCalendarTime().month`, northern: winter is December to February). The
tooltip says "Only at night" or "Only in winter and spring" once the item was caught at least 5
times and the other time or season was fished at least 20 times without it.

### Records

`Core\Records.lua`: `global.records.stacks[itemID] = { n, mapID, area, t }`, and
`sessionCatches`/`sessionLength` `{ n, session }` (the session's start, so beating a record set by
another session says so, once per session). A first value is kept quietly.

### Guild

`Core\Share.lua`: AceComm prefix NAME cut to 16 characters, channel GUILD. "H" is a hello (sent
10 s after login); "S" .. Base64(Deflate(CBOR({ id, zones }))) a snapshot of the account's counts,
answered 3 to 15 s after a hello and sent when the pole goes away, at most once every 5 minutes.
`global.shareId` is the account's ID; a snapshot is kept in `global.guild[id] = { name, zones, t }`
after only numeric counts are taken from it. The Guild view and the item tooltips add it.

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
| `Core\Debug.lua` | log lines and counts for OAP Debug |
| `Core\Place.lua` | map and area key of where the player stands, place names |
| `Core\Log.lua` | recording catches, sessions, counts at a place, an item's places |
| `Core\Times.lua` | day and night, seasons, the tooltip's time notes |
| `Core\NewHere.lua` | "New here!" and its marks |
| `Core\Records.lua` | stack and session records, the rarest catch at a place |
| `Core\Broker.lua` | the data broker object (LibDataBroker-1.1) |
| `Core\Share.lua` | swapping counts with the guild (AceComm) |
| `Core\Detect.lua` | the fishing pole and fishing loot |
| `Core\Text.lua` | the windows' font, outline, Slug and shadow (LibSharedMedia) |
| `Core\Window.lua` | the bar list window and its Edit Mode hookup (LibEditMode) |
| `Core\CatchWindow.lua` | the catch window's content |
| `Core\Tooltip.lua` | the item tooltip lines (`TooltipDataProcessor`) |
| `Core\Commands.lua`, `Core\Options.lua` | `/fcv` and the AceConfig options |

### OAP Debug

`Core\Debug.lua`, the only file that talks to OAP Debug (as in BattleCry): when it is installed
the addon registers under its folder and sends log lines and counts, as much as the "OAP Debug"
level in the options asks (errors only, normal, normal and counts, detailed). Logged: every loot
event (detailed: the event, its slots, whether it is fishing loot), each catch with the event that
counted it, hidden slots, the area name lookup and its milliseconds, sessions starting, going on and
ending, and the guild (hello, counts sent and kept, dropped snapshots). Counted: catches, guild
snapshots sent and received.

### Screenshots while testing in game

`Core\Dev.lua`: in a copy straight from the repository (such as the game worktree) the options
have a Development box with "Dev screenshots", off until switched on. On, the first time each
kind of moment from the in-game checks happens (the window per view, in Edit Mode, for the whole
zone, without a subzone, with nothing caught or with more rows; a fishing loot window with and
without autoloot; an item tooltip with places, per tooltip; the options window; the first "New
here"), a grey
`[<NAME> dev] ...` chat line says which, then one screenshot goes to the game's `Screenshots`
folder, at most one every two seconds. What has a screenshot is kept in the saved data; "Forget
the screenshots taken" starts over. It hooks the addon's own methods and listens to LOOT_OPENED
itself. The whole file is a `--@debug@` block, which the packager comments out of every release;
the specs load the files the same way unless a client asks for `dev`.

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

Libraries come from the `.pkgmeta` externals: Ace3 with AceComm (pinned commit, as in
BattleCry), LibEditMode (tag 19, the first with interface 16001), LibSharedMedia-3.0 (svn tag
v12.1.3) and LibDataBroker-1.1 (pinned commit, as in BattleCry).

### Text

`Core\Text.lua`: profile fields `font` (a LibSharedMedia name; none means its default),
`fontSize`, `outline` (`Addon.outlines`: none, thin = `OUTLINE`, thick = `THICKOUTLINE`), `slug`,
`titleColor`, `textColor`, `qualityColors`, `shadow`, `shadowColor` (with alpha), `shadowX` and
`shadowY`. The SetFont flags are the outline's plus `SLUG`, comma-separated (`"OUTLINE, SLUG"`);
the title is two points larger. Colours are set on every font string, so the templates' own
colours (GameFontDisableSmall's grey) never show; the view buttons keep theirs (gold for the
chosen one). Item names carry `ITEM_QUALITY_COLORS[quality].hex`. Both the options and every
window's Edit Mode dialog read and write these same fields (Edit Mode's colour pickers hand over
ColorMixins; its sliders have no typed input, so the offsets go in half pixels there and in tenths
in the options' slider box), and a font an addon registers later (`LibSharedMedia_Registered`) is
applied when it arrives.

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
