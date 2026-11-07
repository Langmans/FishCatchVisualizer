local addonName, ns = ...

-- The addon object, its fixed value sets and its saved data. The addon object is the namespace
-- the client hands every file (`Addon`), and other addons reach it through AceAddon. Every name the
-- game and other addons see is made from the folder's name, NAME (README > Renaming).

---@type Addon
local Addon = LibStub("AceAddon-3.0"):NewAddon(ns, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
Addon.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- The folder's name; the slash command is NAME in lower case, plus SLASH_ALIAS.
Addon.NAME = addonName
Addon.SLASH_ALIAS = "fcv"

---A global name of the addon's own (a frame's, the saved variables'), NAME first.
---@param suffix string
---@return string
function Addon.Global(suffix)
    return addonName .. suffix
end

---A string enum whose keys are its values: { "pole", "always" } gives { pole = "pole", ... }.
---@param values string[]
---@return table<string, string>
local function SelfKeyed(values)
    local enum = {}
    for _, value in ipairs(values) do
        enum[value] = value
    end
    return enum
end

-- When the catch window shows: with a fishing pole in hand, always, or never.
Addon.showModes = SelfKeyed({ "pole", "always", "never" })
-- What the window covers: the subzone the player stands in, or the whole zone.
Addon.scopes = SelfKeyed({ "area", "zone" })
-- Whose catches the window counts: this fishing session's, this character's, every character's,
-- and the guildmates' too.
Addon.views = SelfKeyed({ "session", "char", "account", "guild" })
-- The views in the order the buttons and lists show them.
Addon.VIEW_ORDER = { "session", "char", "account", "guild" }
-- Public messages (AceEvent SendMessage), "<NAME>_CATCH" and so on. catch: itemID, quantity, mapID,
-- area key. newHere (an item's first catch at a place, over the account): itemID, mapID, area key.
Addon.messages = { catch = addonName:upper() .. "_CATCH", newHere = addonName:upper() .. "_NEW_HERE" }

-- The saved data: the settings per profile, the catches account-wide (see annotations\Addon.lua
-- for the shapes).
local DEFAULTS = {
    profile = {
        show = Addon.showModes.pole,
        scope = Addon.scopes.area,
        view = Addon.views.session,
        rows = 8,
        tooltip = true,
        tooltipPlaces = 5,
        -- Swap counts with guildmates who have the addon (Core\Share.lua).
        share = true,
        -- The windows' appearance (Core\Appearance.lua). font and barTexture have no default:
        -- LibSharedMedia's defaults then.
        fontSize = 12,
        outline = "none",
        slug = false,
        shadow = true,
        shadowX = 1,
        shadowY = -1,
        shadowColor = { r = 0, g = 0, b = 0, a = 1 },
        titleColor = { r = 1, g = 0.82, b = 0 },
        textColor = { r = 1, g = 1, b = 1 },
        qualityColors = true,
        -- How much goes to OAP Debug when it is installed (Core\Debug.lua).
        oapDebug = "metrics",
        -- Per Edit Mode layout, per window: where it sits and its look (Core\Window.lua).
        layouts = {},
    },
    global = { chars = {}, sessions = {}, items = {}, times = {}, records = { stacks = {} }, guild = {} },
}
Addon.DEFAULTS = DEFAULTS

---Whether the game hands over a value the addon may read: not nil and not a secret value.
---@param value GameValue
---@return boolean
function Addon.Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---A share from 0 to 1 as a whole percentage; a share above 0 that would round to 0 is "<1%".
---@param share number
---@return string
function Addon.Percent(share)
    if share > 0 and share < 0.005 then return "<1%" end
    return ("%d%%"):format(math.floor(share * 100 + 0.5))
end

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(Addon.Global("DB"), DEFAULTS, true) --[[@as AddonDB]]
    self:ApplyDebugLevel()
    self:SetupCommands()
    self:SetupOptions()
    self:SetupTooltip()
    self:SetupEditMode()
    self:SetupAppearance()
    self:SetupShare()
end

function Addon:OnEnable()
    self:RegisterEvent("LOOT_READY", "OnLoot")
    self:RegisterEvent("LOOT_OPENED", "OnLoot")
    self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFishing")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "UpdateFishing")
    self:RegisterEvent("ZONE_CHANGED", "UpdateCatchWindow")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateCatchWindow")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateCatchWindow")
    self:RegisterMessage(self.messages.catch, "UpdateCatchWindow")
end
