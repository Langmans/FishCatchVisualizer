local _, ns = ...

-- The windows' text: a font from LibSharedMedia (so ElvUI's and SharedMedia's fonts are there),
-- a size, an outline, Slug rendering and a shadow. One set per profile, changed in the options or
-- in any window's Edit Mode dialog; both read and write the same profile fields.

---@type Addon
local Addon = ns
local L = Addon.L
---@type LibSharedMedia-3.0
local LSM = LibStub("LibSharedMedia-3.0")
---@type LibEditMode
local LEM = LibStub("LibEditMode")

-- The outline choices, each with its SetFont flag; Slug is a flag of its own, added to any of them.
Addon.outlines = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }
Addon.OUTLINE_ORDER = { "none", "thin", "thick" }
local SLUG = "SLUG"
Addon.MIN_FONT_SIZE, Addon.MAX_FONT_SIZE = 8, 24

---The profile's font name, or LibSharedMedia's default.
---@return string
local function FontName()
    -- LibSharedMedia always has a default font.
    return Addon.db.profile.font or LSM:GetDefault("font") --[[@as string]]
end

---The text the profile asks for: the font's file, the size, SetFont's flags and the shadow.
---@return string path
---@return number size
---@return string flags "OUTLINE, SLUG" and the like
---@return boolean shadow
function Addon:TextLook()
    local profile = self.db.profile
    local flags = self.outlines[profile.outline] or ""
    if profile.slug then flags = flags == "" and SLUG or (flags .. ", " .. SLUG) end
    -- An unknown name gives the default font's file.
    local path = LSM:Fetch("font", FontName()) --[[@as string]]
    return path, profile.fontSize, flags, profile.shadow
end

---Gives every window the profile's text.
function Addon:ApplyText()
    local path, size, flags, shadow = self:TextLook()
    for _, window in ipairs(self.windows) do
        window:ApplyFont(path, size, flags, shadow)
    end
end

---Sets one text field of the profile and shows it.
---@param key "font"|"fontSize"|"outline"|"slug"|"shadow"
---@param value string|number|boolean
function Addon:SetTextSetting(key, value)
    self.db.profile[key] = value
    self:ApplyText()
end

---Every font LibSharedMedia knows, as an Edit Mode dropdown lists them.
---@return { text: string, value: string }[]
local function FontValues()
    local values = {}
    for _, name in ipairs(LSM:List("font")) do
        values[#values + 1] = { text = name, value = name }
    end
    return values
end

-- The outline choices as an Edit Mode dropdown lists them, built once.
---@type { text: string, value: string }[]
local OUTLINE_VALUES = {}
for i, key in ipairs(Addon.OUTLINE_ORDER) do
    OUTLINE_VALUES[i] = { text = L["OUTLINE_" .. key:upper()], value = key }
end

---An Edit Mode setting for a profile text field. The layout plays no part: text is per profile.
---@param kind number a LibEditMode.SettingType value
---@param name string
---@param key "font"|"fontSize"|"outline"|"slug"|"shadow"
---@param extra table? the kind's own fields (values, minValue, ...)
---@return LibEditModeSetting
local function Setting(kind, name, key, extra)
    ---@type table<string, GameValue>
    local profileDefaults = Addon.DEFAULTS.profile
    local setting = extra or {}
    setting.kind, setting.name = kind, name
    setting.default = key == "font" and LSM:GetDefault("font") or profileDefaults[key]
    setting.get = function()
        return key == "font" and FontName() or Addon.db.profile[key]
    end
    ---@param _ string the layout
    ---@param value string|number|boolean
    setting.set = function(_, value)
        Addon:SetTextSetting(key, value)
    end
    return setting --[[@as LibEditModeSetting]]
end

---The text settings for a window's Edit Mode dialog, new tables for each window.
---@return LibEditModeSetting[]
function Addon.TextSettings()
    local types = LEM.SettingType
    return {
        Setting(types.Dropdown, L.FONT, "font", { values = FontValues }),
        Setting(types.Slider, L.FONT_SIZE, "fontSize", {
            minValue = Addon.MIN_FONT_SIZE,
            maxValue = Addon.MAX_FONT_SIZE,
            valueStep = 1,
        }),
        Setting(types.Dropdown, L.OUTLINE, "outline", { values = OUTLINE_VALUES }),
        Setting(types.Checkbox, L.SLUG, "slug"),
        Setting(types.Checkbox, L.SHADOW, "shadow"),
    }
end

---Applies the text once the saved data exists, and again whenever an addon shares a font: the
---profile's font may come from an addon that loads later.
function Addon:SetupText()
    self:ApplyText()
    ---@param _ string the event
    ---@param mediaType string
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
        if mediaType == "font" then self:ApplyText() end
    end)
end
