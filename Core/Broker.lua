local _, ns = ...

-- The data broker object, named after the addon (Titan Panel, ChocolateBar, ElvUI's datatexts):
-- the session's catches as text; in its tooltip the session, the rarest catch where the player
-- stands and the session records; a click opens the options.

---@type Addon
local Addon = ns
local L = Addon.L

local ICON = "Interface\\Icons\\Trade_Fishing"

---@param seconds number
---@return number
local function Minutes(seconds)
    return math.floor(seconds / 60)
end

---Fills the broker's tooltip.
---@param tooltip GameTooltip
local function OnTooltipShow(tooltip)
    tooltip:AddLine(Addon.NAME)
    local session = Addon:LatestSession()
    if session then
        tooltip:AddLine(L.BROKER_SESSION:format(session.catches or 0, Minutes(session.last - session.start)), 1, 1, 1)
    else
        tooltip:AddLine(L.BROKER_NO_SESSION, 0.6, 0.6, 0.6)
    end
    local mapID, area = Addon.CurrentPlace()
    local itemID, share = nil, nil
    if mapID then
        itemID, share = Addon:RarestAt(mapID, area)
    end
    if itemID and share then
        local name = C_Item.GetItemNameByID(itemID) or Addon.db.global.items[itemID] or ("item:" .. itemID)
        tooltip:AddLine(L.BROKER_RAREST:format(name, Addon.Percent(share)), 1, 1, 1)
    end
    local records = Addon.db.global.records
    if records.sessionCatches then
        tooltip:AddLine(L.BROKER_RECORD_CATCHES:format(records.sessionCatches.n), 0.6, 0.8, 1)
    end
    if records.sessionLength then
        tooltip:AddLine(L.BROKER_RECORD_LENGTH:format(Minutes(records.sessionLength.n)), 0.6, 0.8, 1)
    end
    tooltip:AddLine(L.BROKER_CLICK, 0.6, 0.6, 0.6)
end

local object = LibStub("LibDataBroker-1.1"):NewDataObject(Addon.NAME, {
    type = "data source",
    icon = ICON,
    text = L.CAUGHT:format(0),
    OnTooltipShow = OnTooltipShow,
    OnClick = function()
        Addon:OpenOptions()
    end,
})

---Shows the session's catches as the broker's text.
function Addon:UpdateBroker()
    local session = self.session
    object.text = L.CAUGHT:format(session and session.catches or 0)
end
