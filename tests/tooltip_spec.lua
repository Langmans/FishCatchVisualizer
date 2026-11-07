-- The item tooltip (Core\Tooltip.lua): where an item was caught, best share first.

local function fishing(opts)
    return NewClient(opts):login():equip(ITEMS.pole)
end

describe("the item tooltip", function()
    it("lists the places the item was caught, with its share there and its count", function()
        local client = fishing():catch(ITEMS.snapper, ITEMS.smallfish)
        client:moveTo(MAPS.westfall, "The Dagger Hills"):catch(ITEMS.snapper)
        assert.are.same({
            { "Caught at" },
            { "The Dagger Hills, Westfall", "100% (1)" },
            { "Crystal Lake, Elwynn Forest", "50% (1)" },
        }, client:hoverItem(ITEMS.snapper))
    end)

    it("adds nothing for an item never caught, or one the client hides", function()
        local client = fishing():catch(ITEMS.snapper)
        assert.are.same({}, client:hoverItem(ITEMS.sickly))
        assert.are.same({}, client:hoverItem(SECRET))
        assert.are.same({}, client:hoverItem(nil))
    end)

    it("shows the set number of places, then how many more", function()
        local client = fishing():catch(ITEMS.snapper)
        client:moveTo(MAPS.elwynn, "Stone Cairn Lake"):catch(ITEMS.snapper)
        client:moveTo(MAPS.westfall, "The Dagger Hills"):catch(ITEMS.snapper)
        client.Addon.db.profile.tooltipPlaces = 1
        local lines = client:hoverItem(ITEMS.snapper)
        assert.are.equal(3, #lines)
        assert.are.same({ "and 2 more places" }, lines[3])
    end)

    it("can be switched off", function()
        local client = fishing():catch(ITEMS.snapper)
        client.Addon.db.profile.tooltip = false
        assert.are.same({}, client:hoverItem(ITEMS.snapper))
    end)

    it("loads on a client without tooltip data", function()
        local client = NewClient({ noTooltipData = true }):login()
        assert.are.same({}, client.errors)
    end)
end)
