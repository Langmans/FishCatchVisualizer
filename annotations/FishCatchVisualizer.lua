---@meta
-- FishCatchVisualizer's own types. Not loaded by the client: the .toc does not list this folder.

---The public addon object (ns.FCV; LibStub("AceAddon-3.0"):GetAddon("FishCatchVisualizer")).
---Methods defined in one file and called from another are listed here, so every file knows them.
---@class FishCatchVisualizer: AceAddon, AceConsole-3.0, AceEvent-3.0
---@field L table<string, string> the client language's strings
---@field db FishCatchVisualizerDB
---@field showModes table<string, string> when the catch window shows: showModes.pole is "pole"
---@field scopes table<string, string> the subzone or the whole zone: scopes.zone is "zone"
---@field views table<string, string> whose catches: views.session is "session"
---@field messages { catch: string } public AceEvent messages
---@field session? FishCatchVisualizerSession the session going on, while a pole is in hand
---@field fishing? boolean whether a pole was in hand at the last check
---@field editing? boolean whether Blizzard's Edit Mode is open
---@field SetupCommands fun(self: FishCatchVisualizer)
---@field SetupOptions fun(self: FishCatchVisualizer)
---@field SetupTooltip fun(self: FishCatchVisualizer)
---@field SetupEditMode fun(self: FishCatchVisualizer)
---@field OpenOptions fun(self: FishCatchVisualizer)
---@field HasFishingPole fun(self: FishCatchVisualizer): boolean
---@field UpdateCatchWindow fun(self: FishCatchVisualizer)
---@field UpdateFishing fun(self: FishCatchVisualizer, event: string, slot: number?)
---@field OnLootOpened fun(self: FishCatchVisualizer)
---@field StartSession fun(self: FishCatchVisualizer): FishCatchVisualizerSession
---@field EndSession fun(self: FishCatchVisualizer)
---@field RecordCatch fun(self: FishCatchVisualizer, mapID: number, area: FishCatchVisualizerArea, itemID: number, name: string?, quantity: number)
---@field ClearLog fun(self: FishCatchVisualizer)
---@field PlaceCounts fun(self: FishCatchVisualizer, view: string, mapID: number, area: FishCatchVisualizerArea?): (FishCatchVisualizerRow[], number, number)
---@field ItemPlaces fun(self: FishCatchVisualizer, itemID: number): FishCatchVisualizerItemPlace[]?

---Any value the game hands over, before the addon checks it.
---@alias GameValue string|number|boolean|table|nil

---Where in a zone: the subzone's AreaTable ID, its text when the game has no ID for it, or 0 for
---no subzone (the zone itself).
---@alias FishCatchVisualizerArea number|string

---Catch counts at one place: counts[itemID] = how many.
---@class FishCatchVisualizerCounts
---@field [number] number

---A zone's catch counts by area.
---@class FishCatchVisualizerZone
---@field [number|string] FishCatchVisualizerCounts

---Catch counts: zones[mapID][area][itemID] = how many.
---@class FishCatchVisualizerZones
---@field [number] FishCatchVisualizerZone

---FishCatchVisualizerDB, through AceDB.
---@class FishCatchVisualizerDB: AceDBObject-3.0
---@field profile FishCatchVisualizerProfile
---@field global FishCatchVisualizerGlobal
---@field keys { char: string } AceDB's keys; char is "Name - Realm"

---The settings, per AceDB profile.
---@class FishCatchVisualizerProfile
---@field show string a FCV.showModes value
---@field scope string a FCV.scopes value
---@field view string a FCV.views value
---@field rows number bars at most
---@field tooltip boolean whether item tooltips list the places
---@field tooltipPlaces number places listed at most
---@field layouts table<string, table<string, FishCatchVisualizerWindowLayout>> per Edit Mode layout, per window key

---A window's place and look, every field set: Window.lua's defaults.
---@class FishCatchVisualizerWindowLook
---@field point string
---@field x number
---@field y number
---@field scale number
---@field alpha number

---A window's place and look in one Edit Mode layout; a missing field takes Window.lua's default.
---@class FishCatchVisualizerWindowLayout
---@field point? string
---@field x? number
---@field y? number
---@field scale? number
---@field alpha? number

---The catches, account-wide.
---@class FishCatchVisualizerGlobal
---@field chars table<string, FishCatchVisualizerChar> by "Name - Realm"
---@field sessions FishCatchVisualizerSession[] oldest first
---@field items table<number, string> item names as caught, for items the client has not loaded

---One character's catches.
---@class FishCatchVisualizerChar
---@field zones FishCatchVisualizerZones

---One fishing session: from a pole coming in hand until a break longer than 15 minutes.
---@class FishCatchVisualizerSession
---@field char string "Name - Realm"
---@field start number server time
---@field last number server time of the last catch or of putting the pole away
---@field zones FishCatchVisualizerZones

---One item at a place, as PlaceCounts hands it out.
---@class FishCatchVisualizerRow
---@field itemID number
---@field count number

---One place an item was caught, as ItemPlaces hands it out.
---@class FishCatchVisualizerItemPlace
---@field mapID number
---@field area FishCatchVisualizerArea
---@field count number how many of the item
---@field total number how many of everything

---What TooltipDataProcessor hands an item tooltip's post-call, as far as the addon reads it.
---@class FishCatchVisualizerTooltipData
---@field id GameValue the item ID; secret in some places

---A /fcv command.
---@class FishCatchVisualizerCommand
---@field args string what it takes, for the list
---@field help string what it does
---@field run fun(rest: string)

---A bar list window (Core\Window.lua).
---@class FishCatchVisualizerWindow
---@field key string its key in the saved layouts
---@field frame BackdropTemplate|Frame
---@field color number[] its bars' { r, g, b }
---@field title FontString
---@field subtitle FontString
---@field empty FontString the note when there is nothing
---@field more FontString the note when rows were left out
---@field rows FishCatchVisualizerBarRow[]
---@field buttons table<string, FishCatchVisualizerButton>
---@field lastButton? string the key of the button added last
---@field layoutName? string the Edit Mode layout in use

---A window's bar row.
---@class FishCatchVisualizerBarRow
---@field bar StatusBar
---@field left FontString
---@field right FontString

---A window's button.
---@class FishCatchVisualizerButton: Button
---@field label FontString
---@field selected? boolean
