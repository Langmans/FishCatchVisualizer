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

---An option of the general page's Text box as AceConfig has it.
local function option(key)
    local options = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("FishCatchVisualizer", "dialog", "test-1")
    return options.args.general.args.window.args.text.args[key], { "general", "window", "text", key }
end

---Sets an option of the Text box as AceConfig does; a colour takes r, g, b (and a).
local function setOption(key, ...)
    local entry, info = option(key)
    entry.set(info, ...)
end

describe("the windows' text", function()
    it("is the shared default font at 12, the title at 14, no outline, with a black shadow", function()
        local _, window = shown()
        assert.are.same({ "Fonts\\FRIZQT__.TTF", 14, "" }, window.title.font)
        for _, text in ipairs(strings(window)) do
            if text ~= window.title then assert.are.same({ "Fonts\\FRIZQT__.TTF", 12, "" }, text.font) end
            assert.are.same({ 1, -1 }, text.shadowOffset)
            assert.are.same({ 0, 0, 0, 1 }, text.shadowColor)
        end
    end)

    it("draws the title gold and the rest pure white, in colours of its own", function()
        local _, window = shown()
        assert.are.same({ 1, 0.82, 0 }, window.title.textColor)
        for _, text in ipairs({ window.subtitle, window.empty, window.more, window.rows[1].left, window.rows[1].right }) do
            assert.are.same({ 1, 1, 1 }, text.textColor)
        end
        setOption("titleColor", 0.2, 0.4, 0.6)
        setOption("textColor", 0.9, 0.8, 0.7)
        assert.are.same({ 0.2, 0.4, 0.6 }, window.title.textColor)
        assert.are.same({ 0.9, 0.8, 0.7 }, window.subtitle.textColor)
        assert.are.same({ 0.9, 0.8, 0.7 }, { option("textColor").get(select(2, option("textColor"))) })
    end)

    it("leaves the buttons their own colours: gold for the chosen one", function()
        local _, window = shown()
        setOption("textColor", 0.5, 0.5, 0.5)
        assert.are.same({ 1, 0.82, 0 }, window.buttons.session.label.textColor)
    end)

    it("takes a shadow colour and its own x and y offset", function()
        local _, window = shown()
        setOption("shadowColor", 0.1, 0.2, 0.3, 0.5)
        setOption("shadowX", 3)
        setOption("shadowY", -2)
        assert.are.same({ 3, -2 }, window.title.shadowOffset)
        setOption("shadowX", 1.5)
        assert.are.same({ 1.5, -2 }, window.title.shadowOffset, "fractions too")
        assert.are.equal(0.1, option("shadowX").step, "typed to a tenth in the options")
        assert.are.same({ 0.1, 0.2, 0.3, 0.5 }, window.rows[1].left.shadowColor)
        assert.are.same({ 0.1, 0.2, 0.3, 0.5 }, { option("shadowColor").get(select(2, option("shadowColor"))) })
    end)

    it("names each item in its quality's colour, unless switched off", function()
        local client, window = shown()
        client:catch(ITEMS.sickly)
        local function row(name)
            for _, r in ipairs(window.rows) do
                if r.left.text:find(name, 1, true) then return r.left.text end
            end
        end
        assert.truthy(row("Sickly Looking Fish"):find("|cff9d9d9dSickly Looking Fish|r", 1, true))
        assert.truthy(row("Raw Longjaw Mud Snapper"):find("|cffffffffRaw Longjaw Mud Snapper|r", 1, true))
        setOption("qualityColors", false)
        assert.is_nil(row("Sickly Looking Fish"):find("|c", 1, true))
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

    it("has the colours, the shadow's offset and the quality colours in Edit Mode too", function()
        local client, window = shown()
        local L = client.Addon.L
        local title = client:editModeSetting(window.frame, L.TITLE_COLOR)
        assert.are.same({ 1, 0.82, 0, 1 }, { title.get("Modern"):GetRGBA() })
        assert.is_true(client:editModeSetting(window.frame, L.SHADOW_COLOR).hasOpacity)
        title.set("Modern", CreateColor(0.5, 0.6, 0.7))
        client:editModeSetting(window.frame, L.TEXT_COLOR).set("Modern", CreateColor(0.1, 0.1, 0.1))
        client:editModeSetting(window.frame, L.SHADOW_COLOR).set("Modern", CreateColor(1, 0, 0, 0.5))
        client:editModeSetting(window.frame, L.SHADOW_X).set("Modern", 2)
        client:editModeSetting(window.frame, L.SHADOW_Y).set("Modern", -3)
        assert.are.same({ 0.5, 0.6, 0.7 }, window.title.textColor)
        assert.are.same({ 0.1, 0.1, 0.1 }, window.subtitle.textColor)
        assert.are.same({ 1, 0, 0, 0.5 }, window.title.shadowColor)
        assert.are.same({ 2, -3 }, window.title.shadowOffset)
        client:editModeSetting(window.frame, L.QUALITY_COLORS).set("Modern", false)
        assert.is_false(client.Addon.db.profile.qualityColors)
    end)
end)
