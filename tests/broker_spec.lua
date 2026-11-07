-- The data broker object (Core\Broker.lua), for Titan Panel, ChocolateBar, ElvUI's datatexts and the
-- like: the session's catches as its text; the session, the rarest catch where the player stands
-- and the session records in its tooltip; a click opens the options.

local function broker()
    return LibStub("LibDataBroker-1.1"):GetDataObjectByName("FishCatchVisualizer")
end

---The broker's tooltip lines as text.
local function tooltipLines(object)
    local lines = {}
    local tooltip = {
        AddLine = function(_, text)
            lines[#lines + 1] = text
        end,
        AddDoubleLine = function(_, left, right)
            lines[#lines + 1] = left .. " " .. right
        end,
    }
    object.OnTooltipShow(tooltip)
    return table.concat(lines, "\n")
end

describe("the data broker", function()
    it("is a data source named after the addon, with the session's catches as its text", function()
        local client = NewClient():login()
        local object = broker()
        assert.are.equal("data source", object.type)
        assert.are.equal("0 caught", object.text)
        client:equip(ITEMS.pole):catch(ITEMS.snapper):loots({ { ITEMS.smallfish, 2 } })
        assert.are.equal("3 caught", object.text)
        client:equip(nil)
        client.serverTime = client.serverTime + 3600
        client:equip(ITEMS.pole)
        assert.are.equal("0 caught", object.text, "a new session")
    end)

    it("tells the session, the rarest catch here and the records in its tooltip", function()
        local client = NewClient():login():equip(ITEMS.pole)
        client:catch(ITEMS.snapper, ITEMS.snapper, ITEMS.snapper, ITEMS.sickly)
        client.serverTime = client.serverTime + 12 * 60
        client:catch(ITEMS.snapper)
        local text = tooltipLines(broker())
        assert.truthy(text:find("This session: 5 caught in 12 minutes", 1, true))
        assert.truthy(text:find("Rarest here: Sickly Looking Fish (20%)", 1, true))
        assert.truthy(text:find("Most catches in a session: 5", 1, true))
        assert.truthy(text:find("Longest session: 12 minutes", 1, true))
    end)

    it("says little where nothing was caught yet", function()
        NewClient():login()
        local text = tooltipLines(broker())
        assert.truthy(text:find("No session yet.", 1, true))
        assert.is_nil(text:find("Rarest", 1, true))
        assert.is_nil(text:find("Most catches", 1, true))
    end)

    it("opens the options on a click", function()
        local client = NewClient():login()
        broker().OnClick(nil, "LeftButton")
        assert.is_table(LibStub("AceConfigDialog-3.0").OpenFrames.FishCatchVisualizer)
        assert.are.same({}, client.errors)
    end)
end)
