local addonName, ns = ...

-- The options, in the game's own AddOns settings and in a window of their own (`options` of the
-- slash command): the general page, then Profiles. Position, size and opacity of the windows are
-- not here: those are in Blizzard's Edit Mode (Core\Window.lua).

---@type Addon
local Addon = ns
local L = Addon.L

-- The entries of AceDBOptions' own Profiles page. AceDBOptions hands every addon the same args
-- table, and other addons write into it, so only these are copied (as BattleCry does).
local PROFILE_OPTIONS = {
    "desc",
    "descreset",
    "reset",
    "current",
    "choosedesc",
    "new",
    "choose",
    "copydesc",
    "copyfrom",
    "deldesc",
    "delete",
}

-- The options' own window: the size it opens at and the least it can be dragged to. AceGUI's
-- frames are shared between addons, so its own least size comes back when the window closes.
local WINDOW_WIDTH, WINDOW_HEIGHT = 560, 520
local MIN_WIDTH, MIN_HEIGHT = 460, 400
local ACEGUI_MIN_WIDTH, ACEGUI_MIN_HEIGHT = 400, 200

-- The AceGUI frames the window has been on, each hooked once.
---@type table<Frame, true>
local hookedFrames = {}

---Gives a frame the window closed on back AceGUI's own least size.
---@param frame Frame
local function ResetBounds(frame)
    frame:SetResizeBounds(ACEGUI_MIN_WIDTH, ACEGUI_MIN_HEIGHT)
end

---A setting bound to the profile field of its own key; a change refreshes the window.
---@param option table an AceConfig option without get and set
---@return table
local function Setting(option)
    ---@param info table AceConfig's info; its last entry is the option's key
    ---@return GameValue
    option.get = function(info)
        return Addon.db.profile[info[#info]] --[[@as GameValue]]
    end
    ---@param info table
    ---@param value GameValue
    option.set = function(info, value)
        Addon.db.profile[info[#info]] = value
        Addon:UpdateCatchWindow()
    end
    return option
end

---The values of a choice, by their L.<PREFIX>_<VALUE> names.
---@param prefix string
---@param values string[]
---@return table<string, string>
local function Choices(prefix, values)
    local out = {}
    for _, value in ipairs(values) do
        out[value] = L[prefix .. "_" .. value:upper()]
    end
    return out
end

---The Profiles page: AceDBOptions' group with a copy of only its own entries.
---@return table
local function ProfileOptions()
    local shared = LibStub("AceDBOptions-3.0"):GetOptionsTable(Addon.db)
    -- GetOptionsTable always sets args.
    local sharedArgs = shared.args --[[@as table<string, AceConfig.OptionsTable>]]
    ---@type table<string, AceConfig.OptionsTable>
    local args = {}
    for _, key in ipairs(PROFILE_OPTIONS) do
        args[key] = sharedArgs[key]
    end
    return { type = "group", name = shared.name, desc = shared.desc, handler = shared.handler, order = 100, args = args }
end

---@return table
function Addon:GetOptionsTable()
    return {
        type = "group",
        name = addonName,
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = L.GENERAL,
                order = 1,
                args = {
                    desc = { type = "description", name = L.GENERAL_DESC, order = 1 },
                    window = {
                        type = "group",
                        inline = true,
                        name = L.WINDOW,
                        order = 2,
                        args = {
                            show = Setting({
                                type = "select",
                                name = L.SHOW,
                                order = 1,
                                values = Choices("SHOW_MODE", { "pole", "always", "never" }),
                            }),
                            scope = Setting({
                                type = "select",
                                name = L.SCOPE,
                                order = 2,
                                values = Choices("SCOPE_MODE", { "area", "zone" }),
                            }),
                            view = Setting({
                                type = "select",
                                name = L.VIEW,
                                order = 3,
                                values = Choices("VIEW_MODE", { "session", "char", "account" }),
                            }),
                            rows = Setting({ type = "range", name = L.ROWS, order = 4, min = 3, max = 20, step = 1 }),
                            editMode = { type = "description", name = L.EDIT_MODE_HINT, order = 5 },
                        },
                    },
                    tooltip = {
                        type = "group",
                        inline = true,
                        name = L.TOOLTIP,
                        order = 3,
                        args = {
                            tooltip = Setting({ type = "toggle", name = L.TOOLTIP_ENABLE, order = 1, width = "double" }),
                            tooltipPlaces = Setting({
                                type = "range",
                                name = L.TOOLTIP_PLACES,
                                order = 2,
                                min = 1,
                                max = 10,
                                step = 1,
                            }),
                        },
                    },
                    log = {
                        type = "group",
                        inline = true,
                        name = L.LOG,
                        order = 4,
                        args = {
                            clear = {
                                type = "execute",
                                name = L.CLEAR,
                                desc = L.CLEAR_DESC,
                                confirm = true,
                                confirmText = L.CLEAR_CONFIRM,
                                func = function()
                                    Addon:ClearLog()
                                    Addon:Print(L.LOG_CLEARED)
                                    Addon:UpdateCatchWindow()
                                end,
                            },
                        },
                    },
                },
            },
            profiles = ProfileOptions(),
        },
    }
end

function Addon:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, function()
        return self:GetOptionsTable()
    end)
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:SetDefaultSize(addonName, WINDOW_WIDTH, WINDOW_HEIGHT)
    dialog:AddToBlizOptions(addonName, addonName, nil, "general")
    dialog:AddToBlizOptions(addonName, self:GetOptionsTable().args.profiles.name, addonName, "profiles")
end

---Opens the options in their own window, which can be moved and resized, or closes it when open.
function Addon:OpenOptions()
    local dialog = LibStub("AceConfigDialog-3.0")
    if dialog.OpenFrames[addonName] then
        dialog:Close(addonName)
        return
    end
    dialog:Open(addonName)
    local frame = dialog.OpenFrames[addonName].frame --[[@as Frame]]
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
    if not hookedFrames[frame] then
        hookedFrames[frame] = true
        frame:HookScript("OnHide", ResetBounds)
    end
end
