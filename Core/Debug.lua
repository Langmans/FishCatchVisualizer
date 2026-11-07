local _, ns = ...

-- The bridge to OAP Debug (an addon of its own, a debug window: log, inspector, metrics, Lua
-- errors; /oapd), the only file that talks to it, as in BattleCry. When it is installed, the addon
-- registers under its folder (so its Lua errors are filed under it) and sends log lines and counts.
-- How much goes is the "OAP Debug" level: errors only, normal, normal + metrics (the default),
-- detailed. Without OAP Debug nothing is sent.

---@type Addon
local Addon = ns

local ICON = "Interface\\Icons\\Trade_Fishing"
local ERRORS, NORMAL, METRICS, DETAILED = 1, 2, 3, 4
Addon.debugLevels = { errors = ERRORS, normal = NORMAL, metrics = METRICS, detailed = DETAILED }
Addon.DEBUG_LEVEL_ORDER = { "errors", "normal", "metrics", "detailed" }
-- What a log line of each kind needs.
local NEEDS = { error = ERRORS, warn = NORMAL, info = NORMAL, debug = DETAILED }

local level = METRICS
-- OAP Debug's table, found once when the settings load (OptionalDeps loads it first); nil without it.
---@type OAPDebugApi?
local api

---Finds OAP Debug and registers the addon with it, once.
local function Connect()
    if api then return end
    api = rawget(_G, "OAPDebug") --[[@as OAPDebugApi?]]
    if api then api.Register(Addon.NAME, { title = Addon.NAME, folder = Addon.NAME, icon = ICON }) end
end

---Whether OAP Debug is installed.
---@return boolean
function Addon.HasOAPDebug()
    return api ~= nil
end

---A log line: "error", "warn", "info" or "debug"; values fill {1}, {2}, ... (tables become links).
---@param kind "error"|"warn"|"info"|"debug"
---@param msg string
---@param ... any
function Addon:Log(kind, msg, ...)
    if api and level >= NEEDS[kind] then api.Log(self.NAME, msg, kind, ...) end
end

---Counts something that happens, from Normal + metrics.
---@param name string
function Addon:Count(name)
    if api and level >= METRICS then api.Count(self.NAME, name) end
end

---Takes the profile's level.
function Addon:ApplyDebugLevel()
    Connect()
    level = self.debugLevels[self.db.profile.oapDebug] or METRICS
end

---Sets the level ("errors", "normal", "metrics" or "detailed") in the profile, in effect at once.
---@param value string
function Addon:SetDebugLevel(value)
    self.db.profile.oapDebug = value
    self:ApplyDebugLevel()
end
