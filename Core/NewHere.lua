local _, ns = ...

-- "New here!": the first catch of an item at a place (map and area), counted over every character
-- of the account, says so in chat and in <NAME>_NEW_HERE, and the window marks the item "new" until
-- the player leaves the place.

---@type Addon
local Addon = ns
local L = Addon.L

-- The items new at the place in newPlace, by item ID.
---@type table<number, true>
local newItems = {}
---@type string?
local newPlace

---The key of a place, to tell one from another.
---@param mapID number
---@param area AddonArea
---@return string
local function PlaceKey(mapID, area)
    return mapID .. ":" .. tostring(area)
end

---Whether any character of the account caught the item at the place.
---@param mapID number
---@param area AddonArea
---@param itemID number
---@return boolean
function Addon:EverCaughtHere(mapID, area, itemID)
    for _, char in pairs(self.db.global.chars) do
        local zone = char.zones[mapID]
        ---@type AddonCounts?
        local counts = zone and zone[area]
        if counts and counts[itemID] then return true end
    end
    return false
end

---Says an item is new at the place, and marks it so until the player leaves.
---@param itemID number
---@param mapID number
---@param area AddonArea
function Addon:NoteNewHere(itemID, mapID, area)
    local key = PlaceKey(mapID, area)
    if key ~= newPlace then
        wipe(newItems)
        newPlace = key
    end
    newItems[itemID] = true
    local name = C_Item.GetItemNameByID(itemID) or self.db.global.items[itemID] or ("item:" .. itemID)
    self:Print(L.NEW_HERE_LINE:format(name, self.AreaName(mapID, area)))
    self:SendMessage(self.messages.newHere, itemID, mapID, area)
end

---Drops the marks once the player stands somewhere else. Asks where only while there are marks,
---so it costs nothing (no area name lookups) until the first catch.
function Addon:KeepNewHere()
    if not newPlace then return end
    local mapID, area = self.CurrentPlace()
    if
        mapID and newPlace == PlaceKey(mapID, area --[[@as AddonArea]])
    then
        return
    end
    wipe(newItems)
    newPlace = nil
end

---Whether the item is marked new at the place the player stands.
---@param itemID number
---@return boolean
function Addon:IsNewHere(itemID)
    return newItems[itemID] == true
end
