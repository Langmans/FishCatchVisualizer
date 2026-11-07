-- Every name the game and other addons see is made from the addon's folder name, so a rename is the
-- folder and the .toc (README > Renaming). Loaded here as "Tester" to prove it.

---A logged-in client whose folder is called Tester.
---@return table
local function tester()
    return NewClient({ addonName = "Tester" }):login()
end

describe("the addon's names", function()
    it("start from the folder's name", function()
        local client = tester()
        assert.are.same({}, client.errors)
        local addon = client.Addon
        assert.are.equal("Tester", addon.NAME)
        assert.are.equal(addon, LibStub("AceAddon-3.0"):GetAddon("Tester"))
        assert.are.equal("TESTER_CATCH", addon.messages.catch)
    end)

    it("name the saved data and the window", function()
        tester()
        assert.is_table(_G.TesterDB)
        assert.is_table(_G.TesterCatchesWindow)
    end)

    it("answer to the slash command by the folder's name and to its short alias", function()
        local client = tester()
        client:slash("show always")
        assert.are.equal("always", client.Addon.db.profile.show)
        client:slash("show never", "fcv")
        assert.are.equal("never", client.Addon.db.profile.show)
    end)

    it("name the options page", function()
        local client = tester()
        assert.are.equal("Tester", client.pageNames[1])
    end)
end)

describe("the names that cannot be made from the folder", function()
    it("match it in the .toc: the saved data", function()
        local client = NewClient():login()
        assert.are.equal(client.Addon.NAME .. "DB", TOC_SAVED)
    end)
end)
