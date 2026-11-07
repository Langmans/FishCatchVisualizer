-- A simulated WoW: Forever client: the API FishCatchVisualizer and the Ace3 libraries touch, with
-- every value a test may want to vary exposed on the client object. NewClient() resets the globals
-- and loads the .toc's files (Ace3 included) into a fresh namespace, so tests never share state.
-- The load order and the .toc's metadata come from tests/helper.lua (TOC_FILES, TOC_METADATA,
-- TOC_SAVED). The frame and Ace3 plumbing follows BattleCry's tests/wow.lua.

-- What a hidden value looks like to the addon: only issecretvalue tells it apart.
SECRET = setmetatable({}, {
    __tostring = function()
        return "<secret>"
    end,
})

-- The test world: item, map and area IDs. The fish and the pole are real Classic items; the map IDs
-- are the game's uiMapIDs; the area IDs are made up, only their names matter to the addon.
ITEMS = {
    snapper = 6289, -- Raw Longjaw Mud Snapper
    smallfish = 6291, -- Raw Brilliant Smallfish
    sickly = 6299, -- Sickly Looking Fish
    pole = 6256, -- Fishing Pole
    sword = 2488, -- a one-handed sword
}
MAPS = { elwynn = 1429, westfall = 1436 }
AREAS = { crystalLake = 9001, stoneCairn = 9002, daggerHills = 9003, goldshire = 9004 }

-- What the client knows about each item: its name, class and subclass, icon, quality (0 poor,
-- 1 common).
local ITEM_INFO = {
    [ITEMS.snapper] = { name = "Raw Longjaw Mud Snapper", class = 7, subclass = 8, icon = 133888, quality = 1 },
    [ITEMS.smallfish] = { name = "Raw Brilliant Smallfish", class = 7, subclass = 8, icon = 133890, quality = 1 },
    [ITEMS.sickly] = { name = "Sickly Looking Fish", class = 0, subclass = 0, icon = 133891, quality = 0 },
    [ITEMS.pole] = { name = "Fishing Pole", class = 2, subclass = 20, icon = 132932 },
    [ITEMS.sword] = { name = "Shortsword", class = 2, subclass = 7, icon = 135274 },
}
local MAP_NAMES = { [MAPS.elwynn] = "Elwynn Forest", [MAPS.westfall] = "Westfall" }
local AREA_NAMES = {
    [AREAS.crystalLake] = "Crystal Lake",
    [AREAS.stoneCairn] = "Stone Cairn Lake",
    [AREAS.daggerHills] = "The Dagger Hills",
    [AREAS.goldshire] = "Goldshire",
}

---A file's source as the client gets it: from a release, where the packager comments out every line
---between `--@debug@` and `--@end-debug@`, unless `dev` (a copy straight from the repository).
---The line count stays, so coverage still points at the right lines.
---@param file string
---@param dev boolean
---@return string
local function AsPackaged(file, dev)
    local handle = assert(io.open(file, "rb"))
    local source = handle:read("*a")
    handle:close()
    if dev or not source:find("--@debug@", 1, true) then return source end
    local lines, inDebug = {}, false
    for line in (source .. "\n"):gmatch("(.-)\r?\n") do
        if line:match("^%s*%-%-@end%-debug@") then
            inDebug = false
        elseif inDebug then
            line = "--" .. line
        elseif line:match("^%s*%-%-@debug@") then
            inDebug = true
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

---Compiled once per run and kind of copy: a file's chunk runs again for every client, each time
---from the top.
---@type table<string, function>
local chunks = {}
---@param file string
---@param dev boolean
---@return function
local function Chunk(file, dev)
    local key = (dev and "dev:" or "release:") .. file
    chunks[key] = chunks[key] or assert(loadstring(AsPackaged(file, dev), "@" .. file))
    return chunks[key]
end

---Packs varargs with their count, nils included (Lua 5.1 has no table.pack).
local function pack(...)
    return { n = select("#", ...), ... }
end

-- WoW's Lua 5.1 passes xpcall's extra arguments on to the function, as Lua 5.2 does; plain 5.1
-- drops them. Ace3 relies on it (AceAddon calls OnInitialize as xpcall(func, handler, addon)).
local plainXpcall = xpcall
function xpcall(func, handler, ...)
    local args = pack(...)
    return plainXpcall(function()
        return func(unpack(args, 1, args.n))
    end, handler)
