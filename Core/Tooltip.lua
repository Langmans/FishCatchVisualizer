local _, ns = ...

-- The item tooltip: under an item any character has caught, where, best share first ("Crystal
-- Lake, Elwynn Forest   45% (21)": 45% of what was caught there was this item, 21 of them).

---@type FishCatchVisualizer
local FCV = ns.FCV
local L = FCV.L

---Adds the places to an item's tooltip. Runs on every item tooltip, so it reads the cached list
---and makes no tables.
---@param tooltip GameTooltip
---@param data FishCatchVisualizerTooltipData?
function FCV:AddItemPlaces(tooltip, data)
    local profile = self.db.profile
    if not profile.tooltip then return end
    local itemID = data and data.id
    if not ns.Readable(itemID) then return end
    local places = self:ItemPlaces(itemID --[[@as number]])
    if not places then return end
    local limit = profile.tooltipPlaces
    tooltip:AddLine(L.TOOLTIP_TITLE, 0.4, 0.73, 1)
    for i = 1, math.min(#places, limit) do
        ---@type FishCatchVisualizerItemPlace
        local place = places[i]
        local share = L.TOOLTIP_SHARE:format(ns.Percent(place.count / place.total), place.count)
        tooltip:AddDoubleLine(ns.PlaceName(place.mapID, place.area), share, 1, 1, 1, 1, 1, 1)
    end
    if #places > limit then tooltip:AddLine(L.TOOLTIP_MORE:format(#places - limit), 0.6, 0.6, 0.6) end
end

---Hooks the item tooltips; a client without TooltipDataProcessor gets none.
function FCV:SetupTooltip()
    if not TooltipDataProcessor then return end
    ---@param tooltip GameTooltip
    ---@param data FishCatchVisualizerTooltipData
    local function OnItemTooltip(tooltip, data)
        self:AddItemPlaces(tooltip, data)
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
