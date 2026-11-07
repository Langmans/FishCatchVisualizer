local _, ns = ...

-- Sharing with the guild: guildmates with the addon swap their accounts' counts by addon message
-- (AceComm, so long messages are split and throttled). Each account has an ID of its own, so two
-- characters of one player count once. A hello 10 s after login asks for the guild's counts;
-- whoever hears one answers a few seconds later, at most once every 5 minutes, and putting the pole
-- away sends the counts too. What arrives is checked, and only counts are kept:
-- global.guild[account ID] = { name = the sender, zones, t }.
--
-- Messages: "H" (hello), "S" .. snapshot (CBOR of { id, zones }, deflated, Base64).

---@type Addon
local Addon = ns

-- AceComm's prefix: the folder's name, cut to the 16 characters a prefix may have.
Addon.COMM_PREFIX = Addon.NAME:sub(1, 16)
local HELLO, SNAPSHOT = "H", "S"
local CHANNEL = "GUILD"
local HELLO_DELAY = 10
-- An answer to a hello waits this many seconds, chosen at random, so a guild does not answer at once.
local ANSWER_MIN, ANSWER_MAX = 3, 15
-- Seconds at least between two snapshots this account sends.
local SNAPSHOT_GAP = 300
local lastSnapshot = -SNAPSHOT_GAP

---This account's ID in the guild, made once.
---@return string
function Addon:ShareId()
    local global = self.db.global
    if not global.shareId then global.shareId = ("%08x%08x"):format(math.random(0, 0x7fffffff), GetServerTime()) end
    return global.shareId
end

---A snapshot as sent: { id, zones } as CBOR, deflated, in Base64.
---@param id string
---@param zones AddonZones
---@return string
function Addon.EncodeSnapshot(id, zones)
    local cbor = C_EncodingUtil.SerializeCBOR({ id = id, zones = zones })
    return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(cbor))
end

---Only the counts of what arrived: number map IDs, number or text areas, number item IDs with
---counts above 0. Nil when nothing is left.
---@param zones GameValue
---@return AddonZones?
local function CleanZones(zones)
    if type(zones) ~= "table" then return nil end
    local clean, any = {}, false
    ---@type GameValue, GameValue
    for mapID, zone in
        pairs(zones --[[@as table<GameValue, GameValue>]])
    do
        if type(mapID) == "number" and type(zone) == "table" then
            ---@type GameValue, GameValue
            for area, counts in
                pairs(zone --[[@as table<GameValue, GameValue>]])
            do
                local areaType = type(area)
                if (areaType == "number" or areaType == "string") and type(counts) == "table" then
                    ---@type GameValue, GameValue
                    for itemID, count in
                        pairs(counts --[[@as table<GameValue, GameValue>]])
                    do
                        if type(itemID) == "number" and type(count) == "number" and count > 0 then
                            clean[mapID] = clean[mapID] or {}
                            clean[mapID][area] = clean[mapID][area] or {}
                            clean[mapID][area][itemID] = count
                            any = true
                        end
                    end
                end
            end
        end
    end
    return any and clean --[[@as AddonZones]] or nil
end

---A snapshot as it arrived: its account ID and its counts, or nil for anything broken.
---@param text string
---@return string? id
---@return AddonZones? zones
function Addon.DecodeSnapshot(text)
    ---@return GameValue
    local function Decode()
        local deflated = C_EncodingUtil.DecodeBase64(text)
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(deflated)) --[[@as GameValue]]
    end
    local ok, value = pcall(Decode)
    if not ok or type(value) ~= "table" then return nil, nil end
    local snapshot = value --[[@as { id: GameValue, zones: GameValue }]]
    local id = snapshot.id
    if type(id) ~= "string" then return nil, nil end
    local zones = CleanZones(snapshot.zones)
    if not zones then return nil, nil end
    return id, zones
end

---Every character of the account's counts together, for a snapshot.
---@return AddonZones
local function AccountZones()
    local zones = {}
    for _, char in pairs(Addon.db.global.chars) do
        for mapID, zone in pairs(char.zones) do
            for area, counts in pairs(zone) do
                for itemID, count in pairs(counts) do
                    zones[mapID] = zones[mapID] or {}
                    zones[mapID][area] = zones[mapID][area] or {}
                    zones[mapID][area][itemID] = (zones[mapID][area][itemID] or 0) + count
                end
            end
        end
    end
    return zones --[[@as AddonZones]]
end

---Whether the addon may talk to the guild now.
---@return boolean
local function Sharing()
    return Addon.db.profile.share and IsInGuild() and true or false
end

---Sends the account's counts to the guild, unless one went out less than 5 minutes ago.
function Addon:SendSnapshot()
    if not Sharing() or GetTime() - lastSnapshot < SNAPSHOT_GAP then return end
    lastSnapshot = GetTime()
    self:SendCommMessage(
        self.COMM_PREFIX,
        SNAPSHOT .. self.EncodeSnapshot(self:ShareId(), AccountZones()),
        CHANNEL,
        nil,
        "BULK"
    )
end

local function AnswerHello()
    Addon:SendSnapshot()
end

---A guildmate's message: a hello is answered a few seconds later; a snapshot is kept under its
---account ID. The player's own messages, and anything not from the guild, are left alone.
---@param prefix string
---@param message string
---@param channel string
---@param sender string
function Addon:OnCommReceived(prefix, message, channel, sender)
    if prefix ~= self.COMM_PREFIX or channel ~= CHANNEL or not self.db.profile.share then return end
    if Ambiguate(sender, "none") == UnitName("player") then return end
    local kind = message:sub(1, 1)
    if kind == HELLO then
        C_Timer.After(math.random(ANSWER_MIN, ANSWER_MAX), AnswerHello)
    elseif kind == SNAPSHOT then
        local id, zones = self.DecodeSnapshot(message:sub(2))
        if not id or id == self:ShareId() then return end
        self.db.global.guild[id] = {
            name = sender,
            zones = zones --[[@as AddonZones]],
            t = GetServerTime(),
        }
        self:LogChanged()
        self:UpdateCatchWindow()
    end
end

local function SayHello()
    if Sharing() then Addon:SendCommMessage(Addon.COMM_PREFIX, HELLO, CHANNEL) end
end

---Listens to the guild, and says hello once the client has settled after login.
function Addon:SetupShare()
    self:RegisterComm(self.COMM_PREFIX)
    C_Timer.After(HELLO_DELAY, SayHello)
end
