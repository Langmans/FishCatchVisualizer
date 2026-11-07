-- The core (Core\Addon.lua): loading, the saved data's shape, the addon object.

describe("the core", function()
    it("loads without errors and keeps its data in its saved variables", function()
        local client = NewClient():login()
        assert.are.same({}, client.errors)
        assert.is_table(Saved())
        assert.are.equal("pole", client.Addon.db.profile.show)
    end)

    it("is reachable through AceAddon, the same object its files share", function()
        local client = NewClient():login()
        assert.are.equal(client.Addon, LibStub("AceAddon-3.0"):GetAddon("FishCatchVisualizer"))
    end)

    it("speaks English in another client language until translations fill in", function()
        local client = NewClient({ locale = "deDE" }):login()
        assert.are.same({}, client.errors)
        assert.are.equal("Caught at", client.Addon.L.TOOLTIP_TITLE)
    end)

    it("names its fixed value sets", function()
        local addon = NewClient():login().Addon
        assert.are.equal("session", addon.views.session)
        assert.are.equal("zone", addon.scopes.zone)
        assert.are.equal("pole", addon.showModes.pole)
        assert.are.equal("FISHCATCHVISUALIZER_CATCH", addon.messages.catch)
    end)

    it("formats shares as whole percentages, below one as <1%", function()
        local addon = NewClient().Addon
        assert.are.equal("45%", addon.Percent(21 / 47))
        assert.are.equal("100%", addon.Percent(1))
        assert.are.equal("<1%", addon.Percent(0.004))
    end)
end)
