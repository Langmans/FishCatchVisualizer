local _, ns = ...

-- A bar list window, the catch window's and later the Wowhead window's: a title, a subtitle, a
-- row of buttons, then one status bar per row with a label on the left and numbers on the right.
-- It takes no mouse itself, so clicks go through to the world; only its buttons do.
--
-- Position, scale and opacity live in Blizzard's Edit Mode through LibEditMode, per Edit Mode
-- layout: profile.layouts[layout name][window key] = { point, x, y, scale, alpha }, every field
-- falling back to DEFAULTS. The background is see-through by default, as Fishbringer's. The text
-- settings in the same dialog are the profile's (Core\Text.lua).

---@type Addon
local Addon = ns
local L = Addon.L
---@type LibEditMode
local LEM = LibStub("LibEditMode")

local WIDTH, PAD = 260, 8
local ROW_HEIGHT, ROW_GAP = 16, 2
-- From the top edge to the first bar: title, subtitle and the buttons.
local HEADER = 52
local NOTE_HEIGHT = 14
-- A button is as wide as its label plus this, so a bigger font never cuts a label off.
local BUTTON_PAD, BUTTON_HEIGHT = 8, 14
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
-- A window's place and look in a layout it has not been touched in.
---@type AddonWindowLook
local DEFAULTS = { point = "RIGHT", x = -60, y = 120, scale = 1, alpha = 0 }
-- How much larger than the other text the title is.
local TITLE_LARGER = 2

---Every window made, so a new Edit Mode layout and a text change reach them all.
---@type AddonWindow[]
local windows = {}
Addon.windows = windows

---@class AddonWindow
local Window = {}
Window.__index = Window

---A font string on the window, hidden until it has something to say.
---@param frame Frame
---@param font string
---@return FontString
local function Text(frame, font)
    local text = frame:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    return text
end

---This window's saved fields in a layout, made when missing.
---@param layoutName string
---@return AddonWindowLayout
function Window:Saved(layoutName)
    local layouts = Addon.db.profile.layouts
    local layout = layouts[layoutName]
    if not layout then
        layout = {}
        layouts[layoutName] = layout
    end
    local saved = layout[self.key]
    if not saved then
        saved = {} --[[@as AddonWindowLayout]]
        layout[self.key] = saved
    end
    return saved
end

---Where the layout has the window and its look, each field the saved value or the default.
---Before the game has loaded a layout, the defaults.
---@param layoutName string?
---@return string point
---@return number x
---@return number y
---@return number scale
---@return number alpha
function Window:Look(layoutName)
    local layout = layoutName and Addon.db.profile.layouts[layoutName]
    local saved = layout and layout[self.key] or DEFAULTS
    return saved.point or DEFAULTS.point,
        saved.x or DEFAULTS.x,
        saved.y or DEFAULTS.y,
        saved.scale or DEFAULTS.scale,
        saved.alpha or DEFAULTS.alpha
end

---Puts the window where the layout has it, at its scale and opacity.
---@param layoutName string?
function Window:ApplyLayout(layoutName)
    self.layoutName = layoutName
    local frame = self.frame
    local point, x, y, scale, alpha = self:Look(layoutName)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
    frame:SetScale(scale)
    frame:SetBackdropColor(0, 0, 0, alpha)
    frame:SetBackdropBorderColor(0, 0, 0, alpha)
end

---Saves where the player moved the window in a layout.
---@param layoutName string
---@param point string
---@param x number
---@param y number
function Window:SavePosition(layoutName, point, x, y)
    local saved = self:Saved(layoutName)
    saved.point, saved.x, saved.y = point, x, y
    if layoutName == self.layoutName then self:ApplyLayout(layoutName) end
end

