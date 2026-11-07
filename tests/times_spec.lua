-- Day and night, and the seasons (Core\Times.lua): every catch is counted by the server's time of
-- day and the month's season, and an item's tooltip says when it seems to bite only then.

local function fishing()
    return NewClient():login():equip(ITEMS.pole)
end

---Catches `item` `count` times.
local function catchMany(client, item, count)
    for _ = 1, count do
        client:catch(item)
    end
    return client
end

---The tooltip's lines as text, the right half after the left.
local function lines(client, item)
    local out = {}
    for _, line in ipairs(client:hoverItem(item)) do
        out[#out + 1] = line[2] and (line[1] .. " " .. line[2]) or line[1]
    end
    return table.concat(out, "\n")
end

describe("the time of a catch", function()
    it("is counted by day or night (server time, day from 6 to 18) and by season, for all catches too", function()
        local client = fishing()
        client.hour, client.month = 22, 1
        client:catch(ITEMS.snapper)
        client.hour, client.month = 6, 7
        client:loots({ { ITEMS.smallfish, 2 } })
        local times = client.Addon.db.global.times
        assert.are.same({ night = 1, winter = 1 }, times[ITEMS.snapper])
        assert.are.same({ day = 2, summer = 2 }, times[ITEMS.smallfish])
        assert.are.same({ night = 1, day = 2, winter = 1, summer = 2 }, times[0])
    end)

    it("names the seasons by the northern months: winter is December to February", function()
        local Addon = NewClient().Addon
        local seasons = {}
        for month = 1, 12 do
            seasons[month] = Addon.SeasonOf(month)
        end
        assert.are.same({
            "winter",
            "winter",
            "spring",
            "spring",
            "spring",
            "summer",
            "summer",
            "summer",
            "autumn",
            "autumn",
            "autumn",
            "winter",
        }, seasons)
    end)

    it("says in the tooltip that an item bites only at night, once day fishing has shown it does not", function()
        local client = fishing()
        client.hour = 23
        catchMany(client, ITEMS.snapper, 5)
        assert.is_nil(lines(client, ITEMS.snapper):find("Only at night", 1, true), "no day fishing yet")
        client.hour = 12
        catchMany(client, ITEMS.smallfish, 20)
        assert.truthy(lines(client, ITEMS.snapper):find("Only at night", 1, true))
        assert.is_nil(lines(client, ITEMS.smallfish):find("Only", 1, true), "night fished only 5 times")
        client.hour = 2
        catchMany(client, ITEMS.sickly, 15)
        assert.truthy(lines(client, ITEMS.smallfish):find("Only by day", 1, true))
    end)

    it("says nothing about an item caught too few times to tell", function()
        local client = fishing()
        client.hour = 23
        catchMany(client, ITEMS.snapper, 4)
        client.hour = 12
        catchMany(client, ITEMS.smallfish, 20)
        assert.is_nil(lines(client, ITEMS.snapper):find("Only", 1, true))
    end)

    it("names the seasons an item bit in, once the other seasons were fished without it", function()
        local client = fishing()
        client.month = 1
        catchMany(client, ITEMS.snapper, 3)
        client.month = 4
        catchMany(client, ITEMS.snapper, 2)
        client.month = 7
        catchMany(client, ITEMS.smallfish, 20)
        assert.truthy(lines(client, ITEMS.snapper):find("Only in winter and spring", 1, true))
        client.month = 10
        catchMany(client, ITEMS.smallfish, 20)
        assert.truthy(lines(client, ITEMS.snapper):find("Only in winter and spring", 1, true))
        client.month = 7
        catchMany(client, ITEMS.snapper, 1)
        assert.truthy(lines(client, ITEMS.snapper):find("Only in winter, spring and summer", 1, true))
    end)

    it("is forgotten with the log", function()
        local client = fishing():catch(ITEMS.snapper)
        client.Addon:ClearLog()
        assert.are.same({}, client.Addon.db.global.times)
    end)
end)
