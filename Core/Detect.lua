local _, ns = ...

-- What the game says: a fishing pole in hand (the session and the window follow it) and a loot
-- window of fishing loot (each item in it is a catch).

---@type Addon
local Addon = ns

---Whether the main hand holds a fishing pole.
---@return boolean
function Addon:HasFishingPole()
    local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
    if not itemID then return false end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon and subClassID == Enum.ItemWeaponSubclass.Fishingpole
end

---On login and on every change of the main hand: a pole coming in starts or continues the
---session, one going away ends it and sends the counts to the guild; then the window is shown or
---hidden and the broker shows the session's catches.
---@param event string
---@param slot number? PLAYER_EQUIPMENT_CHANGED's slot
function Addon:UpdateFishing(event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= INVSLOT_MAINHAND then return end
    local fishing = self:HasFishingPole()
    if fishing ~= self.fishing then
        self.fishing = fishing
        if fishing then
            self:StartSession()
        elseif self.session then
            self:EndSession()
            self:SendSnapshot()
        end
    end
    self:UpdateCatchWindow()
    self:UpdateBroker()
end

-- The slots of the loot window counted so far. A fast-loot addon loots on LOOT_READY and may close
-- the window before LOOT_OPENED, and LOOT_READY can come twice with slots the first lacked, so
-- both events are read and each slot counts once. LOOT_CLOSED starts over; so does a quiet second,
-- for a window that never sent its close.
---@type table<number, true>
local counted = {}
---@type number?
local countedAt
local WINDOW = 1

---LOOT_READY and LOOT_OPENED: every item of a fishing loot window not counted yet is logged where
---the player stands, with its time of day and season, whether it is new there and the records it
---beats, before other addons and the window hear of it. Money and anything the client hides are
---skipped.
---@param event string
function Addon:OnLoot(event)
    local fishing = IsFishingLoot()
    self:Log("debug", "{1}: {2} slots, fishing {3}", event, GetNumLootItems(), fishing)
    if not fishing then return end
    local mapID, area = Addon.CurrentPlace()
    if not mapID or not area then
        self:Log("warn", "fishing loot where the client tells no map")
        return
    end
    local now = GetTime()
    if countedAt and now - countedAt > WINDOW then wipe(counted) end
    countedAt = now
    for slot = 1, GetNumLootItems() do
        if not counted[slot] and GetLootSlotType(slot) == Enum.LootSlotType.Item then
            local link = GetLootSlotLink(slot)
            local itemID = Addon.Readable(link) and C_Item.GetItemInfoInstant(link)
            if not itemID then self:Log("warn", "slot {1}: the item is hidden", slot) end
            if itemID then
                counted[slot] = true
                local _, name, quantity = GetLootSlotInfo(slot)
                quantity = Addon.Readable(quantity) and quantity or 1
                self:Log("info", "caught {1} x{2} at {3} on {4}", itemID, quantity, Addon.PlaceName(mapID, area), event)
                self:Count("catches")
                local isNew = not self:EverCaughtHere(mapID, area, itemID)
                self:RecordCatch(mapID, area, itemID, Addon.Readable(name) and name or nil, quantity)
                self:NoteTime(itemID, quantity)
                self:NoteRecords(itemID, quantity, mapID, area)
                if isNew then self:NoteNewHere(itemID, mapID, area) end
                self:UpdateBroker()
                self:SendMessage(self.messages.catch, itemID, quantity, mapID, area)
            end
        end
    end
end

---LOOT_CLOSED: the next loot window is counted from scratch.
function Addon:OnLootClosed()
    wipe(counted)
    countedAt = nil
end
