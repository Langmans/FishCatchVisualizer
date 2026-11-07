local _, ns = ...

-- The windows' text: a font from LibSharedMedia (so ElvUI's and SharedMedia's fonts are there),
-- a size, an outline, Slug rendering, a shadow (colour and x/y offset), the title's and the other
-- text's colours, and items in their quality's colour. One set per profile, changed in the options
-- or in any window's Edit Mode dialog; both read and write the same profile fields.

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
-- The shadow's offset either way, in pixels; SetShadowOffset takes fractions too.
Addon.MAX_SHADOW_OFFSET = 4
-- Edit Mode has sliders only, in half pixels; the options' slider also takes a typed number.
local EDIT_MODE_OFFSET_STEP = 0.5

---The profile's font name, or LibSharedMedia's default.
---@return string
local function FontName()
    -- LibSharedMedia always has a default font.
    return Addon.db.profile.font or LSM:GetDefault("font") --[[@as string]]
end

-- What the windows draw their text with, filled by TextLook and handed to every window.
---@type AddonTextLook
local look = {}

---The text the profile asks for, in the one shared look table.
---@return AddonTextLook
function Addon:TextLook()
    local profile = self.db.profile
    local flags = self.outlines[profile.outline] or ""
    if profile.slug then flags = flags == "" and SLUG or (flags .. ", " .. SLUG) end
    -- An unknown name gives the default font's file.
    look.path = LSM:Fetch("font", FontName()) --[[@as string]]
    look.size, look.flags = profile.fontSize, flags
    look.shadowX = profile.shadow and profile.shadowX or 0
    look.shadowY = profile.shadow and profile.shadowY or 0
    look.shadowColor, look.titleColor, look.textColor = profile.shadowColor, profile.titleColor, profile.textColor
    return look
end

---Gives every window the profile's text.
function Addon:ApplyText()
    local textLook = self:TextLook()
    for _, window in ipairs(self.windows) do
        window:ApplyLook(textLook)
    end
end

---Shows a changed text setting: the text, and the bars, whose item names carry the quality colour.
function Addon:TextChanged()
    self:ApplyText()
    self:UpdateCatchWindow()
end

---Sets one text field of the profile and shows it.
---@param key string
---@param value string|number|boolean
function Addon:SetTextSetting(key, value)
    self.db.profile[key] = value
    self:TextChanged()
end

---Sets a colour field of the profile and shows it; `a` only for a colour with opacity.
---@param key "titleColor"|"textColor"|"shadowColor"
---@param r number
---@param g number
---@param b number
---@param a number?
function Addon:SetTextColor(key, r, g, b, a)
    local color = self.db.profile[key]
    color.r, color.g, color.b = r, g, b
    if a then color.a = a end
    self:TextChanged()
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
---@param key string
---@param extra table? the kind's own fields (values, minValue, ...)
---@return LibEditModeSetting
local function Setting(kind, name, key, extra)
    ---@type table<string, GameValue>
    local profileDefaults = Addon.DEFAULTS.profile
    local setting = extra or {}
    setting.kind, setting.name = kind, name
    setting.default = key == "font" and LSM:GetDefault("font") or profileDefaults[key]
    ---@return GameValue
    setting.get = function()
        return key == "font" and FontName() or Addon.db.profile[key] --[[@as GameValue]]
    end
    ---@param _ string the layout
    ---@param value string|number|boolean
    setting.set = function(_, value)
        Addon:SetTextSetting(key, value)
    end
    return setting --[[@as LibEditModeSetting]]
end

---An Edit Mode colour picker for a profile colour; LibEditMode hands colours over as ColorMixins.
---@param name string
---@param key "titleColor"|"textColor"|"shadowColor"
---@param hasOpacity boolean?
---@return LibEditModeSetting
local function ColorSetting(name, key, hasOpacity)
    ---@type AddonColor
    local default = Addon.DEFAULTS.profile[key]
    return {
        kind = LEM.SettingType.ColorPicker,
        name = name,
        hasOpacity = hasOpacity,
        default = CreateColor(default.r, default.g, default.b, default.a),
        get = function()
            ---@type AddonColor
            local color = Addon.db.profile[key]
            return CreateColor(color.r, color.g, color.b, color.a)
        end,
        ---@param _ string the layout
        ---@param color ColorMixin
        set = function(_, color)
            local r, g, b, a = color:GetRGBA()
            Addon:SetTextColor(key, r, g, b, hasOpacity and a or nil)
        end,
    }
end

---A slider for one of the shadow's offsets.
---@param name string
---@param key "shadowX"|"shadowY"
---@return LibEditModeSetting
local function OffsetSetting(name, key)
    return Setting(LEM.SettingType.Slider, name, key, {
        minValue = -Addon.MAX_SHADOW_OFFSET,
        maxValue = Addon.MAX_SHADOW_OFFSET,
        valueStep = EDIT_MODE_OFFSET_STEP,
    })
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
        ColorSetting(L.TITLE_COLOR, "titleColor"),
        ColorSetting(L.TEXT_COLOR, "textColor"),
        Setting(types.Checkbox, L.QUALITY_COLORS, "qualityColors"),
        Setting(types.Checkbox, L.SHADOW, "shadow"),
        ColorSetting(L.SHADOW_COLOR, "shadowColor", true),
        OffsetSetting(L.SHADOW_X, "shadowX"),
        OffsetSetting(L.SHADOW_Y, "shadowY"),
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
