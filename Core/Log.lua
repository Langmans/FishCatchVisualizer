local _, ns = ...

-- The catch log: counts per character and per fishing session, both keyed
-- zones[mapID][area][itemID], and the two reads made of them: the counts at one place (the
-- window) and the places one item was caught (the tooltip).

---@type Addon
local Addon = ns

-- A session goes on when the pole comes back within this many seconds of the last catch or of
-- putting it away; after a longer break the next one starts.
local SESSION_GAP = 15 * 60
-- Sessions kept; the oldest go first.
local MAX_SESSIONS = 50

---Adds `quantity` of an item to a zones table.
---@param zones AddonZones
---@param mapID number
---@param area AddonArea
---@param itemID number
---@param quantity number
local function Bump(zones, mapID, area, itemID, quantity)
    ---@type AddonZone?
    local zone = zones[mapID]
    if not zone then
        zone = {} --[[@as AddonZone]]
        zones[mapID] = zone
    end
    ---@type AddonCounts?
    local counts = zone[area]
    if not counts then
        counts = {} --[[@as AddonCounts]]
        zone[area] = counts
    end
    counts[itemID] = (counts[itemID] or 0) + quantity
end

---This character's newest session, whether or not it is still going.
---@return AddonSession?
function Addon:LatestSession()
    if self.session then return self.session end
    local sessions, key = self.db.global.sessions, self.db.keys.char
    for i = #sessions, 1, -1 do
        if sessions[i].char == key then return sessions[i] end
    end
end

