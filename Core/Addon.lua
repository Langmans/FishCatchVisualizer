local addonName, ns = ...

-- The addon object, its fixed value sets and its saved data.
--
-- The addon object (FCV) is public: other addons reach it through
-- LibStub("AceAddon-3.0"):GetAddon("FishCatchVisualizer") and hear about catches through
-- FCV.messages.catch. `ns`, the table the client hands only to this addon's files, holds what only
-- they share (the place helpers, the window); nothing on FCV leads back to it.

---@type FishCatchVisualizer
local FCV = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.FCV = FCV
FCV.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

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
FCV.showModes = SelfKeyed({ "pole", "always", "never" })
-- What the window covers: the subzone the player stands in, or the whole zone.
FCV.scopes = SelfKeyed({ "area", "zone" })
-- Whose catches the window counts: this fishing session's, this character's, every character's.
FCV.views = SelfKeyed({ "session", "char", "account" })
-- Public messages (AceEvent SendMessage). catch: itemID, quantity, mapID, area key.
FCV.messages = { catch = "FISHCATCHVISUALIZER_CATCH" }

-- The saved data: the settings per profile, the catches account-wide (see
-- annotations\FishCatchVisualizer.lua for the shapes).
local DEFAULTS = {
    profile = {
        show = FCV.showModes.pole,
        scope = FCV.scopes.area,
        view = FCV.views.session,
        rows = 8,
        tooltip = true,
        tooltipPlaces = 5,
        -- Per Edit Mode layout, per window: where it sits and its look (Core\Window.lua).
        layouts = {},
    },
    global = { chars = {}, sessions = {}, items = {} },
}

---Whether the game hands over a value the addon may read: not nil and not a secret value.
---@param value GameValue
---@return boolean
function ns.Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---A share from 0 to 1 as a whole percentage; a share above 0 that would round to 0 is "<1%".
---@param share number
---@return string
function ns.Percent(share)
    if share > 0 and share < 0.005 then return "<1%" end
    return ("%d%%"):format(math.floor(share * 100 + 0.5))
end

function FCV:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("FishCatchVisualizerDB", DEFAULTS, true) --[[@as FishCatchVisualizerDB]]
    self:SetupCommands()
    self:SetupOptions()
    self:SetupTooltip()
    self:SetupEditMode()
end

function FCV:OnEnable()
    self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFishing")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "UpdateFishing")
    self:RegisterEvent("ZONE_CHANGED", "UpdateCatchWindow")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateCatchWindow")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateCatchWindow")
    self:RegisterMessage(self.messages.catch, "UpdateCatchWindow")
end
