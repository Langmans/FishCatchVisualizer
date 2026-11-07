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

---A setting bound to the profile field of its own key; a change refreshes the window, or calls
---`apply` (the name of an Addon method).
---@param option table an AceConfig option without get and set
---@param apply string?
---@return table
local function Setting(option, apply)
    ---@param info table AceConfig's info; its last entry is the option's key
    ---@return GameValue
    option.get = function(info)
        return Addon.db.profile[info[#info]] --[[@as GameValue]]
    end
    ---@param info table
    ---@param value GameValue
    option.set = function(info, value)
        Addon.db.profile[info[#info]] = value
        Addon[apply or "UpdateCatchWindow"](Addon)
    end
    return option
end

---A colour picker for a profile colour.
---@param name string
---@param key "titleColor"|"textColor"|"shadowColor"
---@param order number
---@param hasAlpha boolean?
---@return table
local function ColorOption(name, key, order, hasAlpha)
    return {
        type = "color",
        name = name,
        order = order,
        hasAlpha = hasAlpha,
        ---@return number r, number g, number b, number? a
        get = function()
            ---@type AddonColor
            local color = Addon.db.profile[key]
            return color.r, color.g, color.b, color.a
        end,
        ---@param _ table AceConfig's info
        ---@param r number
        ---@param g number
        ---@param b number
        ---@param a number?
        set = function(_, r, g, b, a)
            Addon:SetTextColor(key, r, g, b, hasAlpha and a or nil)
        end,
    }
end

---A slider for one of the shadow's offsets; its box takes a typed number to a tenth.
---@param name string
---@param order number
---@return table
local function OffsetOption(name, order)
    return Setting({
        type = "range",
        name = name,
        order = order,
        min = -Addon.MAX_SHADOW_OFFSET,
        max = Addon.MAX_SHADOW_OFFSET,
        step = 0.1,
        bigStep = 0.5,
    }, "TextChanged")
end

---The Text box: the same profile fields as the windows' Edit Mode dialogs.
---@return table
local function TextOptions()
    local font = Setting({
        type = "select",
        name = L.FONT,
        order = 1,
        values = function()
            local values = {}
            for _, name in ipairs(LibStub("LibSharedMedia-3.0"):List("font")) do
                values[name] = name
            end
            return values
        end,
    }, "TextChanged")
    -- No saved font is LibSharedMedia's default, which the list shows chosen.
    font.get = function()
        return Addon.db.profile.font or LibStub("LibSharedMedia-3.0"):GetDefault("font")
    end
    return {
        type = "group",
        inline = true,
        name = L.TEXT,
        order = 10,
        args = {
            font = font,
            fontSize = Setting({
                type = "range",
                name = L.FONT_SIZE,
                order = 2,
                min = Addon.MIN_FONT_SIZE,
                max = Addon.MAX_FONT_SIZE,
                step = 1,
            }, "TextChanged"),
            outline = Setting({
                type = "select",
                name = L.OUTLINE,
                order = 3,
                values = Choices("OUTLINE", Addon.OUTLINE_ORDER),
                sorting = Addon.OUTLINE_ORDER,
            }, "TextChanged"),
            slug = Setting({ type = "toggle", name = L.SLUG, desc = L.SLUG_DESC, order = 4 }, "TextChanged"),
            titleColor = ColorOption(L.TITLE_COLOR, "titleColor", 5),
            textColor = ColorOption(L.TEXT_COLOR, "textColor", 6),
            qualityColors = Setting({
                type = "toggle",
                name = L.QUALITY_COLORS,
                desc = L.QUALITY_COLORS_DESC,
                order = 7,
            }, "TextChanged"),
            shadow = Setting({ type = "toggle", name = L.SHADOW, order = 8 }, "TextChanged"),
            shadowColor = ColorOption(L.SHADOW_COLOR, "shadowColor", 9, true),
            shadowX = OffsetOption(L.SHADOW_X, 10),
            shadowY = OffsetOption(L.SHADOW_Y, 11),
        },
    }
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
                            text = TextOptions(),
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
                    -- Only in a copy straight from the repository (Core\Dev.lua).
                    dev = Addon.DevOptions and Addon:DevOptions() or nil,
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
