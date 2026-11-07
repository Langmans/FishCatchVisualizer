---@meta
-- The addon's own types. Not loaded by the client: the .toc does not list this folder. The types
-- carry no addon name (`Addon...`), so a rename leaves them alone.

---The addon object, which is also the namespace the client hands every file; other addons reach
---it through AceAddon. What one file defines and another uses is listed here, so every file
---knows it.
---@class Addon: AceAddon, AceConsole-3.0, AceEvent-3.0
---@field NAME string the folder's name; every name the game sees starts from it
---@field SLASH_ALIAS string the slash command's short name
---@field Global fun(suffix: string): string a global name of the addon's own, NAME first
---@field Readable fun(value: GameValue): boolean not nil and not a secret value
---@field Percent fun(share: number): string a share as "45%"
---@field CurrentPlace fun(): (number?, AddonArea?) the player's map and area key
---@field ZoneName fun(mapID: number): string
---@field AreaName fun(mapID: number, area: AddonArea): string
---@field PlaceName fun(mapID: number, area: AddonArea): string
---@field NewBarWindow fun(key: string, name: string, color: number[]): AddonWindow
---@field catchWindow AddonWindow
---@field DevOptions? fun(self: Addon): table the development box of the options, only in a copy from the repository
---@field AddItemPlaces fun(self: Addon, tooltip: GameTooltip, data: AddonTooltipData?)
---@field L table<string, string> the client language's strings
---@field db AddonDB
---@field showModes table<string, string> when the catch window shows: showModes.pole is "pole"
---@field scopes table<string, string> the subzone or the whole zone: scopes.zone is "zone"
---@field views table<string, string> whose catches: views.session is "session"
---@field messages { catch: string } public AceEvent messages
---@field session? AddonSession the session going on, while a pole is in hand
---@field fishing? boolean whether a pole was in hand at the last check
---@field editing? boolean whether Blizzard's Edit Mode is open
---@field SetupCommands fun(self: Addon)
---@field SetupOptions fun(self: Addon)
---@field SetupTooltip fun(self: Addon)
---@field SetupEditMode fun(self: Addon)
---@field OpenOptions fun(self: Addon)
---@field HasFishingPole fun(self: Addon): boolean
---@field UpdateCatchWindow fun(self: Addon)
---@field UpdateFishing fun(self: Addon, event: string, slot: number?)
---@field OnLootOpened fun(self: Addon)
---@field StartSession fun(self: Addon): AddonSession
---@field EndSession fun(self: Addon)
---@field RecordCatch fun(self: Addon, mapID: number, area: AddonArea, itemID: number, name: string?, quantity: number)
---@field ClearLog fun(self: Addon)
---@field PlaceCounts fun(self: Addon, view: string, mapID: number, area: AddonArea?): (AddonRow[], number, number)
---@field ItemPlaces fun(self: Addon, itemID: number): AddonItemPlace[]?

---Any value the game hands over, before the addon checks it.
---@alias GameValue string|number|boolean|table|nil

---Where in a zone: the subzone's AreaTable ID, its text when the game has no ID for it, or 0 for
---no subzone (the zone itself).
---@alias AddonArea number|string

---Catch counts at one place: counts[itemID] = how many.
---@class AddonCounts
---@field [number] number

---A zone's catch counts by area.
---@class AddonZone
---@field [number|string] AddonCounts

---Catch counts: zones[mapID][area][itemID] = how many.
---@class AddonZones
---@field [number] AddonZone

---The saved variables (<NAME>DB), through AceDB.
---@class AddonDB: AceDBObject-3.0
---@field profile AddonProfile
---@field global AddonGlobal
---@field keys { char: string } AceDB's keys; char is "Name - Realm"

---The settings, per AceDB profile.
---@class AddonProfile
---@field show string a Addon.showModes value
---@field scope string a Addon.scopes value
---@field view string a Addon.views value
---@field rows number bars at most
---@field tooltip boolean whether item tooltips list the places
---@field tooltipPlaces number places listed at most
---@field layouts table<string, table<string, AddonWindowLayout>> per Edit Mode layout, per window key

---A window's place and look, every field set: Window.lua's defaults.
---@class AddonWindowLook
---@field point string
---@field x number
---@field y number
---@field scale number
---@field alpha number

---A window's place and look in one Edit Mode layout; a missing field takes Window.lua's default.
---@class AddonWindowLayout
---@field point? string
---@field x? number
---@field y? number
---@field scale? number
---@field alpha? number

---The catches, account-wide.
---@class AddonGlobal
---@field chars table<string, AddonChar> by "Name - Realm"
---@field sessions AddonSession[] oldest first
---@field items table<number, string> item names as caught, for items the client has not loaded
---@field dev? AddonDevData Core\Dev.lua's, in a copy from the repository

---The development screenshots' switch and what has been shot (Core\Dev.lua).
---@class AddonDevData
---@field on boolean
---@field shots table<string, true> by kind

---One character's catches.
---@class AddonChar
---@field zones AddonZones

---One fishing session: from a pole coming in hand until a break longer than 15 minutes.
---@class AddonSession
---@field char string "Name - Realm"
---@field start number server time
---@field last number server time of the last catch or of putting the pole away
---@field zones AddonZones

---One item at a place, as PlaceCounts hands it out.
---@class AddonRow
---@field itemID number
---@field count number

---One place an item was caught, as ItemPlaces hands it out.
---@class AddonItemPlace
---@field mapID number
---@field area AddonArea
---@field count number how many of the item
---@field total number how many of everything

---What TooltipDataProcessor hands an item tooltip's post-call, as far as the addon reads it.
---@class AddonTooltipData
---@field id GameValue the item ID; secret in some places

---A /fcv command.
---@class AddonCommand
---@field args string what it takes, for the list
---@field help string what it does
---@field run fun(rest: string)

---A bar list window (Core\Window.lua).
---@class AddonWindow
---@field key string its key in the saved layouts
---@field frame BackdropTemplate|Frame
---@field color number[] its bars' { r, g, b }
---@field title FontString
---@field subtitle FontString
---@field empty FontString the note when there is nothing
---@field more FontString the note when rows were left out
---@field rows AddonBarRow[]
---@field buttons table<string, AddonButton>
---@field lastButton? string the key of the button added last
---@field layoutName? string the Edit Mode layout in use

---A window's bar row.
---@class AddonBarRow
---@field bar StatusBar
---@field left FontString
---@field right FontString

---A window's button.
---@class AddonButton: Button
---@field label FontString
---@field selected? boolean
