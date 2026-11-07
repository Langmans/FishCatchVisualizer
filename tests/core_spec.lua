-- The core (Core\Addon.lua): loading, the saved data's shape, the public addon object.

describe("the core", function()
    it("loads without errors and keeps its data in FishCatchVisualizerDB", function()
        local client = NewClient():login()
        assert.are.same({}, client.errors)
        assert.is_table(Saved())
        assert.are.equal("pole", client.addon.db.profile.show)
    end)

    it("is reachable through AceAddon, and the public object leads no way back to the namespace", function()
        local client = NewClient():login()
        assert.are.equal(client.addon, LibStub("AceAddon-3.0"):GetAddon("FishCatchVisualizer"))
        for _, value in pairs(client.addon) do
            assert.are_not.equal(client.ns, value)
        end
    end)

    it("speaks English in another client language until translations fill in", function()
        local client = NewClient({ locale = "deDE" }):login()
        assert.are.same({}, client.errors)
        assert.are.equal("Caught at", client.addon.L.TOOLTIP_TITLE)
    end)

    it("names its fixed value sets", function()
        local addon = NewClient():login().addon
        assert.are.equal("session", addon.views.session)
        assert.are.equal("zone", addon.scopes.zone)
        assert.are.equal("pole", addon.showModes.pole)
        assert.are.equal("FISHCATCHVISUALIZER_CATCH", addon.messages.catch)
    end)

    it("formats shares as whole percentages, below one as <1%", function()
        local ns = NewClient().ns
        assert.are.equal("45%", ns.Percent(21 / 47))
        assert.are.equal("100%", ns.Percent(1))
        assert.are.equal("<1%", ns.Percent(0.004))
    end)
end)
