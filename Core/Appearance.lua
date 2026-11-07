local _, ns = ...

-- The windows' appearance: a font from LibSharedMedia (so ElvUI's and SharedMedia's fonts are
-- there), a size, an outline, Slug rendering, a shadow (colour and x/y offset), the title's and the
-- other text's colours, items in their quality's colour, and the bars. The bars take what fits a
-- list of catches from ElvUI's unit frame health bar: a texture (LibSharedMedia's statusbars), a
-- colour or a colour by share (ElvUI's Health By Value), a background in its own colour or the
-- bar's at the multiplier's opacity, transparent, inverted, reverse fill and smooth. One set per
-- profile, changed in the options or in any window's Edit Mode dialog; both read and write the
-- same profile fields.

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

-- Transparent bars are flat, as ElvUI's.
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
-- How smooth bars move; nil on a client whose status bars cannot glide.
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
-- The multiplier slider's step in Edit Mode.
local MULTIPLIER_STEP = 0.05

-- The profile fields that name LibSharedMedia media, and the media type of each.
local MEDIA_TYPES = { font = "font", barTexture = "statusbar" }

---The profile's name for a medium (font, barTexture), or LibSharedMedia's default.
---@param key "font"|"barTexture"
---@return string
local function MediaName(key)
    -- LibSharedMedia always has a default font and statusbar.
    return Addon.db.profile[key] or LSM:GetDefault(MEDIA_TYPES[key]) --[[@as string]]
end

-- What the windows draw with, filled by Appearance and handed to every window.
---@type AddonAppearance
local appearance = {}

---The appearance the profile asks for, in the one shared table.
---@return AddonAppearance
function Addon:Appearance()
    local profile = self.db.profile
    local flags = self.outlines[profile.outline] or ""
    if profile.slug then flags = flags == "" and SLUG or (flags .. ", " .. SLUG) end
    -- An unknown name gives the default's file.
    appearance.path = LSM:Fetch("font", MediaName("font")) --[[@as string]]
    appearance.size, appearance.flags = profile.fontSize, flags
    appearance.shadowX = profile.shadow and profile.shadowX or 0
    appearance.shadowY = profile.shadow and profile.shadowY or 0
    appearance.shadowColor = profile.shadowColor
    appearance.titleColor, appearance.textColor = profile.titleColor, profile.textColor
    local transparent, multiplier = profile.barTransparent, profile.barMultiplier
    appearance.barTexture = transparent and FLAT_TEXTURE or LSM:Fetch("statusbar", MediaName("barTexture")) --[[@as string]]
    appearance.barColor = profile.barColor
    appearance.barBackground = profile.barCustomBackdrop and profile.barBackground or nil
    -- As ElvUI: a transparent bar at twice the multiplier, its background at half.
    appearance.barAlpha = transparent and math.min(multiplier * 2, 1) or 1
    appearance.backgroundAlpha = transparent and multiplier / 2 or multiplier
    appearance.barByShare, appearance.barTransparent = profile.barByShare, transparent
    appearance.barInvert, appearance.barReverseFill = profile.barInvert, profile.barReverseFill
    appearance.barInterpolation = profile.barSmooth and SMOOTH or nil
    return appearance
end

---Gives every window the profile's appearance.
function Addon:ApplyAppearance()
    local current = self:Appearance()
    for _, window in ipairs(self.windows) do
        window:ApplyAppearance(current)
    end
end

---Shows a changed setting: the windows, and the bars, whose item names carry the quality colour.
function Addon:AppearanceChanged()
    self:ApplyAppearance()
    self:UpdateCatchWindow()
end

---Sets one appearance field of the profile and shows it.
---@param key string
---@param value string|number|boolean
function Addon:SetAppearanceSetting(key, value)
    self.db.profile[key] = value
    self:AppearanceChanged()
end

---Sets a colour field of the profile and shows it; `a` only for a colour with opacity.
---@param key AddonColorKey
---@param r number
---@param g number
---@param b number
---@param a number?
function Addon:SetAppearanceColor(key, r, g, b, a)
    local color = self.db.profile[key]
    color.r, color.g, color.b = r, g, b
    if a then color.a = a end
    self:AppearanceChanged()
end

---Every medium of a type LibSharedMedia knows, as an Edit Mode dropdown lists them.
---@param mediaType "font"|"statusbar"
---@return fun(): { text: string, value: string }[]
local function MediaValues(mediaType)
    return function()
        local values = {}
        for _, name in ipairs(LSM:List(mediaType)) do
            values[#values + 1] = { text = name, value = name }
        end
        return values
    end
end

-- The outline choices as an Edit Mode dropdown lists them, built once.
---@type { text: string, value: string }[]
local OUTLINE_VALUES = {}
for i, key in ipairs(Addon.OUTLINE_ORDER) do
    OUTLINE_VALUES[i] = { text = L["OUTLINE_" .. key:upper()], value = key }
end

---An Edit Mode setting for a profile appearance field. The layout plays no part: the appearance is
---per profile.
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
    local mediaType = MEDIA_TYPES[key]
    setting.default = mediaType and LSM:GetDefault(mediaType) or profileDefaults[key]
    ---@return GameValue
    setting.get = function()
        if mediaType then return MediaName(key) end
        return Addon.db.profile[key] --[[@as GameValue]]
    end
    ---@param _ string the layout
    ---@param value string|number|boolean
    setting.set = function(_, value)
        Addon:SetAppearanceSetting(key, value)
    end
    return setting --[[@as LibEditModeSetting]]
end

---An Edit Mode colour picker for a profile colour; LibEditMode hands colours over as ColorMixins.
---@param name string
---@param key AddonColorKey
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
            Addon:SetAppearanceColor(key, r, g, b, hasOpacity and a or nil)
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

---The appearance settings for a window's Edit Mode dialog, new tables for each window.
---@return LibEditModeSetting[]
function Addon.AppearanceSettings()
    local types = LEM.SettingType
    return {
        Setting(types.Dropdown, L.FONT, "font", { values = MediaValues("font") }),
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
        Setting(types.Dropdown, L.BAR_TEXTURE, "barTexture", { values = MediaValues("statusbar") }),
        ColorSetting(L.BAR_COLOR, "barColor"),
        Setting(types.Checkbox, L.BAR_BY_SHARE, "barByShare"),
        Setting(types.Checkbox, L.BAR_CUSTOM_BACKDROP, "barCustomBackdrop"),
        ColorSetting(L.BAR_BACKGROUND, "barBackground"),
        Setting(types.Slider, L.BAR_MULTIPLIER, "barMultiplier", {
            minValue = 0,
            maxValue = 1,
            valueStep = MULTIPLIER_STEP,
        }),
        Setting(types.Checkbox, L.BAR_TRANSPARENT, "barTransparent"),
        Setting(types.Checkbox, L.BAR_INVERT, "barInvert"),
        Setting(types.Checkbox, L.BAR_REVERSE_FILL, "barReverseFill"),
        Setting(types.Checkbox, L.BAR_SMOOTH, "barSmooth"),
    }
end

---Applies the look once the saved data exists, and again whenever an addon shares a font or a
---statusbar texture: the profile's may come from an addon that loads later.
function Addon:SetupAppearance()
    self:ApplyAppearance()
    ---@param _ string the event
    ---@param mediaType string
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
        if mediaType == "font" or mediaType == "statusbar" then self:ApplyAppearance() end
    end)
end
