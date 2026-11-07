-- The windows' text (Core\Text.lua): font from LibSharedMedia, size, outline, Slug rendering and
-- shadow, one set per profile, changed in the options or in a window's Edit Mode dialog.

---A logged-in client with the catch window up and a bar in it.
---@return table client, table window
local function shown()
    local client = NewClient():login():equip(ITEMS.pole):catch(ITEMS.snapper)
    return client, client.Addon.catchWindow
end

---Every font string of the window that carries text: title, subtitle, notes, row texts, buttons.
local function strings(window)
    local out = { window.title, window.subtitle, window.empty, window.more }
    for _, row in ipairs(window.rows) do
        out[#out + 1] = row.left
        out[#out + 1] = row.right
    end
    for _, button in pairs(window.buttons) do
        out[#out + 1] = button.label
    end
    return out
end

---Sets an option of the general page's Text box as AceConfig does.
local function setOption(key, value)
    local options = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("FishCatchVisualizer", "dialog", "test-1")
    local text = options.args.general.args.window.args.text
    text.args[key].set({ "general", "window", "text", key }, value)
end

describe("the windows' text", function()
    it("is the shared default font at 12, the title at 14, no outline, with a shadow", function()
        local _, window = shown()
        assert.are.same({ "Fonts\\FRIZQT__.TTF", 14, "" }, window.title.font)
        for _, text in ipairs(strings(window)) do
            if text ~= window.title then assert.are.same({ "Fonts\\FRIZQT__.TTF", 12, "" }, text.font) end
            assert.are.same({ 1, -1 }, text.shadowOffset)
        end
    end)

    it("takes an outline and Slug together, and goes without shadow", function()
        local client, window = shown()
        setOption("outline", "thin")
        setOption("slug", true)
        assert.are.equal("OUTLINE, SLUG", window.title.font[3])
        setOption("outline", "thick")
        assert.are.equal("THICKOUTLINE, SLUG", window.subtitle.font[3])
        setOption("outline", "none")
        assert.are.equal("SLUG", window.subtitle.font[3])
        setOption("shadow", false)
        for _, text in ipairs(strings(window)) do
            assert.are.same({ 0, 0 }, text.shadowOffset)
        end
        assert.is_false(client.Addon.db.profile.shadow)
    end)

    it("uses any font another addon shared, and a size", function()
        local _, window = shown()
        LibStub("LibSharedMedia-3.0"):Register("font", "Test Serif", "Interface\\AddOns\\Test\\Serif.ttf")
        setOption("font", "Test Serif")
        setOption("fontSize", 16)
        assert.are.same({ "Interface\\AddOns\\Test\\Serif.ttf", 18, "" }, window.title.font)
        assert.are.same({ "Interface\\AddOns\\Test\\Serif.ttf", 16, "" }, window.rows[1].left.font)
    end)

    it("waits for a saved font an addon shares later, the default until then", function()
        local saved = { profiles = { Default = { font = "Late Font" } } }
        local client = NewClient({ saved = saved }):login():equip(ITEMS.pole)
        local window = client.Addon.catchWindow
        assert.are.equal("Fonts\\FRIZQT__.TTF", window.title.font[1])
        LibStub("LibSharedMedia-3.0"):Register("font", "Late Font", "Interface\\AddOns\\Late\\Late.ttf")
        assert.are.equal("Interface\\AddOns\\Late\\Late.ttf", window.title.font[1])
    end)

    it("reaches rows made later", function()
        local client, window = shown()
        setOption("outline", "thin")
        client:catch(ITEMS.smallfish)
        assert.are.equal("OUTLINE", window.rows[2].left.font[3])
    end)

    it("is in the window's Edit Mode dialog too, the same settings", function()
        local client, window = shown()
        local L = client.Addon.L
        local outline = client:editModeSetting(window.frame, L.OUTLINE)
        assert.are.equal("none", outline.get("Modern"))
        outline.set("Modern", "thin")
        assert.are.equal("thin", client.Addon.db.profile.outline)
        assert.are.equal("OUTLINE", window.title.font[3])
        client:editModeSetting(window.frame, L.SLUG).set("Modern", true)
        client:editModeSetting(window.frame, L.SHADOW).set("Modern", false)
        client:editModeSetting(window.frame, L.FONT_SIZE).set("Modern", 10)
        assert.are.same({ "Fonts\\FRIZQT__.TTF", 10, "OUTLINE, SLUG" }, window.rows[1].left.font)
        assert.are.same({ 0, 0 }, window.title.shadowOffset)
        local font = client:editModeSetting(window.frame, L.FONT)
        local names = {}
        for _, option in ipairs(font.values()) do
            names[option.value] = option.text
        end
        assert.are.equal("Friz Quadrata TT", names["Friz Quadrata TT"])
        assert.are.equal("Friz Quadrata TT", font.get("Modern"))
        font.set("Modern", "Arial Narrow")
        assert.are.equal("Fonts\\ARIALN.TTF", window.title.font[1])
        local values = {}
        for _, option in ipairs(outline.values) do
            values[#values + 1] = option.value
        end
        assert.are.same({ "none", "thin", "thick" }, values)
    end)
end)
