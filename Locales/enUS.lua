-- English strings, also the fallback for every other client language. Every string has a comment
-- saying where it appears and what each placeholder holds, for translators.
local addonName = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

-- One string per line, however long.
-- stylua: ignore start

-- Places. A subzone and its zone: "Crystal Lake, Elwynn Forest".
L.PLACE = "%s, %s"
-- A map the client has no name for; %d is its map ID.
L.MAP = "Map %d"

-- The catch window: its name in Edit Mode.
L.WINDOW_CATCHES = "Fish Catch Visualizer: your catches"
-- The catch window's subtitle: how many were caught at the place.
L.CAUGHT = "%d caught"
-- The catch window's subtitle in a subzone: the zone, then L.CAUGHT.
L.SUBTITLE = "%s · %s"
-- The catch window's title where the client cannot tell the map.
L.UNKNOWN_PLACE = "Somewhere unknown"
-- The catch window's subtitle, after L.CAUGHT: kinds in the view, out of every kind caught here.
L.KINDS = "%d/%d kinds"
-- The catch window, after an item first caught at the place.
L.NEW = "new"
-- Chat, on the first catch of an item at a place: the item, the place.
L.NEW_HERE_LINE = "New here: %s in %s"
-- The catch window when nothing was caught at the place.
L.NOTHING_HERE = "Nothing caught here yet."
-- The numbers on a bar: how many, then their share ("21 · 45%").
L.ROW_COUNT = "%d · %s"
-- Under the bars when not every item fits: how many were left out.
L.MORE = "and %d more"
-- The catch window's buttons: whose catches it counts.
L.BUTTON_SESSION = "Session"
L.BUTTON_CHAR = "Character"
L.BUTTON_ACCOUNT = "All"
L.BUTTON_GUILD = "Guild"
-- Edit Mode, a window's dialog: its sliders.
L.SCALE = "Size"
L.OPACITY = "Background opacity"
-- Edit Mode dialog and settings window, the Text and bars box: the windows' appearance, the same in
-- both.
L.APPEARANCE = "Text and bars"
L.FONT = "Font"
L.FONT_SIZE = "Text size"
L.OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_THIN = "Thin"
L.OUTLINE_THICK = "Thick"
L.SLUG = "High quality text"
L.SLUG_DESC = "Draws the text with the game's Slug renderer: sharp at any size, also with an outline."
L.SHADOW = "Text shadow"
L.SHADOW_COLOR = "Shadow colour"
-- The bars' texture, from the statusbar textures LibSharedMedia knows.
L.BAR_TEXTURE = "Bar texture"
-- The shadow's offset: right (or left, below 0), and up (or down, below 0), in pixels.
L.SHADOW_X = "Shadow offset x"
L.SHADOW_Y = "Shadow offset y"
L.TITLE_COLOR = "Title colour"
L.TEXT_COLOR = "Text colour"
L.QUALITY_COLORS = "Items in their quality's colour"
L.QUALITY_COLORS_DESC = "Poor items grey, uncommon green, rare blue."

-- The item tooltip: above the places an item was caught.
L.TOOLTIP_TITLE = "Caught at"
-- The data broker's tooltip (Titan Panel and the like): this session's catches and minutes.
L.BROKER_SESSION = "This session: %d caught in %d minutes"
L.BROKER_NO_SESSION = "No session yet."
-- The data broker's tooltip: the item caught least where the player stands, and its share.
L.BROKER_RAREST = "Rarest here: %s (%s)"
L.BROKER_RECORD_CATCHES = "Most catches in a session: %d"
L.BROKER_RECORD_LENGTH = "Longest session: %d minutes"
L.BROKER_CLICK = "Click: options"
-- The item tooltip, under the places: the item's biggest stack, and where ("5 (Crystal Lake, Elwynn
-- Forest)").
L.TOOLTIP_STACK = "Biggest stack: %d (%s)"
-- Chat, when a record falls: the item, the new stack, the old one.
L.RECORD_STACK = "New record: biggest stack of %s, %d (was %d)"
-- Chat: the catches of this session, the old record.
L.RECORD_CATCHES = "New record: %d catches in one session (was %d)"
-- Chat: this session's minutes, the old record's.
L.RECORD_LENGTH = "New record: a session of %d minutes (was %d)"
-- The item tooltip, under the places: when the item seems to bite (server time; day is 6 to 18).
L.ONLY_DAY = "Only by day"
L.ONLY_NIGHT = "Only at night"
-- The seasons the item bit in: "Only in winter and spring".
L.ONLY_IN = "Only in %s"
-- Joins the last of a list: "winter, spring" and "summer".
L.AND = "%s and %s"
L.SEASON_WINTER = "winter"
L.SEASON_SPRING = "spring"
L.SEASON_SUMMER = "summer"
L.SEASON_AUTUMN = "autumn"
-- The item tooltip, right of a place: the item's share there, then how many ("45% (21)").
L.TOOLTIP_SHARE = "%s (%d)"
-- The item tooltip when not every place fits: how many were left out.
L.TOOLTIP_MORE = "and %d more places"

