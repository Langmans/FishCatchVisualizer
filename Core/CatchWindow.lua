local _, ns = ...

-- The catch window: the player's own catches where they stand, as bars, most caught first. The
-- buttons pick whose catches: this session's, this character's or every character's.

---@type Addon
local Addon = ns
local L = Addon.L

-- The icon for an item the client has none for yet: the question mark.
local UNKNOWN_ICON = 134400

local window = Addon.NewBarWindow("catches", L.WINDOW_CATCHES, { 0.18, 0.44, 0.56 })
Addon.catchWindow = window

for _, view in ipairs(Addon.VIEW_ORDER) do
    window:AddButton(view, L["BUTTON_" .. view:upper()], function()
        Addon:SetView(view)
    end)
end

-- The "new" mark after an item first caught at the place: green.
local NEW_MARK = " |cff33ff33" .. L.NEW .. "|r"

---An item's icon and name: the client's name, or the one saved when it was caught; in its quality's
---colour when the profile asks for it and the client knows the quality; marked when new here.
---@param itemID number
---@param isNew boolean
---@return string
local function ItemLabel(itemID, isNew)
    local name = C_Item.GetItemNameByID(itemID) or Addon.db.global.items[itemID] or ("item:" .. itemID)
    if Addon.db.profile.qualityColors then
        local quality = C_Item.GetItemQualityByID(itemID)
        ---@type { hex: string }?
        local color = quality and ITEM_QUALITY_COLORS[quality]
        if color then name = color.hex .. name .. "|r" end
    end
    return ("|T%s:14:14|t %s%s"):format(C_Item.GetItemIconByID(itemID) or UNKNOWN_ICON, name, isNew and NEW_MARK or "")
end

---Whose catches the window counts.
---@param view string a Addon.views value
function Addon:SetView(view)
    self.db.profile.view = view
    self:UpdateCatchWindow()
end

---Shows or hides the window by the settings and the pole, and fills it for where the player
---stands.
function Addon:UpdateCatchWindow()
    local profile = self.db.profile
    -- Every update follows the player, shown or not: a "new" mark ends when they leave the place.
    self:KeepNewHere()
    local shown = self.editing
        or profile.show == self.showModes.always
        or (profile.show == self.showModes.pole and self:HasFishingPole())
    window.frame:SetShown(shown)
    if not shown then return end
    window:Select(profile.view)

    local mapID, area = Addon.CurrentPlace()
    if not mapID then
        window:SetTitle(L.UNKNOWN_PLACE, "")
        window:ShowRows(0, L.NOTHING_HERE)
        return
    end
    if profile.scope == self.scopes.zone then area = nil end
    -- Every kind the account caught here, counted first: PlaceCounts reuses its rows.
    local _, known = self:PlaceCounts(self.views.account, mapID, area)
    local rows, n, total = self:PlaceCounts(profile.view, mapID, area)
    local caught = L.CAUGHT:format(total)
    if known > 0 then caught = L.SUBTITLE:format(caught, L.KINDS:format(n, known)) end
    if area == nil or area == 0 then
        window:SetTitle(Addon.ZoneName(mapID), caught)
    else
        window:SetTitle(Addon.AreaName(mapID, area), L.SUBTITLE:format(Addon.ZoneName(mapID), caught))
    end
    local count = math.min(n, profile.rows)
    for i = 1, count do
        local row = rows[i]
        local share = row.count / total
        local label = ItemLabel(row.itemID, self:IsNewHere(row.itemID))
        window:FillRow(i, label, L.ROW_COUNT:format(row.count, Addon.Percent(share)), share)
    end
    window:ShowRows(count, n == 0 and L.NOTHING_HERE or nil, n > count and L.MORE:format(n - count) or nil)
end
