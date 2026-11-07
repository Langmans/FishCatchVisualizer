local _, ns = ...

-- What the game says: a fishing pole in hand (the session and the window follow it) and a loot
-- window of fishing loot (each item in it is a catch).

---@type FishCatchVisualizer
local FCV = ns.FCV

---Whether the main hand holds a fishing pole.
---@return boolean
function FCV:HasFishingPole()
    local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
    if not itemID then return false end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon and subClassID == Enum.ItemWeaponSubclass.Fishingpole
end

---On login and on every change of the main hand: a pole coming in starts or continues the
---session, one going away ends it; then the window is shown or hidden.
---@param event string
---@param slot number? PLAYER_EQUIPMENT_CHANGED's slot
function FCV:UpdateFishing(event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= INVSLOT_MAINHAND then return end
    local fishing = self:HasFishingPole()
    if fishing ~= self.fishing then
        self.fishing = fishing
        if fishing then
            self:StartSession()
        else
            self:EndSession()
        end
    end
    self:UpdateCatchWindow()
end

---LOOT_OPENED: every item of a fishing loot window is logged where the player stands. Money and
---anything the client hides are skipped.
function FCV:OnLootOpened()
    if not IsFishingLoot() then return end
    local mapID, area = ns.CurrentPlace()
    if not mapID or not area then return end
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == Enum.LootSlotType.Item then
            local link = GetLootSlotLink(slot)
            local itemID = ns.Readable(link) and C_Item.GetItemInfoInstant(link)
            if itemID then
                local _, name, quantity = GetLootSlotInfo(slot)
                quantity = ns.Readable(quantity) and quantity or 1
                self:RecordCatch(mapID, area, itemID, ns.Readable(name) and name or nil, quantity)
                self:SendMessage(self.messages.catch, itemID, quantity, mapID, area)
            end
        end
    end
end
