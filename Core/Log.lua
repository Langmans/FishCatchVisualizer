local _, ns = ...

-- The catch log: counts per character and per fishing session, both keyed
-- zones[mapID][area][itemID], and the two reads made of them: the counts at one place (the
-- window) and the places one item was caught (the tooltip).

---@type FishCatchVisualizer
local FCV = ns.FCV

-- A session goes on when the pole comes back within this many seconds of the last catch or of
-- putting it away; after a longer break the next one starts.
local SESSION_GAP = 15 * 60
-- Sessions kept; the oldest go first.
local MAX_SESSIONS = 50

---Adds `quantity` of an item to a zones table.
---@param zones FishCatchVisualizerZones
---@param mapID number
---@param area FishCatchVisualizerArea
---@param itemID number
---@param quantity number
local function Bump(zones, mapID, area, itemID, quantity)
    ---@type FishCatchVisualizerZone?
    local zone = zones[mapID]
    if not zone then
        zone = {} --[[@as FishCatchVisualizerZone]]
        zones[mapID] = zone
    end
    ---@type FishCatchVisualizerCounts?
    local counts = zone[area]
    if not counts then
        counts = {} --[[@as FishCatchVisualizerCounts]]
        zone[area] = counts
    end
    counts[itemID] = (counts[itemID] or 0) + quantity
end

---This character's newest session, whether or not it is still going.
---@return FishCatchVisualizerSession?
function FCV:LatestSession()
    if self.session then return self.session end
    local sessions, key = self.db.global.sessions, self.db.keys.char
    for i = #sessions, 1, -1 do
        if sessions[i].char == key then return sessions[i] end
    end
end

---Makes the session go on, or starts a new one after a break longer than SESSION_GAP.
---@return FishCatchVisualizerSession
function FCV:StartSession()
    local now = GetServerTime()
    local latest = self:LatestSession()
    if latest and now - latest.last <= SESSION_GAP then
        latest.last = now
        self.session = latest
        return latest
    end
    local sessions = self.db.global.sessions
    ---@type FishCatchVisualizerSession
    local session = {
        char = self.db.keys.char,
        start = now,
        last = now,
        zones = {} --[[@as FishCatchVisualizerZones]],
    }
    sessions[#sessions + 1] = session
    while #sessions > MAX_SESSIONS do
        table.remove(sessions, 1)
    end
    self.session = session
    return session
end

---The pole went away: the session's last moment is now; the next pole may make it go on.
function FCV:EndSession()
    local session = self.session
    if not session then return end
    session.last = GetServerTime()
    self.session = nil
end

---Per item ID: the places it was caught, best share first, or false when it never was. Filled by
---ItemPlaces, emptied by every change to the log.
---@type table<number, FishCatchVisualizerItemPlace[]|false>
local placesCache = {}

---Logs a catch for this character and its session.
---@param mapID number
---@param area FishCatchVisualizerArea
---@param itemID number
---@param name string? the item's name, kept for when the client has not loaded the item
---@param quantity number
function FCV:RecordCatch(mapID, area, itemID, name, quantity)
    local global, key = self.db.global, self.db.keys.char
    local char = global.chars[key]
    if not char then
        char = {
            zones = {} --[[@as FishCatchVisualizerZones]],
        }
        global.chars[key] = char
    end
    Bump(char.zones, mapID, area, itemID, quantity)
    local session = self.session or self:StartSession()
    Bump(session.zones, mapID, area, itemID, quantity)
    session.last = GetServerTime()
    if name then global.items[itemID] = name end
    wipe(placesCache)
end

---Forgets every character's catches and sessions.
function FCV:ClearLog()
    local global = self.db.global
    wipe(global.chars)
    wipe(global.sessions)
    wipe(global.items)
    self.session = nil
    wipe(placesCache)
end

-- PlaceCounts' working tables, reused on every call: item ID -> count, the row tables, and the
-- rows handed out.
---@type table<number, number>
local sums = {}
---@type FishCatchVisualizerRow[]
local pool = {}
---@type FishCatchVisualizerRow[]
local rows = {}

---Adds a place's counts to `sums`; without an area, every area of the map.
---@param zones FishCatchVisualizerZones?
---@param mapID number
---@param area FishCatchVisualizerArea?
local function AddPlace(zones, mapID, area)
    ---@type FishCatchVisualizerZone?
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
---@param a FishCatchVisualizerRow
---@param b FishCatchVisualizerRow
---@return boolean
local function ByCount(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.itemID < b.itemID
end

---The items caught at a place, most first. The rows are reused by the next call.
---@param view string a FCV.views value
---@param mapID number
---@param area FishCatchVisualizerArea? nil for the whole zone
---@return FishCatchVisualizerRow[] rows
---@return number count how many rows
---@return number total the place's catches
function FCV:PlaceCounts(view, mapID, area)
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
---@param a FishCatchVisualizerItemPlace
---@param b FishCatchVisualizerItemPlace
---@return boolean
local function ByShare(a, b)
    local shareA, shareB = a.count / a.total, b.count / b.total
    if shareA ~= shareB then return shareA > shareB end
    if a.count ~= b.count then return a.count > b.count end
    if a.mapID ~= b.mapID then return a.mapID < b.mapID end
    return tostring(a.area) < tostring(b.area)
end

---Every place any character caught the item, with its count and the place's total, best share
---first; nil when it was never caught. Built once per item until the log changes.
---@param itemID number
---@return FishCatchVisualizerItemPlace[]?
function FCV:ItemPlaces(itemID)
    local cached = placesCache[itemID]
    if cached ~= nil then return cached or nil end
    ---@type table<string, FishCatchVisualizerItemPlace>
    local byPlace = {}
    ---@type FishCatchVisualizerItemPlace[]
    local places = {}
    for _, char in pairs(self.db.global.chars) do
        for mapID, zone in pairs(char.zones) do
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
    for _, place in pairs(byPlace) do
        if place.count > 0 then places[#places + 1] = place end
    end
    table.sort(places, ByShare)
    placesCache[itemID] = #places > 0 and places
    return placesCache[itemID] or nil
end