---A slider of the window's Edit Mode dialog for its scale or opacity.
---@param name string
---@param field "scale"|"alpha"
---@param min number
---@param max number
---@return LibEditModeSetting
function Window:Slider(name, field, min, max)
    return {
        kind = LEM.SettingType.Slider,
        name = name,
        default = DEFAULTS[field],
        minValue = min,
        maxValue = max,
        valueStep = 0.05,
        ---@param layoutName string
        ---@return number
        get = function(layoutName)
            local _, _, _, scale, alpha = self:Look(layoutName)
            return field == "scale" and scale or alpha
        end,
        ---@param layoutName string
        ---@param value number
        set = function(layoutName, value)
            self:Saved(layoutName)[field] = value
            if layoutName == self.layoutName then self:ApplyLayout(layoutName) end
        end,
    }
end

---Gives a font string the window's text, `larger` points above its size, in the look's colour
---`colorKey` (none: the button labels, which Select colours). Before the first ApplyLook the
---template's font stays.
---@param text FontString
---@param larger number?
---@param colorKey "titleColor"|"textColor"|nil
function Window:StyleText(text, larger, colorKey)
    local look = self.look
    if not look then return end
    text:SetFont(look.path, look.size + (larger or 0), look.flags)
    text:SetShadowOffset(look.shadowX, look.shadowY)
    local shadow = look.shadowColor
    text:SetShadowColor(shadow.r, shadow.g, shadow.b, shadow.a)
    if not colorKey then return end
    local color = look[colorKey]
    text:SetTextColor(color.r, color.g, color.b)
end

---The text for every font string the window has, and for those it makes later.
---@param look AddonTextLook
function Window:ApplyLook(look)
    self.look = look
    self:StyleText(self.title, TITLE_LARGER, "titleColor")
    self:StyleText(self.subtitle, nil, "textColor")
    self:StyleText(self.empty, nil, "textColor")
    self:StyleText(self.more, nil, "textColor")
    for _, button in pairs(self.buttons) do
        self:StyleText(button.label)
        button:SetWidth(button.label:GetStringWidth() + BUTTON_PAD)
    end
    for _, row in ipairs(self.rows) do
        self:StyleText(row.left, nil, "textColor")
        self:StyleText(row.right, nil, "textColor")
    end
end

---Adds a button to the row under the subtitle, each next to the one before.
---@param key string
---@param label string
---@param onClick fun()
function Window:AddButton(key, label, onClick)
    local button = CreateFrame("Button", nil, self.frame)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetAllPoints()
    text:SetText(label)
    self:StyleText(text)
    button:SetSize(text:GetStringWidth() + BUTTON_PAD, BUTTON_HEIGHT)
    button.label = text
    button:SetScript("OnClick", onClick)
    local previous = self.buttons[self.lastButton]
    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    else
        button:SetPoint("TOPLEFT", self.subtitle, "BOTTOMLEFT", 0, -4)
    end
    self.buttons[key], self.lastButton = button, key
end

---Marks one button as the chosen one: gold, the others grey.
---@param key string
function Window:Select(key)
    for buttonKey, button in pairs(self.buttons) do
        local selected = buttonKey == key
        button.selected = selected
        if selected then
            button.label:SetTextColor(1, 0.82, 0)
        else
            button.label:SetTextColor(0.6, 0.6, 0.6)
        end
    end
end

---@param title string
---@param subtitle string
function Window:SetTitle(title, subtitle)
    self.title:SetText(title)
    self.subtitle:SetText(subtitle)
end

---Fills row i, made on first use: the bar at `value` (0 to 1) in the window's colour.
---@param i number
---@param left string
---@param right string
---@param value number
function Window:FillRow(i, left, right, value)
    local row = self.rows[i]
    if not row then
        local bar = CreateFrame("StatusBar", nil, self.frame)
        bar:SetStatusBarTexture(BAR_TEXTURE)
        bar:SetMinMaxValues(0, 1)
        bar:SetHeight(ROW_HEIGHT)
        bar:SetPoint("TOPLEFT", PAD, -(HEADER + (i - 1) * (ROW_HEIGHT + ROW_GAP)))
        bar:SetPoint("RIGHT", -PAD, 0)
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(1, 1, 1, 0.06)
        local leftText = Text(bar, "GameFontHighlightSmall")
        leftText:SetPoint("LEFT", 4, 0)
        local rightText = Text(bar, "GameFontHighlightSmall")
        rightText:SetPoint("RIGHT", -4, 0)
        rightText:SetJustifyH("RIGHT")
        leftText:SetPoint("RIGHT", rightText, "LEFT", -4, 0)
        self:StyleText(leftText, nil, "textColor")
        self:StyleText(rightText, nil, "textColor")
        row = { bar = bar, left = leftText, right = rightText }
        self.rows[i] = row
    end
    local color = self.color
    row.bar:SetStatusBarColor(color[1], color[2], color[3])
    row.bar:SetValue(value)
    row.left:SetText(left)
    row.right:SetText(right)
