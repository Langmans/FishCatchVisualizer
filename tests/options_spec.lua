-- The options (Core\Options.lua) and /fcv (Core\Commands.lua).

local AceConfigRegistry = function()
    return LibStub("AceConfigRegistry-3.0")
end

---The options table as AceConfig gets it.
local function options()
    return AceConfigRegistry():GetOptionsTable("FishCatchVisualizer", "dialog", "test-1")
end

---Calls an option's setter as AceConfig does.
local function set(path, value)
    local root = options()
    local node, info = root, { options = root }
    for i, key in ipairs(path) do
        node = node.args[key]
        info[i] = key
    end
    info.option = node
    return node.set(info, value)
end

local function get(path)
    local root = options()
    local node, info = root, { options = root }
    for i, key in ipairs(path) do
        node = node.args[key]
        info[i] = key
    end
    info.option = node
    return node.get(info)
end

describe("the options", function()
    it("are pages in the game's settings: FishCatchVisualizer, then Profiles", function()
        local client = NewClient():login()
        assert.are.same({ "FishCatchVisualizer", "Profiles" }, client.pageNames)
        assert.are.same({}, client.errors)
    end)

    it("read and write the settings, and the window follows", function()
        local client = NewClient():login()
        assert.are.equal("pole", get({ "general", "window", "show" }))
        set({ "general", "window", "show" }, "always")
        assert.are.equal("always", client.Addon.db.profile.show)
        assert.is_true(client.Addon.catchWindow.frame:IsShown())
        set({ "general", "tooltip", "tooltip" }, false)
        assert.is_false(client.Addon.db.profile.tooltip)
    end)

    it("clear the log after asking", function()
        local client = NewClient():login():equip(ITEMS.pole):catch(ITEMS.snapper)
        local clear = options().args.general.args.log.args.clear
        assert.is_string(clear.confirmText)
        clear.func()
        assert.are.same({}, client.Addon.db.global.chars)
    end)

    it("open in a window of their own with /fcv options, and close with it again", function()
        local client = NewClient():login()
        client:slash("options")
        local dialog = LibStub("AceConfigDialog-3.0")
        local frame = dialog.OpenFrames.FishCatchVisualizer.frame
        assert.are.same({ 460, 400 }, frame.resizeBounds)
        client:slash("config")
        -- AceConfigDialog lets the window go on the next frame drawn.
        client:nextFrame()
        assert.is_nil(dialog.OpenFrames.FishCatchVisualizer)
        assert.are.same({ 400, 200 }, frame.resizeBounds, "AceGUI's shared frame gets its own bounds back")
        client:slash("options"):slash("options"):nextFrame()
        assert.are.equal(1, #frame.hooks.OnHide, "hooked once")
    end)
end)

describe("/fcv", function()
    it("lists its commands for anything it does not know", function()
        local client = NewClient():login()
        client:slash("")
        assert.is_true(client:printedContains("/fcv show pole|always|never"))
        client.printed = {}
        client:slash("nonsense")
        assert.is_true(client:printedContains("/fcv view session|char|account"))
    end)

    it("answers a bad value with the commands instead of saving it", function()
        local client = NewClient():login()
        client:slash("show sometimes")
        assert.are.equal("pole", client.Addon.db.profile.show)
        assert.is_true(client:printedContains("/fcv show"))
    end)

    it("says what it changed", function()
        local client = NewClient():login()
        client:slash("view account")
        assert.is_true(client:printedContains(client.Addon.L.VIEW_ACCOUNT))
    end)
end)
