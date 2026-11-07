local _, ns = ...

-- Records, account-wide: an item's biggest stack (with where), the most catches in one session and
-- the longest session. A first value is kept quietly; beating a record from before says so in chat,
-- a session's records once per session. The rarest catch at a place is worked out when asked.

---@type Addon
local Addon = ns
local L = Addon.L

---Keeps a session record up to date. Beating a record another session set says so, once per
---session (the session's `said` flag).
---@param session AddonSession
---@param key "sessionCatches"|"sessionLength"
---@param value number
---@param said "saidCatches"|"saidLength"
---@param announce fun(value: number, was: number)
local function SessionRecord(session, key, value, said, announce)
    local records = Addon.db.global.records
    local record = records[key]
    if not record then
        records[key] = { n = value, session = session.start }
        return
    end
    if value <= record.n then return end
    if record.session ~= session.start and not session[said] then
        session[said] = true
        announce(value, record.n)
    end
    record.n, record.session = value, session.start
end

---@param value number
---@param was number
local function AnnounceCatches(value, was)
    Addon:Print(L.RECORD_CATCHES:format(value, was))
end

---@param value number seconds
---@param was number seconds
local function AnnounceLength(value, was)
    Addon:Print(L.RECORD_LENGTH:format(math.floor(value / 60), math.floor(was / 60)))
end

---Checks a catch against the records, after it was logged.
---@param itemID number
---@param quantity number
---@param mapID number
---@param area AddonArea
function Addon:NoteRecords(itemID, quantity, mapID, area)
    local stacks = self.db.global.records.stacks
    local stack = stacks[itemID]
    if not stack or quantity > stack.n then
        if stack then
            local name = C_Item.GetItemNameByID(itemID) or self.db.global.items[itemID] or ("item:" .. itemID)
            self:Print(L.RECORD_STACK:format(name, quantity, stack.n))
        else
            stack = {} --[[@as AddonStackRecord]]
            stacks[itemID] = stack
        end
        stack.n, stack.mapID, stack.area, stack.t = quantity, mapID, area, GetServerTime()
    end
    local session = self.session
    if not session then return end
    SessionRecord(session, "sessionCatches", session.catches or 0, "saidCatches", AnnounceCatches)
    SessionRecord(session, "sessionLength", session.last - session.start, "saidLength", AnnounceLength)
end

---The item's biggest stack and where, or nil.
---@param itemID number
---@return AddonStackRecord?
function Addon:StackRecord(itemID)
    return self.db.global.records.stacks[itemID]
end

---The item caught least at a place over every character, and its share there; nil where nothing
---was caught.
---@param mapID number
---@param area AddonArea?
---@return number? itemID
---@return number? share
function Addon:RarestAt(mapID, area)
    local rows, n, total = self:PlaceCounts(self.views.account, mapID, area)
    if n == 0 then return nil, nil end
    return rows[n].itemID, rows[n].count / total
end

---Forgets the records, with the log.
function Addon:ClearRecords()
    local records = self.db.global.records
    wipe(records.stacks)
    records.sessionCatches, records.sessionLength = nil, nil
end