end

---@class TestClientOptions
---@field saved table? FishCatchVisualizerDB as the saved file left it
---@field locale string? the client's language (GetLocale), enUS by default
---@field noTooltipData boolean? a client without TooltipDataProcessor
---@field addonName string? the addon's folder name, FishCatchVisualizer by default: every name it shows the game comes from it
---@field dev boolean? a copy straight from the repository: `--@debug@` blocks run (Core\Dev.lua)

---@param opts TestClientOptions?
function NewClient(opts)
    opts = opts or {}
    local addonName = opts.addonName or "FishCatchVisualizer"
    local function noop() end
    local client = {
        time = 100,
        serverTime = 1794000000,
        frames = {},
        printed = {},
        errors = {},
        loggedIn = false,
        inCombat = false,
        -- Where the player stands: a uiMapID (nil: the client cannot tell), the subzone text.
        mapID = MAPS.elwynn,
        subzone = "Crystal Lake",
        -- The item in the main hand, nil for none.
        mainHand = nil,
        -- The open loot window: whether it is fishing loot, and its slots
        -- ({ itemID, quantity, type, link, name }; type 1 item, 2 money).
        fishingLoot = false,
        loot = {},
        areaLookups = 0,
    }

    function GetLocale()
        return opts.locale or "enUS"
    end
    function GetTime()
        return client.time
    end
    function GetServerTime()
        return client.serverTime
    end
    -- The server's time of day (client.hour, client.minute) and date (client.month).
    client.hour, client.minute, client.month = 12, 0, 11
    function GetGameTime()
        return client.hour, client.minute
    end
    C_DateAndTime = {
        GetCurrentCalendarTime = function()
            return { year = 2026, month = client.month, monthDay = 7, weekday = 7, hour = client.hour, minute = 0 }
        end,
    }
    -- client.screenshots: how many screenshots were taken.
    client.screenshots = 0
    function Screenshot()
        client.screenshots = client.screenshots + 1
    end
    function IsLoggedIn()
        return client.loggedIn
    end
    -- An error the addon or a library reports without raising is kept for the test to check.
    function geterrorhandler()
        return function(err)
            client.errors[#client.errors + 1] = tostring(err)
        end
    end
    function securecallfunction(func, ...)
        return func(...)
    end
    function hooksecurefunc(target, name, hook)
        if type(target) ~= "table" then
            target, name, hook = _G, target, name
        end
        local original = target[name]
        target[name] = function(...)
            local results = pack(original(...))
            hook(...)
            return unpack(results, 1, results.n)
        end
    end
    function InCombatLockdown()
        return client.inCombat
    end
    C_EventUtils = {
        IsEventValid = function()
            return true
        end,
    }
    function issecretvalue(value)
        return value == SECRET
    end

    -- The player, as AceDB names its profile.
    function UnitName()
        return "Fisher"
    end
    UnitNameUnmodified = UnitName
    function UnitClass()
        return "Hunter", "HUNTER"
    end
    function UnitRace()
        return "Human", "Human", 1
    end
    function UnitFactionGroup()
        return "Alliance", "Alliance"
    end
    function GetRealmName()
        return "Doomhowl"
    end
    function GetCurrentRegion()
        return 3
    end
    function GetCurrentRegionName()
        return "EU"
    end

    Enum = {
        LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
        ItemClass = { Consumable = 0, Weapon = 2, Tradegoods = 7 },
        ItemWeaponSubclass = { Sword1H = 7, Fishingpole = 20 },
        TooltipDataType = { Item = 0, Spell = 1 },
        SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, NotInGuild = 10, AddOnMessageLockdown = 11 },
    }
    INVSLOT_MAINHAND = 16

    -- Addon messages. client.addonSent: every one sent, { prefix, text, channel }; client.inGuild:
    -- whether the player is in a guild. ChatThrottleLib (AceComm) also hooks the chat send.
    client.addonSent, client.inGuild = {}, false
    function IsInGuild()
        return client.inGuild
    end
    function Ambiguate(name)
        return name
    end
    function GetFramerate()
        return 60
    end
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function()
            return true
        end,
        SendAddonMessage = function(prefix, text, channel)
            client.addonSent[#client.addonSent + 1] = { prefix, text, channel }
            return Enum.SendAddonMessageResult.Success
        end,
        SendAddonMessageLogged = function()
            return Enum.SendAddonMessageResult.Success
        end,
        SendChatMessage = noop,
    }

    -- The client's encoding: Base64 as the game does it; CBOR and Deflate stand-ins that only this
    -- client reads back (as BattleCry's tests have them). Serialize keeps a copy under a token,
    -- Compress marks its input, and each reader raises on what it did not make, as the game's do.
    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local serialized = {}
    local function deepCopy(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for k, v in pairs(value) do
            copy[k] = deepCopy(v)
        end
        return copy
    end
    C_EncodingUtil = {
        EncodeBase64 = function(source)
            return (
                (source:gsub(".", function(char)
                    local byte, bits = char:byte(), ""
                    for i = 8, 1, -1 do
                        bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0")
                    end
                    return bits
                end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
                    if #bits < 6 then return "" end
                    local n = 0
                    for i = 1, 6 do
                        n = n + (bits:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
                    end
                    return B64:sub(n + 1, n + 1)
                end) .. ({ "", "==", "=" })[#source % 3 + 1]
            )
        end,
        DecodeBase64 = function(source)
            if source:find("[^%w%+/=]") then error("not Base64") end
            source = source:gsub("=", "")
            return (
                source
                    :gsub(".", function(char)
                        local n, bits = B64:find(char, 1, true) - 1, ""
                        for i = 6, 1, -1 do
                            bits = bits .. (n % 2 ^ i - n % 2 ^ (i - 1) > 0 and "1" or "0")
                        end
                        return bits
                    end)
                    :gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
                        if #bits ~= 8 then return "" end
                        local n = 0
                        for i = 1, 8 do
                            n = n + (bits:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
                        end
                        return string.char(n)
                    end)
            )
        end,
        CompressString = function(source)
            return "deflated:" .. source
        end,
        DecompressString = function(source)
            local plain = source:match("^deflated:(.*)$")
            if not plain then error("not deflated") end
            return plain
        end,
        SerializeCBOR = function(value)
            serialized[#serialized + 1] = deepCopy(value)
            return "cbor:" .. #serialized
        end,
        DeserializeCBOR = function(source)
            local index = tonumber(source:match("^cbor:(%d+)$"))
            if not index then error("not CBOR") end
            return deepCopy(serialized[index])
        end,
    }

    -- Places. client.mapID and client.subzone say where the player stands; the zone's name comes
    -- from the map. client.areaLookups counts C_Map.GetAreaInfo calls.
    C_Map = {
        GetBestMapForUnit = function(unit)
            assert(unit == "player", "only the player's map is asked")
            return client.mapID
        end,
        GetMapInfo = function(mapID)
            local name = MAP_NAMES[mapID]
            if name then return { mapID = mapID, name = name } end
        end,
        GetAreaInfo = function(areaID)
            client.areaLookups = client.areaLookups + 1
            return AREA_NAMES[areaID]
        end,
    }
    function GetZoneText()
        return MAP_NAMES[client.mapID] or ""
    end
    function GetSubZoneText()
        return client.subzone
    end

    -- Items: what C_Item tells about the items in ITEM_INFO.
    local function idOf(item)
        if type(item) == "number" then return item end
        return tonumber(tostring(item):match("item:(%d+)"))
    end
    C_Item = {
        GetItemInfoInstant = function(item)
            local id = idOf(item)
            local info = ITEM_INFO[id]
            if not info then return nil end
            return id, "", "", "", info.icon, info.class, info.subclass
        end,
        GetItemIconByID = function(item)
            local info = ITEM_INFO[idOf(item)]
            return info and info.icon
        end,
        GetItemNameByID = function(item)
            local info = ITEM_INFO[idOf(item)]
            return info and info.name
        end,
        GetItemQualityByID = function(item)
            local info = ITEM_INFO[idOf(item)]
            return info and info.quality
        end,
    }
    function GetInventoryItemID(unit, slot)
        assert(unit == "player")
        if slot == INVSLOT_MAINHAND then return client.mainHand end
    end

    -- Loot: client.loot and client.fishingLoot.
    function IsFishingLoot()
        return client.fishingLoot
    end
    function GetNumLootItems()
        return #client.loot
    end
    function GetLootSlotType(slot)
        local entry = client.loot[slot]
        return entry and entry.type or Enum.LootSlotType.None
    end
    function GetLootSlotLink(slot)
        local entry = client.loot[slot]
        if not entry or entry.type ~= Enum.LootSlotType.Item then return nil end
        return entry.link
    end
    function GetLootSlotInfo(slot)
        local entry = client.loot[slot]
        if not entry then return nil end
        return entry.icon, entry.name, entry.quantity
    end

    -- Every file a font or texture names is known to this client.
    C_UIFileAsset = {
        IsKnownFile = function()
            return true
        end,
    }

    -- The client's bit library (LibSharedMedia masks locales with it); plain Lua 5.1 has none.
    bit = {
        band = function(a, b)
            local result, place = 0, 1
            while a > 0 and b > 0 do
                if a % 2 == 1 and b % 2 == 1 then result = result + place end
                a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
            end
            return result
        end,
    }

    -- WoW's string and table shorthands.
    strmatch, strfind, strsub, strlower, strupper, strlen, format, gsub =
        string.match, string.find, string.sub, string.lower, string.upper, string.len, string.format, string.gsub
    tinsert, tremove, tconcat = table.insert, table.remove, table.concat
    min, max, floor = math.min, math.max, math.floor
    function strtrim(text, chars)
        chars = chars or " \t\r\n"
        local class = "[" .. chars:gsub("[%]%%%-%^]", "%%%0") .. "]"
        return (text:gsub("^" .. class .. "+", ""):gsub(class .. "+$", ""))
    end
    function strsplit(sep, text, limit)
        local parts, start = {}, 1
        while true do
            if limit and #parts == limit - 1 then break end
            local at = text:find(sep, start, true)
            if not at then break end
            parts[#parts + 1] = text:sub(start, at - 1)
            start = at + #sep
        end
        parts[#parts + 1] = text:sub(start)
        return unpack(parts)
    end
    string.split = strsplit
    -- Characters, not bytes. AceDB measures profile names with it.
    function strlenutf8(text)
        return select(2, text:gsub("[^\128-\191]", ""))
    end
    function strjoin(sep, ...)
        return table.concat({ ... }, sep)
    end
    function wipe(tbl)
        for key in pairs(tbl) do
            tbl[key] = nil
        end
        return tbl
    end
    table.wipe = wipe
    function tostringall(...)
        local out = pack(...)
        for i = 1, out.n do
            out[i] = tostring(out[i])
        end
        return unpack(out, 1, out.n)
    end

    -- Frames: a frame keeps its events, scripts, shown state, points, size, scale, colours and
    -- text; any other capitalised method is a no-op.
    local Region = {}
    Region.__index = function(_, key)
        if Region[key] then return Region[key] end
        if type(key) == "string" and key:match("^%u") then return noop end
    end
    function Region:Show()
        self.shown = true
    end
    -- Hiding a shown frame runs its OnHide script and hooks, as on the client.
    function Region:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
        for _, hook in ipairs(self.hooks.OnHide or {}) do
            hook(self)
        end
    end
    function Region:SetShown(shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end
    function Region:IsShown()
        return self.shown
    end
    function Region:SetResizeBounds(minWidth, minHeight)
        self.resizeBounds = { minWidth, minHeight }
    end
    function Region:RegisterEvent(event)
        self.events[event] = true
    end
    function Region:RegisterUnitEvent(event, unit)
        self.events[event] = unit
    end
    function Region:UnregisterEvent(event)
        self.events[event] = nil
    end
    function Region:UnregisterAllEvents()
        self.events = {}
    end
    function Region:IsEventRegistered(event)
        return self.events[event] ~= nil
    end
    function Region:SetScript(script, handler)
        self.scripts[script] = handler
    end
    function Region:GetScript(script)
        return self.scripts[script]
    end
    function Region:HookScript(script, handler)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], handler)
    end
    function Region:GetName()
        return self.name
    end
    function Region:GetParent()
        return self.parent
    end
    -- Sizes and positions: what was set, else a plausible number, so layout code that does
    -- arithmetic on them (AceGUI's) runs.
    function Region:SetWidth(width)
        self.width = width
    end
    function Region:SetHeight(height)
        self.height = height
    end
    function Region:SetSize(width, height)
        self.width, self.height = width, height
    end
    function Region:GetWidth()
        return self.width or 100
    end
    function Region:GetHeight()
        return self.height or 20
    end
    function Region:GetSize()
        return self:GetWidth(), self:GetHeight()
    end
    for _, getter in ipairs({
        "GetTop",
        "GetBottom",
        "GetLeft",
        "GetRight",
        "GetStringWidth",
        "GetStringHeight",
        "GetFrameLevel",
        "GetNumPoints",
    }) do
        Region[getter] = function()
            return 0
        end
    end
    function Region:GetEffectiveScale()
        return 1
    end
    function Region:SetScale(scale)
        self.scale = scale
    end
    function Region:GetScale()
        return self.scale or 1
    end
    function Region:SetAlpha(alpha)
        self.alpha = alpha
    end
    -- Points: every SetPoint since the last ClearAllPoints, { point, relativeTo, relativePoint,
    -- x, y }. GetPoint gives the first, as the client does for a frame with one point.
    function Region:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points = self.points or {}
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    function Region:ClearAllPoints()
        self.points = {}
    end
    function Region:GetPoint(index)
        local p = self.points and self.points[index or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    function Region:EnableMouse(on)
        self.mouse = on
    end
    function Region:SetBackdropColor(r, g, b, a)
        self.backdropColor = { r, g, b, a }
    end
    function Region:GetText()
        return self.text
    end
    function Region:SetText(text)
        self.text = text
    end
    function Region:SetFormattedText(pattern, ...)
        self.text = pattern:format(...)
    end
    function Region:SetTextColor(r, g, b)
        self.textColor = { r, g, b }
    end
    -- A font string's font: { path, size, flags }, and its shadow offset { x, y }.
    function Region:SetFont(path, size, flags)
        self.font = { path, size, flags }
        return true
    end
    function Region:SetShadowOffset(x, y)
        self.shadowOffset = { x, y }
    end
    function Region:SetShadowColor(r, g, b, a)
        self.shadowColor = { r, g, b, a }
    end

    -- The item quality colours as the client has them (ColorUtil), for poor and common.
    ITEM_QUALITY_COLORS = {
        [0] = { r = 0.62, g = 0.62, b = 0.62, hex = "|cff9d9d9d" },
        [1] = { r = 1, g = 1, b = 1, hex = "|cffffffff" },
    }
    -- A ColorMixin as CreateColor makes it, as far as LibEditMode's colour picker uses it.
    function CreateColor(r, g, b, a)
        return {
            r = r,
            g = g,
            b = b,
            a = a or 1,
            GetRGB = function(self)
                return self.r, self.g, self.b
            end,
            GetRGBA = function(self)
                return self.r, self.g, self.b, self.a
            end,
        }
    end
    function Region:SetTexture(texture)
        self.texture = texture
    end
    -- A status bar's value, as the bar rows fill it.
    function Region:SetValue(value)
        self.value = value
    end
    local function newRegion(fields)
        fields = fields or {}
        fields.shown = true
        fields.events, fields.scripts, fields.hooks = {}, {}, {}
        return setmetatable(fields, Region)
    end
    function Region:CreateTexture()
        return newRegion({ parent = self, kind = "Texture" })
    end
    function Region:CreateFontString()
        return newRegion({ parent = self, kind = "FontString" })
    end
    function Region:CreateAnimationGroup()
        return newRegion()
    end
    function Region:CreateAnimation()
        return newRegion()
    end
    -- A button's textures and label, made on first ask, as AceGUI's widgets style them.
    for _, getter in ipairs({
        "GetNormalTexture",
        "GetPushedTexture",
        "GetHighlightTexture",
        "GetDisabledTexture",
        "GetCheckedTexture",
        "GetFontString",
    }) do
        Region[getter] = function(self)
            local key = "_" .. getter
            if not rawget(self, key) then rawset(self, key, newRegion()) end
            return rawget(self, key)
        end
    end

    -- The named children a template makes ($parentLeft and so on), for templates whose children
    -- Ace3 looks up by global name.
    local TEMPLATE_CHILDREN = {
        UIDropDownMenuTemplate = { "Left", "Middle", "Right", "Button", "Text" },
    }

    function CreateFrame(kind, name, parent, template)
        local frame = newRegion({ kind = kind, name = name, parent = parent, template = template })
        client.frames[#client.frames + 1] = frame
        if name then _G[name] = frame end
        for _, suffix in ipairs(name and TEMPLATE_CHILDREN[template] or {}) do
            _G[name .. suffix] = newRegion({ name = name .. suffix })
        end
        return frame
    end
    UIParent = newRegion({ name = "UIParent" })
    WorldFrame = newRegion()

    -- The game's tooltip. client.tooltipLines: the lines added since the last hover, { left, right }
    -- each (right nil for a single line).
    GameTooltip = newRegion({ name = "GameTooltip" })
    client.tooltipLines = {}
    function GameTooltip:AddLine(text)
        client.tooltipLines[#client.tooltipLines + 1] = { text }
    end
    function GameTooltip:AddDoubleLine(left, right)
        client.tooltipLines[#client.tooltipLines + 1] = { left, right }
    end
    -- TooltipDataProcessor: the post-calls registered per tooltip data type; client:hoverItem runs
    -- them. opts.noTooltipData: a client without it.
    client.tooltipPostCalls = {}
    TooltipDataProcessor = not opts.noTooltipData
            and {
                AddTooltipPostCall = function(dataType, callback)
                    client.tooltipPostCalls[dataType] = client.tooltipPostCalls[dataType] or {}
                    table.insert(client.tooltipPostCalls[dataType], callback)
                end,
            }
        or nil

    -- Global strings and constants the Ace3 GUI reads.
    FONT_COLOR_CODE_CLOSE, NORMAL_FONT_COLOR_CODE = "|r", "|cffffd200"
    NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
    ACCEPT, CANCEL, CLOSE, OKAY, NOT_BOUND, YES, NO = "Accept", "Cancel", "Close", "Okay", "Not Bound", "Yes", "No"
    WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_CAMELOT = 1, 2, 18
    WOW_PROJECT_ID = WOW_PROJECT_CAMELOT

    -- The settings window. client.categories: every page added, by ID; client.pageNames: their
    -- names in the order they were added; client.opened: the IDs opened.
    client.categories, client.pageNames, client.opened = {}, {}, {}
    local nextID = 1
    local function newCategory(frame, name, parent)
        local category = { frame = frame, name = name, parent = parent, ID = nextID }
        nextID = nextID + 1
        function category:GetID()
            return self.ID
        end
        return category
    end
    Settings = {
        RegisterCanvasLayoutCategory = newCategory,
        RegisterCanvasLayoutSubcategory = function(parent, frame, name)
            local category = newCategory(frame, name, parent)
            client.categories[category.ID] = category
            client.pageNames[#client.pageNames + 1] = name
            return category
        end,
        RegisterAddOnCategory = function(category)
            client.categories[category.ID] = category
            client.pageNames[#client.pageNames + 1] = category.name
        end,
        GetCategory = function(id)
            return client.categories[id]
        end,
        OpenToCategory = function(id)
            client.opened[#client.opened + 1] = id
        end,
    }

    -- client.timers: pending C_Timer callbacks; client:advance runs the ones that come due.
    client.timers = {}
    C_Timer = {
        After = function(seconds, callback)
            client.timers[#client.timers + 1] = { at = client.time + seconds, callback = callback }
        end,
    }

    -- client.printed: every chat line, whether through print or the default chat frame.
    DEFAULT_CHAT_FRAME = newRegion()
    function DEFAULT_CHAT_FRAME:AddMessage(text)
        client.printed[#client.printed + 1] = text
    end
    function print(...)
        client.printed[#client.printed + 1] = table.concat({ tostringall(...) }, " ")
    end

    C_AddOns = {
        GetAddOnMetadata = function(name, key)
            if name == addonName then return TOC_METADATA[key] end
        end,
        IsAddOnLoaded = function()
            return false, false
        end,
    }

    SlashCmdList = {}
    hash_SlashCmdList = {}
    _G[TOC_SAVED] = opts.saved

    -- LibEditMode drives Blizzard's Edit Mode, which this client does not have; a stand-in with
    -- the same calls takes its place. client.editMode: the frames added, their default position,
    -- settings and move callback, and the layout callbacks. client:loadLayout, :enterEditMode,
    -- :exitEditMode and :moveInEditMode act as the game would.
    local editMode = {
        frames = {},
        layout = {},
        enter = {},
        exit = {},
        active = nil,
        SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2, ColorPicker = 10 },
    }
    client.editMode = editMode
    function editMode:AddFrame(frame, callback, default, name)
        self.frames[frame] = { callback = callback, default = default, name = name, settings = {} }
    end
    function editMode:AddFrameSettings(frame, settings)
        assert(self.frames[frame], "frame must be registered")
        self.frames[frame].settings = settings
    end
    function editMode:RegisterCallback(event, callback)
        table.insert(self[event], callback)
        if event == "layout" and self.active then callback(self.active) end
    end
    function editMode:GetActiveLayoutName()
        return self.active
    end
    ---The game loads an Edit Mode layout (at login, or the player picks another).
    function client:loadLayout(name)
        editMode.active = name
        for _, callback in ipairs(editMode.layout) do
            callback(name)
        end
        return self
    end
    function client:enterEditMode()
        for _, callback in ipairs(editMode.enter) do
            callback()
        end
        return self
    end
    function client:exitEditMode()
        for _, callback in ipairs(editMode.exit) do
            callback()
        end
        return self
    end
    ---The player drags a frame in Edit Mode; LibEditMode then anchors it to UIParent.
    function client:moveInEditMode(frame, point, x, y)
        frame:ClearAllPoints()
        frame:SetPoint(point, x, y)
        editMode.frames[frame].callback(frame, editMode.active, point, x, y)
        return self
    end
    ---A setting of a frame's Edit Mode dialog, by name.
    function client:editModeSetting(frame, name)
        for _, setting in ipairs(editMode.frames[frame].settings) do
            if setting.name == name then return setting end
        end
    end

    -- LibStub keeps its libraries in a global; a fresh client starts without one.
    LibStub = nil
    local ns = {}
    for _, file in ipairs(TOC_FILES) do
        local path = file:gsub("^%./", "")
        if not path:match("^Libs/LibEditMode/") then Chunk(file, opts.dev == true)(addonName, ns) end
        if path == "Libs/LibStub/LibStub.lua" then
            local lib = LibStub:NewLibrary("LibEditMode", 1)
            for key, value in pairs(editMode) do
                lib[key] = value
            end
            client.editMode, editMode = lib, lib
        end
    end
    -- client.Addon: the addon object, which is also the namespace the client hands its files.
    client.Addon = ns

    ---Delivers an event to every frame registered for it.
    function client:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
        return self
    end

    ---Moves the clock on and runs the C_Timer callbacks that came due.
    function client:advance(seconds)
        self.time = self.time + seconds
        local due = {}
        for i = #self.timers, 1, -1 do
            if self.timers[i].at <= self.time then table.insert(due, 1, table.remove(self.timers, i)) end
        end
        for _, timer in ipairs(due) do
            timer.callback()
        end
        return self
    end

    ---The next frame drawn: every shown frame's OnUpdate runs (AceConfigDialog closes its window
    ---there).
    function client:nextFrame()
        for _, frame in ipairs(self.frames) do
            local onUpdate = frame.scripts.OnUpdate
            if frame.shown and onUpdate then onUpdate(frame, 0.016) end
        end
        return self
    end

    ---What the client does at login: ADDON_LOADED, PLAYER_LOGIN, then the loading screen ends.
    function client:login()
        self:fire("ADDON_LOADED", "SomeOtherAddon")
        self:fire("ADDON_LOADED", addonName)
        self.loggedIn = true
        self:fire("PLAYER_LOGIN")
        self:fire("PLAYER_ENTERING_WORLD", true, false)
        return self
    end

    ---What the client does at logout: AceDB strips the defaults from the saved table.
    function client:logout()
        return self:fire("PLAYER_LOGOUT")
    end

    ---Puts an item in the main hand (nil empties it): PLAYER_EQUIPMENT_CHANGED for that slot.
    ---@param itemID number?
    function client:equip(itemID)
        self.mainHand = itemID
        return self:fire("PLAYER_EQUIPMENT_CHANGED", INVSLOT_MAINHAND, itemID ~= nil)
    end

    ---Walks into a subzone ("" for none) of a map: ZONE_CHANGED_NEW_AREA when the map changes,
    ---else ZONE_CHANGED.
    ---@param mapID number?
    ---@param subzone string
    function client:moveTo(mapID, subzone)
        local newArea = mapID ~= self.mapID
        self.mapID, self.subzone = mapID, subzone
        return self:fire(newArea and "ZONE_CHANGED_NEW_AREA" or "ZONE_CHANGED")
    end

    ---A loot window opens: fishing loot unless `notFishing`. Each slot is an item ID (one of it),
    ---{ itemID, quantity }, or "money". Then the window closes.
    ---@param slots (number|table|string)[]
    ---@param notFishing boolean?
    function client:loots(slots, notFishing)
        self.fishingLoot = not notFishing
        self.loot = {}
        for i, slot in ipairs(slots) do
            if slot == "money" then
                self.loot[i] = { type = Enum.LootSlotType.Money, name = "12 Copper", quantity = 0 }
            else
                local id, quantity = slot, 1
                if type(slot) == "table" then
                    id, quantity = slot[1], slot[2]
                end
                local info = ITEM_INFO[id]
                self.loot[i] = {
                    type = Enum.LootSlotType.Item,
                    link = ("|cffffffff|Hitem:%d::::::::30:::::|h[%s]|h|r"):format(id, info.name),
                    name = info.name,
                    icon = info.icon,
                    quantity = quantity,
                }
            end
        end
        self:fire("LOOT_OPENED", false, false)
        self.fishingLoot, self.loot = false, {}
        return self:fire("LOOT_CLOSED")
    end

    ---Fishes up each item in turn, one loot window each.
    ---@param ... number item IDs
    function client:catch(...)
        for i = 1, select("#", ...) do
            self:loots({ (select(i, ...)) })
        end
        return self
    end

    ---The mouse over an item: GameTooltip is filled for it and the item post-calls run.
    ---@param itemID any a number, or SECRET
    function client:hoverItem(itemID)
        self.tooltipLines = {}
        for _, callback in ipairs(self.tooltipPostCalls[Enum.TooltipDataType.Item] or {}) do
            callback(GameTooltip, { type = Enum.TooltipDataType.Item, id = itemID })
        end
        return self.tooltipLines
    end

    ---Runs a line of the addon's slash command the way the chat box does; `command` picks another
    ---of its commands (the alias), the addon's own name by default.
    function client:slash(message, command)
        SlashCmdList["ACECONSOLE_" .. (command or addonName):upper()](message)
        return self
    end

    ---The texts of the addon messages sent so far with the addon's prefix, to the guild.
    ---@return string[]
    function client:guildSent()
        local out = {}
        for _, sent in ipairs(self.addonSent) do
            if sent[1] == self.Addon.COMM_PREFIX and sent[3] == "GUILD" then out[#out + 1] = sent[2] end
        end
        return out
    end

    ---A guildmate's addon message arrives, whole, as AceComm hands it over (`channel` GUILD by
    ---default).
    ---@param text string
    ---@param sender string
    ---@param channel string?
    function client:receive(text, sender, channel)
        self.Addon:OnCommReceived(self.Addon.COMM_PREFIX, text, channel or "GUILD", sender)
        return self
    end

    function client:printedContains(text)
        for _, line in ipairs(self.printed) do
            if line:find(text, 1, true) then return true end
        end
        return false
    end

    return client
end

function Saved()
    return _G[TOC_SAVED]
end
