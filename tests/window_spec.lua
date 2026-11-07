-- The catch window (Core\Window.lua, Core\CatchWindow.lua): when it shows, what its bars say,
-- the view buttons, and its look.

---@return table client, table window
local function fishing(opts)
    local client = NewClient(opts):login():equip(ITEMS.pole)
    return client, client.Addon.catchWindow
end

---The text of each shown row: { left, right, bar value }.
local function shownRows(window)
    local out = {}
    for _, row in ipairs(window.rows) do
        if row.bar:IsShown() then out[#out + 1] = { row.left.text, row.right.text, row.bar.value } end
    end
    return out
end

describe("the catch window", function()
    it("shows while a fishing pole is in hand and hides without it", function()
        local client = NewClient():login()
        local window = client.Addon.catchWindow
        assert.is_false(window.frame:IsShown())
        client:equip(ITEMS.pole)
        assert.is_true(window.frame:IsShown())
        client:equip(ITEMS.sword)
        assert.is_false(window.frame:IsShown())
        client:equip(ITEMS.pole):equip(nil)
        assert.is_false(window.frame:IsShown())
    end)

    it("shows at login when the pole is already in hand", function()
        local client = NewClient()
        client.mainHand = ITEMS.pole
        client:login()
        assert.is_true(client.Addon.catchWindow.frame:IsShown())
    end)

    it("can always show or never", function()
        local client = NewClient():login()
        local window = client.Addon.catchWindow
        client:slash("show always")
        assert.is_true(window.frame:IsShown())
        client:slash("show never"):equip(ITEMS.pole)
        assert.is_false(window.frame:IsShown())
        client:slash("show pole")
        assert.is_true(window.frame:IsShown())
    end)

    it("lists the subzone's catches as bars, most caught first", function()
        local client, window = fishing()
        client:catch(ITEMS.snapper, ITEMS.snapper, ITEMS.snapper, ITEMS.smallfish)
        assert.are.equal("Crystal Lake", window.title.text)
        assert.are.equal("Elwynn Forest · 4 caught · 2/2 kinds", window.subtitle.text)
        local rows = shownRows(window)
        assert.are.equal(2, #rows)
        assert.truthy(rows[1][1]:find("Raw Longjaw Mud Snapper", 1, true))
        assert.truthy(rows[1][1]:find("133888", 1, true), "with its icon")
        assert.are.same({ "3 · 75%", 0.75 }, { rows[1][2], rows[1][3] })
        assert.are.same({ "1 · 25%", 0.25 }, { rows[2][2], rows[2][3] })
    end)

    it("follows the player into another subzone", function()
        local client, window = fishing()
        client:catch(ITEMS.snapper):moveTo(MAPS.elwynn, "Stone Cairn Lake")
        assert.are.equal("Stone Cairn Lake", window.title.text)
        assert.are.same({}, shownRows(window))
        assert.is_true(window.empty:IsShown())
        assert.are.equal(client.Addon.L.NOTHING_HERE, window.empty.text)
    end)

    it("shows the whole zone in zone scope", function()
        local client, window = fishing()
        client:catch(ITEMS.snapper):moveTo(MAPS.elwynn, "Stone Cairn Lake"):catch(ITEMS.smallfish)
        client:slash("scope zone")
        assert.are.equal("Elwynn Forest", window.title.text)
        assert.are.equal("2 caught · 2/2 kinds", window.subtitle.text)
        assert.are.equal(2, #shownRows(window))
    end)

    it("says where it is when the map is unknown", function()
        local client, window = fishing()
        client:moveTo(nil, "")
        assert.are.equal(client.Addon.L.UNKNOWN_PLACE, window.title.text)
    end)

    it("switches between session, character and account with its buttons", function()
        local saved = {
            global = {
                chars = {
                    ["Alt - Doomhowl"] = {
                        zones = { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.sickly] = 5 } } },
                    },
                },
            },
        }
        local client, window = fishing({ saved = saved })
        client:catch(ITEMS.snapper)
        assert.are.equal(1, #shownRows(window), "the session by default")
        window.buttons.account.scripts.OnClick(window.buttons.account)
        assert.are.equal("account", client.Addon.db.profile.view)
        assert.are.equal(2, #shownRows(window))
        assert.is_true(window.buttons.account.selected)
        assert.is_false(window.buttons.session.selected)
        client:slash("view char")
        assert.are.equal(1, #shownRows(window))
    end)

    it("shows at most its row count, then how many more", function()
        local client, window = fishing()
        client:catch(ITEMS.snapper, ITEMS.smallfish, ITEMS.sickly)
        client.Addon.db.profile.rows = 2
        client.Addon:UpdateCatchWindow()
        assert.are.equal(2, #shownRows(window))
        assert.is_true(window.more:IsShown())
        assert.are.equal("and 1 more", window.more.text)
    end)

    it("lets clicks through to the world, except on its buttons", function()
        local _, window = fishing()
        assert.is_false(window.frame.mouse)
    end)

    describe("in Edit Mode", function()
        it("is a frame of its own, with scale and opacity in its dialog", function()
            local client, window = fishing()
            local entry = client.editMode.frames[window.frame]
            assert.is_table(entry)
            assert.are.equal(client.Addon.L.WINDOW_CATCHES, entry.name)
            assert.are.same({ point = "RIGHT", x = -60, y = 120 }, entry.default)
            assert.is_table(client:editModeSetting(window.frame, client.Addon.L.SCALE))
            assert.is_table(client:editModeSetting(window.frame, client.Addon.L.OPACITY))
        end)

        it("takes its spot, scale and opacity from the layout, the defaults in a new one", function()
            local client, window = fishing()
            client:loadLayout("Modern")
            assert.are.same({ "RIGHT", UIParent, "RIGHT", -60, 120 }, window.frame.points[1])
            assert.are.equal(1, window.frame.scale)
            assert.are.equal(0, window.frame.backdropColor[4], "see-through, as Fishbringer")
        end)

        it("keeps where it was moved to and its settings per layout", function()
            local client, window = fishing()
            client:loadLayout("Modern")
            client:moveInEditMode(window.frame, "TOPLEFT", 100, -200)
            client:editModeSetting(window.frame, client.Addon.L.SCALE).set("Modern", 1.5)
            client:editModeSetting(window.frame, client.Addon.L.OPACITY).set("Modern", 0.3)
            assert.are.equal(1.5, window.frame.scale)
            assert.are.equal(0.3, window.frame.backdropColor[4])
            assert.are.equal(1.5, client:editModeSetting(window.frame, client.Addon.L.SCALE).get("Modern"))

            client:loadLayout("Classic")
            assert.are.same({ "RIGHT", UIParent, "RIGHT", -60, 120 }, window.frame.points[1])
            assert.are.equal(1, window.frame.scale)
            client:loadLayout("Modern")
            assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", 100, -200 }, window.frame.points[1])
            assert.are.equal(1.5, window.frame.scale)
        end)

        it("comes back to its layout's spot after a reload", function()
            local saved = {
                profiles = { Default = { layouts = { Modern = { catches = { point = "TOP", x = 5, y = -50 } } } } },
            }
            local client = NewClient({ saved = saved }):login():loadLayout("Modern")
            assert.are.same({ "TOP", UIParent, "TOP", 5, -50 }, client.Addon.catchWindow.frame.points[1])
        end)

        it("shows while Edit Mode is open, so it can be moved, then follows the pole again", function()
            local client = NewClient():login()
            local frame = client.Addon.catchWindow.frame
            client:enterEditMode()
            assert.is_true(frame:IsShown())
            client:exitEditMode()
            assert.is_false(frame:IsShown())
        end)
    end)
end)
