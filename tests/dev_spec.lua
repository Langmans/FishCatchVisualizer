-- Screenshots for development (Core\Dev.lua): only in a copy straight from the repository, never
-- in a release (the packager comments it out), off until switched on. The first time each kind of
-- moment from tasks\01-todo\01-ingame.md happens, a grey chat line says which, then one screenshot.

---A development copy, logged in, with the screenshots switched on.
---@return table
local function shooting()
    local client = NewClient({ dev = true }):login()
    local dev = client.Addon:DevOptions().args
    assert.is_false(dev.on.get(), "off until switched on")
    dev.on.set(nil, true)
    return client
end

describe("development screenshots", function()
    it("take one of the window the first time it shows, after saying which", function()
        local client = shooting():equip(ITEMS.pole)
        assert.is_true(client:printedContains("|cff888888[FishCatchVisualizer dev] window: session view|r"))
        assert.are.equal(0, client.screenshots, "not before the window is drawn")
        client:advance(0.5)
        assert.are.equal(1, client.screenshots)
    end)

    it("take each kind once, kept across sessions, until forgotten", function()
        local client = shooting():equip(ITEMS.pole)
        client:advance(3):equip(nil):advance(3):equip(ITEMS.pole):advance(3)
        assert.are.equal(1, client.screenshots, "the same window again")
        local shots = client.Addon.db.global.dev.shots
        assert.is_true(shots["window: session view"])
        assert.is_true(shots["window: nothing caught here"])
        client.Addon:DevOptions().args.forget.func()
        client:equip(nil):equip(ITEMS.pole):advance(1)
        assert.are.equal(2, client.screenshots)
    end)

    it("take at most one every two seconds; a kind skipped comes again later", function()
        local client = shooting():equip(ITEMS.pole)
        client:catch(ITEMS.snapper)
        client:advance(0.5)
        assert.are.equal(1, client.screenshots)
        assert.is_nil(client.Addon.db.global.dev.shots["fishing loot window"], "too soon, not marked")
        client:advance(3):catch(ITEMS.snapper):advance(0.5)
        assert.are.equal(2, client.screenshots)
        assert.is_true(client.Addon.db.global.dev.shots["fishing loot window"])
    end)

    it("know the moments from the in-game checks", function()
        local client = shooting()
        local shots = client.Addon.db.global.dev.shots
        local function step(fn)
            fn()
            client:advance(3)
        end
        step(function()
            client:equip(ITEMS.pole)
        end)
        step(function()
            client:catch(ITEMS.snapper)
        end)
        step(function()
            client.fishingLoot = true
            client:fire("LOOT_OPENED", true, false)
        end)
        step(function()
            client:catch(ITEMS.smallfish)
        end)
        step(function()
            client:catch(ITEMS.sickly)
        end)
        step(function()
            client.Addon.db.profile.rows = 3
            client:slash("view account")
        end)
        step(function()
            client.Addon.db.profile.rows = 2
            client:slash("view char")
        end)
        step(function()
            client:slash("scope zone")
        end)
        step(function()
            client:slash("scope area"):moveTo(MAPS.elwynn, "")
        end)
        step(function()
            client:enterEditMode()
        end)
        step(function()
            client:hoverItem(ITEMS.snapper)
        end)
        step(function()
            client:slash("options")
        end)
        for _, kind in ipairs({
            "window: session view",
            "window: nothing caught here",
            "fishing loot window",
            "fishing loot, autoloot",
            "window: account view",
            "window: char view",
            "window: more rows",
            "window: whole zone",
            "window: no subzone",
            "window: in Edit Mode",
            "tooltip: GameTooltip",
            "options window",
            "new here",
        }) do
            assert.is_true(shots[kind], kind)
        end
    end)

    it("leave a tooltip without places alone", function()
        local client = shooting()
        client:hoverItem(ITEMS.snapper)
        client:advance(1)
        assert.are.equal(0, client.screenshots)
    end)

    it("take none while switched off", function()
        local client = NewClient({ dev = true }):login():equip(ITEMS.pole):catch(ITEMS.snapper)
        client:advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_false(client:printedContains("dev]"))
        assert.is_table(client.Addon:GetOptionsTable().args.general.args.dev, "its switch is in the options")
    end)

    it("are not there in a release", function()
        local client = NewClient():login():equip(ITEMS.pole)
        client:advance(3)
        assert.are.equal(0, client.screenshots)
        assert.is_nil(client.Addon.DevOptions)
        assert.is_nil(client.Addon:GetOptionsTable().args.general.args.dev)
    end)
end)
