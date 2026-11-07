-- "New here!" (Core\NewHere.lua): the first catch of an item at a place, counted over every
-- character, says so in chat, tells other addons, and marks the item "new" in the window until the
-- player leaves the place. The window's subtitle counts the kinds: those in the view out of every
-- kind the account caught there.

local function fishing(opts)
    return NewClient(opts):login():equip(ITEMS.pole)
end

---The left text of the window's row for an item, or nil.
local function row(client, name)
    for _, r in ipairs(client.Addon.catchWindow.rows) do
        if r.bar:IsShown() and r.left.text:find(name, 1, true) then return r.left.text end
    end
end

describe("new here", function()
    it("says the first catch of an item at a place in chat, and marks it new in the window", function()
        local client = fishing():catch(ITEMS.snapper)
        assert.is_true(client:printedContains("New here: Raw Longjaw Mud Snapper in Crystal Lake"))
        assert.truthy(row(client, "Raw Longjaw Mud Snapper"):find(client.Addon.L.NEW, 1, true))
    end)

    it("says it once, and the mark goes when the player leaves the place", function()
        local client = fishing():catch(ITEMS.snapper)
        client.printed = {}
        client:catch(ITEMS.snapper)
        assert.is_false(client:printedContains("New here"))
        assert.truthy(row(client, "Raw Longjaw Mud Snapper"):find(client.Addon.L.NEW, 1, true), "still new")
        client:moveTo(MAPS.elwynn, "Stone Cairn Lake"):moveTo(MAPS.elwynn, "Crystal Lake")
        assert.is_nil(row(client, "Raw Longjaw Mud Snapper"):find(client.Addon.L.NEW, 1, true))
    end)

    it("is per place: the same item somewhere else is new there", function()
        local client = fishing():catch(ITEMS.snapper)
        client.printed = {}
        client:moveTo(MAPS.westfall, "The Dagger Hills"):catch(ITEMS.snapper)
        assert.is_true(client:printedContains("New here: Raw Longjaw Mud Snapper in The Dagger Hills"))
    end)

    it("is not new where another character of the account caught it", function()
        local saved = {
            global = {
                chars = {
                    ["Alt - Doomhowl"] = {
                        zones = { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.snapper] = 1 } } },
                    },
                },
            },
        }
        local client = fishing({ saved = saved }):catch(ITEMS.snapper)
        assert.is_false(client:printedContains("New here"))
    end)

    it("tells other addons", function()
        local client = fishing()
        local heard = {}
        LibStub("AceEvent-3.0"):Embed(heard)
        heard:RegisterMessage(client.Addon.messages.newHere, function(_, itemID, mapID, area)
            heard[#heard + 1] = { itemID, mapID, area }
        end)
        client:catch(ITEMS.snapper, ITEMS.snapper)
        assert.are.same({ { ITEMS.snapper, MAPS.elwynn, AREAS.crystalLake } }, { heard[1], heard[2] })
    end)
end)

describe("the kinds counter", function()
    it("counts the kinds in the view out of every kind the account caught at the place", function()
        local saved = {
            global = {
                chars = {
                    ["Alt - Doomhowl"] = {
                        zones = {
                            [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.sickly] = 2, [ITEMS.smallfish] = 1 } },
                        },
                    },
                },
            },
        }
        local client = fishing({ saved = saved }):catch(ITEMS.snapper)
        local subtitle = client.Addon.catchWindow.subtitle
        assert.are.equal("Elwynn Forest · 1 caught · 1/3 kinds", subtitle.text)
        client:slash("view account")
        assert.are.equal("Elwynn Forest · 4 caught · 3/3 kinds", subtitle.text)
    end)
end)
