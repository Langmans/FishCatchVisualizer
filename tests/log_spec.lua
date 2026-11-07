-- The catch log (Core\Detect.lua, Core\Log.lua): what counts as a catch, where it is kept, the
-- sessions, and the counts the window and the tooltip read.

local CHAR = "Fisher - Doomhowl"

---A logged-in client with a fishing pole in hand.
local function fishing(opts)
    return NewClient(opts):login():equip(ITEMS.pole)
end

---This character's count of an item at a place.
local function count(client, mapID, area, itemID)
    local char = client.Addon.db.global.chars[CHAR]
    local zones = char and char.zones
    return zones and zones[mapID] and zones[mapID][area] and zones[mapID][area][itemID]
end

describe("the catch log", function()
    it("counts a fished item for this character at the map and subzone", function()
        local client = fishing():catch(ITEMS.snapper, ITEMS.snapper, ITEMS.smallfish)
        assert.are.equal(2, count(client, MAPS.elwynn, AREAS.crystalLake, ITEMS.snapper))
        assert.are.equal(1, count(client, MAPS.elwynn, AREAS.crystalLake, ITEMS.smallfish))
        assert.are.equal("Raw Longjaw Mud Snapper", client.Addon.db.global.items[ITEMS.snapper])
        assert.are.same({}, client.errors)
    end)

    it("counts the stack, every item of the window, and no money", function()
        local client = fishing()
        client:loots({ { ITEMS.smallfish, 3 }, ITEMS.sickly, "money" })
        assert.are.equal(3, count(client, MAPS.elwynn, AREAS.crystalLake, ITEMS.smallfish))
        assert.are.equal(1, count(client, MAPS.elwynn, AREAS.crystalLake, ITEMS.sickly))
    end)

    it("leaves loot that is not from fishing alone", function()
        local client = fishing()
        client:loots({ ITEMS.snapper }, true)
        assert.is_nil(client.Addon.db.global.chars[CHAR])
    end)

    it("skips a slot the client hides and a catch where the map is unknown", function()
        local client = fishing()
        client.mapID = nil
        client:catch(ITEMS.snapper)
        assert.is_nil(client.Addon.db.global.chars[CHAR])
        client.mapID = MAPS.elwynn
        -- Through _G: busted gives each spec file its own globals.
        local original = _G.GetLootSlotLink
        _G.GetLootSlotLink = function()
            return SECRET
        end
        client:catch(ITEMS.snapper)
        _G.GetLootSlotLink = original
        assert.is_nil(count(client, MAPS.elwynn, AREAS.crystalLake, ITEMS.snapper))
        assert.are.same({}, client.errors)
    end)

    it("tells other addons about each catch", function()
        local client = fishing()
        local heard = {}
        LibStub("AceEvent-3.0"):Embed(heard)
        heard:RegisterMessage(client.Addon.messages.catch, function(_, itemID, quantity, mapID, area)
            heard[#heard + 1] = { itemID, quantity, mapID, area }
        end)
        client:loots({ { ITEMS.smallfish, 2 } })
        assert.are.same({ { ITEMS.smallfish, 2, MAPS.elwynn, AREAS.crystalLake } }, { heard[1] })
    end)

    describe("sessions", function()
        it("start when the pole goes on and keep this character's catches by place", function()
            local client = fishing():catch(ITEMS.snapper)
            local sessions = client.Addon.db.global.sessions
            assert.are.equal(1, #sessions)
            assert.are.equal(CHAR, sessions[1].char)
            assert.are.equal(1, sessions[1].zones[MAPS.elwynn][AREAS.crystalLake][ITEMS.snapper])
        end)

        it("go on after a short break, and a new one starts after 15 minutes", function()
            local client = fishing():catch(ITEMS.snapper)
            client:equip(ITEMS.sword)
            client.serverTime = client.serverTime + 10 * 60
            client:equip(ITEMS.pole):catch(ITEMS.snapper)
            assert.are.equal(1, #client.Addon.db.global.sessions)
            client:equip(nil)
            client.serverTime = client.serverTime + 16 * 60
            client:equip(ITEMS.pole):catch(ITEMS.smallfish)
            local sessions = client.Addon.db.global.sessions
            assert.are.equal(2, #sessions)
            assert.are.equal(2, sessions[1].zones[MAPS.elwynn][AREAS.crystalLake][ITEMS.snapper])
            assert.are.equal(1, sessions[2].zones[MAPS.elwynn][AREAS.crystalLake][ITEMS.smallfish])
        end)

        it("survive a reload with the pole still in hand", function()
            local first = fishing():catch(ITEMS.snapper)
            local saved = Saved()
            local client = NewClient({ saved = saved })
            client.mainHand = ITEMS.pole
            client.serverTime = first.serverTime + 60
            client:login():catch(ITEMS.snapper)
            assert.are.equal(1, #client.Addon.db.global.sessions)
        end)

        it("keep the newest 50", function()
            local client = fishing()
            for _ = 1, 52 do
                client:equip(nil)
                client.serverTime = client.serverTime + 3600
                client:equip(ITEMS.pole)
            end
            assert.are.equal(50, #client.Addon.db.global.sessions)
        end)
    end)

    describe("counts at a place", function()
        it("are sorted by count, with the place's total", function()
            local client = fishing():catch(ITEMS.smallfish, ITEMS.snapper, ITEMS.snapper, ITEMS.sickly)
            local rows, n, total = client.Addon:PlaceCounts("char", MAPS.elwynn, AREAS.crystalLake)
            assert.are.equal(3, n)
            assert.are.equal(4, total)
            assert.are.same({ ITEMS.snapper, 2 }, { rows[1].itemID, rows[1].count })
            assert.are.equal(1, rows[2].count)
        end)

        it("cover the whole zone without an area", function()
            local client = fishing():catch(ITEMS.snapper)
            client:moveTo(MAPS.elwynn, "Stone Cairn Lake"):catch(ITEMS.snapper, ITEMS.smallfish)
            local _, n, total = client.Addon:PlaceCounts("char", MAPS.elwynn, nil)
            assert.are.equal(2, n)
            assert.are.equal(3, total)
            local _, nArea, areaTotal = client.Addon:PlaceCounts("char", MAPS.elwynn, AREAS.stoneCairn)
            assert.are.same({ 2, 2 }, { nArea, areaTotal })
        end)

        it("are of the session, this character or every character", function()
            local other = { char = "Alt - Doomhowl", start = 1, last = 1 }
            local saved = {
                global = {
                    chars = {
                        ["Alt - Doomhowl"] = {
                            zones = { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.sickly] = 5 } } },
                        },
                        [CHAR] = { zones = { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.snapper] = 3 } } } },
                    },
                    sessions = { other },
                },
            }
            local client = NewClient({ saved = saved }):login():equip(ITEMS.pole):catch(ITEMS.smallfish)
            local addon = client.Addon
            local _, _, session = addon:PlaceCounts("session", MAPS.elwynn, AREAS.crystalLake)
            local _, _, char = addon:PlaceCounts("char", MAPS.elwynn, AREAS.crystalLake)
            local _, _, account = addon:PlaceCounts("account", MAPS.elwynn, AREAS.crystalLake)
            assert.are.same({ 1, 4, 9 }, { session, char, account })
        end)

        it("are empty without a session", function()
            local client = NewClient():login()
            local _, n, total = client.Addon:PlaceCounts("session", MAPS.elwynn, AREAS.crystalLake)
            assert.are.same({ 0, 0 }, { n, total })
        end)
    end)

    describe("an item's places", function()
        it("are every character's, best share first", function()
            local client = fishing():catch(ITEMS.snapper, ITEMS.smallfish, ITEMS.smallfish, ITEMS.smallfish)
            client:moveTo(MAPS.westfall, "The Dagger Hills"):catch(ITEMS.snapper)
            local places = client.Addon:ItemPlaces(ITEMS.snapper)
            assert.are.equal(2, #places)
            assert.are.same({ MAPS.westfall, AREAS.daggerHills, 1, 1 }, {
                places[1].mapID,
                places[1].area,
                places[1].count,
                places[1].total,
            })
            assert.are.same({ 1, 4 }, { places[2].count, places[2].total })
        end)

        it("are nil for an item never caught, and follow new catches", function()
            local client = fishing()
            assert.is_nil(client.Addon:ItemPlaces(ITEMS.snapper))
            client:catch(ITEMS.snapper)
            assert.are.equal(1, #client.Addon:ItemPlaces(ITEMS.snapper))
        end)
    end)

    it("can be cleared", function()
        local client = fishing():catch(ITEMS.snapper)
        client.Addon:ClearLog()
        local global = client.Addon.db.global
        assert.are.same({}, global.chars)
        assert.are.same({}, global.sessions)
        assert.is_nil(client.Addon:ItemPlaces(ITEMS.snapper))
    end)
end)
