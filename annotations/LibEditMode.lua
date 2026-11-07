---@meta
-- LibEditMode, as far as FishCatchVisualizer calls it (Core\Window.lua). From the comments in
-- LibEditMode.lua at tag 19; the library ships no types of its own.

---@class LibEditModeSetting
---@field kind number a LibEditMode.SettingType value
---@field name string
---@field default any
---@field get fun(layoutName: string): any
---@field set fun(layoutName: string, value: any, fromReset: boolean?)
---@field minValue? number
---@field maxValue? number
---@field valueStep? number

---@class LibEditMode
---@field SettingType { Dropdown: number, Checkbox: number, Slider: number }
local LibEditMode = {}

---Hands a frame to Edit Mode. `callback` runs after the player moved it, with the layout's name
---and the new point and offsets from UIParent.
---@param frame Frame
---@param callback fun(frame: Frame, layoutName: string, point: string, x: number, y: number)
---@param default { point: string, x: number, y: number }
---@param name string? the name Edit Mode shows
function LibEditMode:AddFrame(frame, callback, default, name) end

---The settings in the frame's Edit Mode dialog.
---@param frame Frame
---@param settings LibEditModeSetting[]
function LibEditMode:AddFrameSettings(frame, settings) end

---"layout": a layout was loaded (its name); "enter"/"exit": Edit Mode opened or closed.
---@param event "layout"|"enter"|"exit"
---@param callback fun(layoutName: string?)
function LibEditMode:RegisterCallback(event, callback) end

---The layout in use, nil until the game has loaded the layouts.
---@return string?
function LibEditMode:GetActiveLayoutName() end
