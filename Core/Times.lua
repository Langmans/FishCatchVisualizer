local _, ns = ...

-- When fish bite: every catch is counted by the server's time of day and by the season of the
-- month, account-wide, per item and for all catches together (item 0). An item's tooltip then says
-- "Only at night" or "Only in winter and spring", but only once enough was fished at the other
-- times without it, so a month of play does not make every fish an autumn fish.

---@type Addon
local Addon = ns
local L = Addon.L

-- times[ALL] counts every catch.
local ALL = 0
-- Day is from 6:00 to 18:00 server time, as Classic's day and night fish keep it.
local DAY_START, DAY_END = 6, 18
-- An item needs this many catches before its tooltip says anything about time.
local MIN_CATCHES = 5
-- A time of day or a season counts as fished once this many catches were made in it.
local MIN_FISHED = 20

Addon.daytimes = { day = "day", night = "night" }
-- The seasons in the order the tooltip names them, and each month's.
Addon.SEASON_ORDER = { "winter", "spring", "summer", "autumn" }
local SEASON_OF_MONTH = {
    "winter",
    "winter",
    "spring",
    "spring",
    "spring",
    "summer",
    "summer",
    "summer",
    "autumn",
    "autumn",
    "autumn",
    "winter",
}

---The season of a month (1 to 12), by the northern months.
---@param month number
---@return string
function Addon.SeasonOf(month)
    return SEASON_OF_MONTH[month]
end

---Per item ID: its time notes ("Only at night", "Only in winter"), or false for none. Emptied by
---every catch.
---@type table<number, { daytime: string?, season: string? }|false>
local notesCache = {}

---Counts a catch in one entry of times.
---@param times table<number, AddonTimes>
---@param id number
---@param daytime string
---@param season string
---@param quantity number
local function Count(times, id, daytime, season, quantity)
    local entry = times[id]
    if not entry then
        entry = {}
        times[id] = entry
    end
    entry[daytime] = (entry[daytime] or 0) + quantity
    entry[season] = (entry[season] or 0) + quantity
end

---Counts a catch by the time of day and the season it is now.
---@param itemID number
---@param quantity number
function Addon:NoteTime(itemID, quantity)
    local hour = GetGameTime()
    local daytime = (hour >= DAY_START and hour < DAY_END) and self.daytimes.day or self.daytimes.night
    local season = self.SeasonOf(C_DateAndTime.GetCurrentCalendarTime().month)
    local times = self.db.global.times
    Count(times, itemID, daytime, season, quantity)
    Count(times, ALL, daytime, season, quantity)
    wipe(notesCache)
end

---Forgets the times, with the log.
function Addon:ClearTimes()
    wipe(self.db.global.times)
    wipe(notesCache)
end

---Whether an item never bit at a time (a daytime or a season) that was fished enough without it.
---@param item AddonTimes
---@param all AddonTimes
---@param key string
---@return boolean
local function MissedAt(item, all, key)
    return (item[key] or 0) == 0 and (all[key] or 0) >= MIN_FISHED
end

---The item's time notes for its tooltip: when it bites only by day or at night, and only in some
---seasons. Built once per item until the next catch.
---@param itemID number
---@return string? daytime "Only at night"
---@return string? season "Only in winter and spring"
function Addon:TimeNotes(itemID)
    local cached = notesCache[itemID]
    if cached == nil then
        cached = false
        local times = self.db.global.times
        local item, all = times[itemID], times[ALL]
        local catches = item and (item.day or 0) + (item.night or 0) or 0
        if item and all and catches >= MIN_CATCHES then
            local daytime
            if MissedAt(item, all, self.daytimes.day) then
                daytime = L.ONLY_NIGHT
            elseif MissedAt(item, all, self.daytimes.night) then
                daytime = L.ONLY_DAY
            end
            ---@type string[]
            local caught = {}
            local missed = false
            for _, season in ipairs(self.SEASON_ORDER) do
                if (item[season] or 0) > 0 then caught[#caught + 1] = L["SEASON_" .. season:upper()] end
                missed = missed or MissedAt(item, all, season)
            end
            local season
            if missed then
                local last = table.remove(caught)
                local list = #caught > 0 and L.AND:format(table.concat(caught, ", "), last) or last
                season = L.ONLY_IN:format(list)
            end
            if daytime or season then cached = { daytime = daytime, season = season } end
        end
        notesCache[itemID] = cached
    end
    if not cached then return nil, nil end
    return cached.daytime, cached.season
end
