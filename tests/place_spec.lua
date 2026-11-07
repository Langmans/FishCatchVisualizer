-- Where the player stands (Core\Place.lua): a uiMapID and an area key, the same in every client
-- language, and their names in the client's language.

describe("the place", function()
    it("is the map and the area ID of the subzone", function()
        local client = NewClient():login()
        client.mapID, client.subzone = MAPS.elwynn, "Crystal Lake"
        assert.are.same({ MAPS.elwynn, AREAS.crystalLake }, { client.ns.CurrentPlace() })
    end)

    it("looks the area names up once, on first use, not at login", function()
        local client = NewClient():login()
        assert.are.equal(0, client.areaLookups)
        client.ns.CurrentPlace()
        local afterFirst = client.areaLookups
        assert.is_true(afterFirst > 0)
        client.subzone = "Stone Cairn Lake"
        assert.are.same({ MAPS.elwynn, AREAS.stoneCairn }, { client.ns.CurrentPlace() })
        assert.are.equal(afterFirst, client.areaLookups)
    end)

    it("is area 0 without a subzone, and the text itself for a subzone the game has no ID for", function()
        local client = NewClient():login()
        client.subzone = ""
        assert.are.same({ MAPS.elwynn, 0 }, { client.ns.CurrentPlace() })
        client.subzone = "Hidden Cove"
        assert.are.same({ MAPS.elwynn, "Hidden Cove" }, { client.ns.CurrentPlace() })
    end)

    it("is nothing where the client cannot tell the map, or hides it", function()
        local client = NewClient():login()
        client.mapID = nil
        assert.is_nil(client.ns.CurrentPlace())
        client.mapID = SECRET
        assert.is_nil(client.ns.CurrentPlace())
    end)

    it("names a place by its subzone and zone, or the zone alone", function()
        local ns = NewClient():login().ns
        assert.are.equal("Elwynn Forest", ns.ZoneName(MAPS.elwynn))
        assert.are.equal("Crystal Lake", ns.AreaName(MAPS.elwynn, AREAS.crystalLake))
        assert.are.equal("Hidden Cove", ns.AreaName(MAPS.elwynn, "Hidden Cove"))
        assert.are.equal("Elwynn Forest", ns.AreaName(MAPS.elwynn, 0))
        assert.are.equal("Crystal Lake, Elwynn Forest", ns.PlaceName(MAPS.elwynn, AREAS.crystalLake))
        assert.are.equal("Elwynn Forest", ns.PlaceName(MAPS.elwynn, 0))
        assert.are.equal("Map 77", ns.ZoneName(77))
    end)
end)