-- /fcv: what each command does, after the command in the list.
L.HELP_OPTIONS = "open the options (also /fcv config)"
L.HELP_SHOW = "when the catch window shows"
L.HELP_SCOPE = "the subzone you stand in, or the whole zone"
L.HELP_VIEW = "whose catches the window counts"
-- /fcv show, /fcv scope, /fcv view: what was set.
L.SHOW_POLE = "The catch window shows while a fishing pole is in hand."
L.SHOW_ALWAYS = "The catch window always shows."
L.SHOW_NEVER = "The catch window stays hidden."
L.SCOPE_AREA = "The catch window shows the subzone you stand in."
L.SCOPE_ZONE = "The catch window shows the whole zone."
L.VIEW_SESSION = "The catch window counts this fishing session."
L.VIEW_CHAR = "The catch window counts this character's catches."
L.VIEW_ACCOUNT = "The catch window counts every character's catches."
L.VIEW_GUILD = "The catch window counts every character's catches and your guildmates'."

-- Settings window: the general page, its title and the text at its top.
L.GENERAL = "General"
L.GENERAL_DESC = "Logs every fish you catch in the subzone you caught it, per character and per fishing session. With a fishing pole in hand, a window shows what you caught where you stand; an item's tooltip shows where you caught it."
-- Settings window: the catch window's box and its settings.
L.WINDOW = "Catch window"
L.SHOW = "Show"
L.SHOW_MODE_POLE = "With a fishing pole in hand"
L.SHOW_MODE_ALWAYS = "Always"
L.SHOW_MODE_NEVER = "Never"
L.SCOPE = "Place"
L.SCOPE_MODE_AREA = "The subzone"
L.SCOPE_MODE_ZONE = "The whole zone"
L.VIEW = "Count the catches of"
L.VIEW_MODE_SESSION = "This fishing session"
L.VIEW_MODE_CHAR = "This character"
L.VIEW_MODE_ACCOUNT = "Every character"
L.VIEW_MODE_GUILD = "Every character and the guild"
L.ROWS = "Bars"
L.EDIT_MODE_HINT = "Move the window, and set its size and opacity, in the game's Edit Mode (Esc > Edit Mode). Its dialog there has the Text settings below too."
-- Settings window: the item tooltip's box.
-- Settings window: the box for OAP Debug (a debug window addon; its name stays as it is).
L.DEBUG = "OAP Debug"
L.DEBUG_LEVEL = "What goes to OAP Debug"
L.DEBUG_DESC = "Log lines and counts for OAP Debug's window (/oapd): loot events, catches, sessions, the guild."
L.DEBUG_MISSING = "OAP Debug is not installed, so nothing is sent."
L.DEBUG_ERRORS = "Errors only"
L.DEBUG_NORMAL = "Normal"
L.DEBUG_METRICS = "Normal and counts"
L.DEBUG_DETAILED = "Detailed (every loot event)"
-- Settings window: the guild box.
L.GUILD = "Guild"
L.SHARE = "Share catches with the guild"
L.SHARE_DESC = "Guildmates with this addon swap their counts (no names of fish or places, only numbers), now and then and when you put the pole away. The Guild button in the window then counts theirs too, and item tooltips list their places."
L.FORGET_GUILD = "Forget the guild's catches"
L.FORGET_GUILD_CONFIRM = "Forget every guildmate's catches? Yours stay."
L.TOOLTIP = "Item tooltip"
L.TOOLTIP_ENABLE = "Show where an item was caught"
L.TOOLTIP_PLACES = "Places listed"
-- Settings window: the catch log's box.
L.LOG = "Catch log"
L.CLEAR = "Clear the log"
L.CLEAR_DESC = "Forget every character's catches and sessions."
L.CLEAR_CONFIRM = "Clear every character's catches and sessions? This cannot be undone."
L.LOG_CLEARED = "Catch log cleared."

-- stylua: ignore end