---Makes the session go on, or starts a new one after a break longer than SESSION_GAP.
---@return AddonSession
function Addon:StartSession()
    local now = GetServerTime()
    local latest = self:LatestSession()
    if latest and now - latest.last <= SESSION_GAP then
        latest.last = now
        self.session = latest
        self:Log("info", "session goes on")
        return latest
    end
    local sessions = self.db.global.sessions
    ---@type AddonSession
    local session = {
        char = self.db.keys.char,
        start = now,
        last = now,
        zones = {} --[[@as AddonZones]],
    }
    sessions[#sessions + 1] = session
    while #sessions > MAX_SESSIONS do
        table.remove(sessions, 1)
    end
    self.session = session
    self:Log("info", "session started")
    return session
end

---The pole went away: the session's last moment is now; the next pole may make it go on.
function Addon:EndSession()
    local session = self.session
    if not session then return end
    session.last = GetServerTime()
    self.session = nil
    self:Log("info", "session ended after {1} catches", session.catches or 0)
end

---Per item ID: the places it was caught, best share first, or false when it never was. Filled by
---ItemPlaces, emptied by every change to the log.
---@type table<number, AddonItemPlace[]|false>
local placesCache = {}

---Logs a catch for this character and its session.
---@param mapID number
---@param area AddonArea
---@param itemID number
---@param name string? the item's name, kept for when the client has not loaded the item
---@param quantity number
function Addon:RecordCatch(mapID, area, itemID, name, quantity)
    local global, key = self.db.global, self.db.keys.char
    local char = global.chars[key]
    if not char then
        char = {
            zones = {} --[[@as AddonZones]],
        }
        global.chars[key] = char
    end
    Bump(char.zones, mapID, area, itemID, quantity)
    local session = self.session or self:StartSession()
    Bump(session.zones, mapID, area, itemID, quantity)
    session.catches = (session.catches or 0) + quantity
    session.last = GetServerTime()
    if name then global.items[itemID] = name end
    wipe(placesCache)
end

---Forgets every character's catches and sessions, the times of day and seasons they bit in, and
---the records.
function Addon:ClearLog()
    local global = self.db.global
    wipe(global.chars)
    wipe(global.sessions)
    wipe(global.items)
    self.session = nil
    wipe(placesCache)
    self:ClearTimes()
    self:ClearRecords()
end

---Something else changed the counts (a guildmate's arrived): the item places are built again.
function Addon:LogChanged()
    wipe(placesCache)
end

-- PlaceCounts' working tables, reused on every call: item ID -> count, the row tables, and the
-- rows handed out.
---@type table<number, number>
local sums = {}
---@type AddonRow[]
local pool = {}
---@type AddonRow[]
local rows = {}

---Adds a place's counts to `sums`; without an area, every area of the map.
---@param zones AddonZones?
---@param mapID number
---@param area AddonArea?
local function AddPlace(zones, mapID, area)
    ---@type AddonZone?
    local zone = zones and zones[mapID]
    if not zone then return end
    for key, counts in pairs(zone) do
        if area == nil or key == area then
            for itemID, count in pairs(counts) do
                sums[itemID] = (sums[itemID] or 0) + count
            end
        end
    end
end

---Most caught first; the item ID decides a tie, so the order holds from one call to the next.
---@param a AddonRow
---@param b AddonRow
---@return boolean
local function ByCount(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.itemID < b.itemID
end

---The items caught at a place, most first. The rows are reused by the next call.
---@param view string a Addon.views value
---@param mapID number
---@param area AddonArea? nil for the whole zone
---@return AddonRow[] rows
---@return number count how many rows
---@return number total the place's catches
function Addon:PlaceCounts(view, mapID, area)
    wipe(sums)
    local global = self.db.global
    if view == self.views.session then
        local session = self:LatestSession()
        AddPlace(session and session.zones, mapID, area)
    elseif view == self.views.char then
        local char = global.chars[self.db.keys.char]
        AddPlace(char and char.zones, mapID, area)
    else
        for _, char in pairs(global.chars) do
            AddPlace(char.zones, mapID, area)
        end
        if view == self.views.guild then
            for _, mate in pairs(global.guild) do
                AddPlace(mate.zones, mapID, area)
            end
        end
    end
    wipe(rows)
    local n, total = 0, 0
    for itemID, count in pairs(sums) do
        n = n + 1
        local row = pool[n] or {}
        pool[n] = row
        row.itemID, row.count = itemID, count
        rows[n] = row
        total = total + count
    end
    table.sort(rows, ByCount)
    return rows, n, total
end

---Best share first, then the most caught; map and area decide a tie.
---@param a AddonItemPlace
---@param b AddonItemPlace
---@return boolean
local function ByShare(a, b)
    local shareA, shareB = a.count / a.total, b.count / b.total
    if shareA ~= shareB then return shareA > shareB end
    if a.count ~= b.count then return a.count > b.count end
    if a.mapID ~= b.mapID then return a.mapID < b.mapID end
    return tostring(a.area) < tostring(b.area)
end

---Adds one source's counts (a character's or a guildmate's) to the places of an item.
---@param byPlace table<string, AddonItemPlace>
---@param zones AddonZones
---@param itemID number
local function AddItemPlaces(byPlace, zones, itemID)
    for mapID, zone in pairs(zones) do
        for area, counts in pairs(zone) do
            local key = mapID .. ":" .. tostring(area)
            local place = byPlace[key]
            if not place then
                place = { mapID = mapID, area = area, count = 0, total = 0 }
                byPlace[key] = place
            end
            place.count = place.count + (counts[itemID] or 0)
            for _, count in pairs(counts) do
                place.total = place.total + count
            end
        end
    end
end

---Every place any character or guildmate caught the item, with its count and the place's total,
---best share first; nil when it was never caught. Built once per item until the log changes.
---@param itemID number
---@return AddonItemPlace[]?
function Addon:ItemPlaces(itemID)
    local cached = placesCache[itemID]
    if cached ~= nil then return cached or nil end
    ---@type table<string, AddonItemPlace>
    local byPlace = {}
    ---@type AddonItemPlace[]
    local places = {}
    local global = self.db.global
    for _, char in pairs(global.chars) do
        AddItemPlaces(byPlace, char.zones, itemID)
    end
    for _, mate in pairs(global.guild) do
        AddItemPlaces(byPlace, mate.zones, itemID)
    end
    for _, place in pairs(byPlace) do
        if place.count > 0 then places[#places + 1] = place end
    end
    table.sort(places, ByShare)
    placesCache[itemID] = #places > 0 and places
    return placesCache[itemID] or nil
end
