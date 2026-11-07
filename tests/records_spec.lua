-- Records (Core\Records.lua), account-wide: an item's biggest stack, the most catches in one
-- session and the longest session. A first value is kept quietly; beating a record says so in chat
-- (a session's records once per session). The rarest catch at a place is worked out when asked.

local function fishing(opts)
    return NewClient(opts):login():equip(ITEMS.pole)
end

local function tooltip(client, item)
    local out = {}
    for _, line in ipairs(client:hoverItem(item)) do
        out[#out + 1] = line[2] and (line[1] .. " " .. line[2]) or line[1]
    end
    return table.concat(out, "\n")
end

describe("records", function()
    it("keep an item's biggest stack, quietly the first time, in chat when beaten", function()
        local client = fishing()
        client:loots({ { ITEMS.snapper, 3 } })
        assert.is_false(client:printedContains("New record"))
        client:loots({ { ITEMS.snapper, 2 } })
        client:moveTo(MAPS.westfall, "The Dagger Hills"):loots({ { ITEMS.snapper, 5 } })
        assert.is_true(client:printedContains("New record: biggest stack of Raw Longjaw Mud Snapper, 5 (was 3)"))
        local stack = client.Addon.db.global.records.stacks[ITEMS.snapper]
        assert.are.same({ 5, MAPS.westfall, AREAS.daggerHills }, { stack.n, stack.mapID, stack.area })
        assert.truthy(tooltip(client, ITEMS.snapper):find("Biggest stack: 5 (The Dagger Hills, Westfall)", 1, true))
    end)

    it("keep the most catches in one session, and say once per session when it is beaten", function()
        local client = fishing():catch(ITEMS.snapper, ITEMS.snapper)
        assert.is_false(client:printedContains("New record"))
        client:equip(nil)
        client.serverTime = client.serverTime + 3600
        client:equip(ITEMS.pole):catch(ITEMS.snapper, ITEMS.snapper)
        assert.is_false(client:printedContains("New record"), "a tie")
        client:catch(ITEMS.snapper)
        assert.is_true(client:printedContains("New record: 3 catches in one session (was 2)"))
        client.printed = {}
        client:catch(ITEMS.snapper)
        assert.is_false(client:printedContains("New record"))
        assert.are.equal(4, client.Addon.db.global.records.sessionCatches.n)
    end)

    it("keep the longest session, and say once per session when it is beaten", function()
        local client = fishing():catch(ITEMS.snapper)
        client.serverTime = client.serverTime + 10 * 60
        client:catch(ITEMS.snapper)
        client:equip(nil)
        client.serverTime = client.serverTime + 3600
        client:equip(ITEMS.pole):catch(ITEMS.smallfish)
        client.serverTime = client.serverTime + 14 * 60
        client:catch(ITEMS.smallfish)
        assert.is_true(client:printedContains("New record: a session of 14 minutes (was 10)"))
        client.printed = {}
        client.serverTime = client.serverTime + 5 * 60
        client:catch(ITEMS.smallfish)
        assert.is_false(client:printedContains("New record: a session"))
        assert.are.equal(19 * 60, client.Addon.db.global.records.sessionLength.n)
    end)

    it("work out the rarest catch at a place over every character", function()
        local client = fishing():catch(ITEMS.snapper, ITEMS.snapper, ITEMS.snapper, ITEMS.sickly)
        assert.are.same({ ITEMS.sickly, 0.25 }, { client.Addon:RarestAt(MAPS.elwynn, AREAS.crystalLake) })
        assert.is_nil(client.Addon:RarestAt(MAPS.westfall, AREAS.daggerHills))
    end)

    it("are forgotten with the log", function()
        local client = fishing():catch(ITEMS.snapper)
        client.Addon:ClearLog()
        assert.are.same({ stacks = {} }, client.Addon.db.global.records)
    end)
end)