end

---Shows `note` in a font string at `y` under the window's top, or hides it without one.
---@param text FontString
---@param note string?
---@param y number
local function ShowNote(text, note, y)
    text:SetShown(note ~= nil)
    if not note then return end
    text:SetText(note)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", PAD, y)
end

---Shows the first `count` rows and hides the rest, then a note under them: `empty` when there
---is nothing, `more` when rows were left out. Sizes the window to fit.
---@param count number
---@param empty string?
---@param more string?
function Window:ShowRows(count, empty, more)
    for i, row in ipairs(self.rows) do
        row.bar:SetShown(i <= count)
    end
    local height = HEADER + count * (ROW_HEIGHT + ROW_GAP)
    ShowNote(self.empty, empty, -height)
    ShowNote(self.more, more, -height)
    local notes = (empty or more) and NOTE_HEIGHT or 0
    self.frame:SetHeight(height + notes + PAD)
end

---A new, hidden window. `key` names it in the saved layouts and, capitalised, its frame
---("<NAME>CatchesWindow"); `name` names it in Edit Mode; `color` is its bars' { r, g, b }.
---@param key string
---@param name string
---@param color number[]
---@return AddonWindow
function Addon.NewBarWindow(key, name, color)
    local frameName = Addon.Global(key:sub(1, 1):upper() .. key:sub(2) .. "Window")
    local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEADER + PAD)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(BACKDROP)
    frame:EnableMouse(false)
    frame:Hide()
    local window = setmetatable({ key = key, frame = frame, color = color, rows = {}, buttons = {} }, Window) --[[@as AddonWindow]]
    window.title = Text(frame, "GameFontNormal")
    window.title:SetPoint("TOPLEFT", PAD, -6)
    window.title:SetPoint("RIGHT", -PAD, 0)
    window.subtitle = Text(frame, "GameFontDisableSmall")
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -2)
    window.empty = Text(frame, "GameFontDisableSmall")
    window.empty:Hide()
    window.more = Text(frame, "GameFontDisableSmall")
    window.more:Hide()
    ---@param _ Frame the window's frame
    ---@param layoutName string
    ---@param point string
    ---@param x number
    ---@param y number
    local function OnMoved(_, layoutName, point, x, y)
        window:SavePosition(layoutName, point, x, y)
    end
    LEM:AddFrame(frame, OnMoved, { point = DEFAULTS.point, x = DEFAULTS.x, y = DEFAULTS.y }, name)
    local settings = { window:Slider(L.SCALE, "scale", 0.5, 2), window:Slider(L.OPACITY, "alpha", 0, 1) }
    for _, setting in ipairs(Addon.TextSettings()) do
        settings[#settings + 1] = setting
    end
    LEM:AddFrameSettings(frame, settings)
    windows[#windows + 1] = window
    return window
end

---Hooks the windows to Edit Mode: each layout loaded puts them in place, and while Edit Mode is
---open they show, so they can be moved. Called once the saved data exists.
function Addon:SetupEditMode()
    for _, window in ipairs(windows) do
        window:ApplyLayout(LEM:GetActiveLayoutName())
    end
    ---@param layoutName string?
    LEM:RegisterCallback("layout", function(layoutName)
        for _, window in ipairs(windows) do
            window:ApplyLayout(layoutName)
        end
    end)
    LEM:RegisterCallback("enter", function()
        self.editing = true
        self:UpdateCatchWindow()
    end)
    LEM:RegisterCallback("exit", function()
        self.editing = false
        self:UpdateCatchWindow()
    end)
end
