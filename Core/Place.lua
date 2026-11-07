local _, ns = ...

-- Where the player stands, as the catch log keys it: the uiMapID and an area key. The area key is
-- the subzone's AreaTable ID, the same in every client language; the client only gives the
-- subzone's name (GetSubZoneText), so names are matched to IDs through C_Map.GetAreaInfo. A
-- subzone with no ID keeps its text as key, and no subzone at all is area 0, the zone itself.

---@type FishCatchVisualizer
local FCV = ns.FCV
local L = FCV.L

-- Area IDs are looked up to here. Classic's go to about 5000, retail's past 15000; WoW: Forever's
-- own new areas may sit anywhere in between.
local MAX_AREA_ID = 20000

---Area name -> area ID, built on first use: scanning every ID costs a moment, so not at login.
---The first ID with a name wins; within one map a name hardly ever comes twice.
---@type table<string, number>?
local areaIDs

---@param name string
---@return number?
local function AreaID(name)
    if not areaIDs then
        areaIDs = {}
        for id = 1, MAX_AREA_ID do
            local areaName = C_Map.GetAreaInfo(id)
            if areaName and areaIDs[areaName] == nil then areaIDs[areaName] = id end
        end
    end
    return areaIDs[name]
end

---The player's map and area key, or nil where the client cannot tell the map.
---@return number? mapID
---@return FishCatchVisualizerArea? area
function ns.CurrentPlace()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not ns.Readable(mapID) then return nil end
    local text = GetSubZoneText()
    if not ns.Readable(text) or text == "" then return mapID, 0 end
    return mapID, AreaID(text) or text
end

---The map's name in the client's language.
---@param mapID number
---@return string
function ns.ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or L.MAP:format(mapID)
end

---The area's name: the subzone's, or the zone's for area 0.
---@param mapID number
---@param area FishCatchVisualizerArea
---@return string
function ns.AreaName(mapID, area)
    if area == 0 then return ns.ZoneName(mapID) end
    if type(area) == "number" then return C_Map.GetAreaInfo(area) or ns.ZoneName(mapID) end
    return area
end

---"Crystal Lake, Elwynn Forest", or the zone's name alone for area 0.
---@param mapID number
---@param area FishCatchVisualizerArea
---@return string
function ns.PlaceName(mapID, area)
    if area == 0 then return ns.ZoneName(mapID) end
    return L.PLACE:format(ns.AreaName(mapID, area), ns.ZoneName(mapID))
end
