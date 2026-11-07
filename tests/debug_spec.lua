-- The bridge to OAP Debug (Core\Debug.lua): when that addon is installed, the addon registers with
-- it and sends log lines and counts as the chosen level asks, so what happened in game can be read
-- back: loot events, catches, sessions, the area name lookup, the guild. Without it nothing is sent.

local ICON = "Interface\\Icons\\Trade_Fishing"

---A stand-in for OAP Debug's global table: every call in `calls`, as { name, ... }.
---@return table api
---@return table[] calls
local function fakeOAPDebug()
    local calls = {}
    local api = {}
    for _, name in ipairs({ "Register", "Log", "Count" }) do
        api[name] = function(...)
            calls[#calls + 1] = { name, ... }
        end
    end
    return api, calls
end

---The calls of one kind.
local function only(calls, name)
    local out = {}
    for _, call in ipairs(calls) do
        if call[1] == name then out[#out + 1] = call end
    end
    return out
end

---Whether a log line with this message was sent, at this kind.
local function logged(calls, kind, msg)
    for _, call in ipairs(only(calls, "Log")) do
        if call[3] == msg and call[4] == kind then return call end
    end
end

---A client with OAP Debug installed, logged in.
---@param level string? the OAP Debug setting
local function withOAP(level)
    local saved = { profiles = { Default = { oapDebug = level } } }
    local client = NewClient(level and { saved = saved } or nil)
    local api, calls = fakeOAPDebug()
    -- busted gives a spec file globals of its own; the addon reads the real ones.
    _G.OAPDebug = api
    client:login()
    return client, calls
end

describe("OAP Debug", function()
    after_each(function()
        _G.OAPDebug = nil
    end)

    it("gets the addon registered once, with its folder for Lua errors and its icon", function()
        local client, calls = withOAP()
        client.Addon:SetDebugLevel("normal")
        assert.are.same({
            {
                "Register",
                "FishCatchVisualizer",
                { title = "FishCatchVisualizer", folder = "FishCatchVisualizer", icon = ICON },
            },
        }, only(calls, "Register"))
    end)

    it("sends only what the level asks for", function()
        local client, calls = withOAP("errors")
        client.Addon:Log("info", "quiet")
        client.Addon:Log("error", "loud")
        client.Addon:Count("catches")
        assert.are.same({ { "Log", "FishCatchVisualizer", "loud", "error" } }, only(calls, "Log"))
        assert.are.same({}, only(calls, "Count"))
        client, calls = withOAP("normal")
        client.Addon:Log("info", "shown")
        client.Addon:Log("debug", "detail")
        client.Addon:Count("catches")
        assert.are.same({ { "Log", "FishCatchVisualizer", "shown", "info" } }, only(calls, "Log"))
        assert.are.same({}, only(calls, "Count"))
        client, calls = withOAP("detailed")
        client.Addon:Log("debug", "detail")
        assert.are.equal(1, #only(calls, "Log"))
    end)

    it("changes level at once and keeps it in the profile; the options have it", function()
        local client, calls = withOAP()
        local options = client.Addon:GetOptionsTable().args.general.args.debug.args.level
        assert.are.equal(client.Addon.L.DEBUG_DESC, options.desc())
        assert.are.equal("metrics", options.get())
        options.set(nil, "errors")
        assert.are.equal("errors", client.Addon.db.profile.oapDebug)
        client.Addon:Log("info", "quiet")
        assert.are.same({}, only(calls, "Log"))
    end)

    it("sends nothing without OAP Debug", function()
        local client = NewClient():login()
        assert.is_false(client.Addon.HasOAPDebug())
        client.Addon:Log("error", "nobody listens")
        client.Addon:Count("catches")
        assert.are.same({}, client.errors)
        local desc = client.Addon:GetOptionsTable().args.general.args.debug.args.level.desc()
        assert.truthy(desc:find(client.Addon.L.DEBUG_MISSING, 1, true), "the options say it is missing")
    end)

    describe("logs, for checking in game", function()
        it("every loot event, and each catch with the event that counted it", function()
            local client, calls = withOAP("detailed")
            client:equip(ITEMS.pole):loots({ { ITEMS.snapper, 2 } }, false, true)
            assert.truthy(logged(calls, "debug", "{1}: {2} slots, fishing {3}"))
            local catch = logged(calls, "info", "caught {1} x{2} at {3} on {4}")
            assert.are.same(
                { ITEMS.snapper, 2, "Crystal Lake, Elwynn Forest", "LOOT_READY" },
                { catch[5], catch[6], catch[7], catch[8] }
            )
            assert.are.equal(1, #only(calls, "Count"))
        end)

        it("a slot whose item the client hides", function()
            local client, calls = withOAP()
            client:equip(ITEMS.pole)
            local original = _G.GetLootSlotLink
            _G.GetLootSlotLink = function()
                return SECRET
            end
            client:catch(ITEMS.snapper)
            _G.GetLootSlotLink = original
            assert.truthy(logged(calls, "warn", "slot {1}: the item is hidden"))
        end)

        it("the area name lookup, and how long it took", function()
            local client, calls = withOAP()
            client:equip(ITEMS.pole):catch(ITEMS.snapper)
            assert.truthy(logged(calls, "info", "area names looked up: {1} in {2} ms"))
        end)

        it("sessions starting, going on and ending", function()
            local client, calls = withOAP()
            client:equip(ITEMS.pole):catch(ITEMS.snapper):equip(nil)
            client:equip(ITEMS.pole)
            assert.truthy(logged(calls, "info", "session started"))
            assert.truthy(logged(calls, "info", "session ended after {1} catches"))
            assert.truthy(logged(calls, "info", "session goes on"))
        end)

        it("the guild: hello, snapshots out and in, and what is dropped", function()
            local client, calls = withOAP()
            client.inGuild = true
            client:advance(11):nextFrame()
            client:equip(ITEMS.pole):catch(ITEMS.snapper):equip(nil)
            client:receive(
                "S" .. client.Addon.EncodeSnapshot("mate", { [MAPS.elwynn] = { [0] = { [ITEMS.sickly] = 1 } } }),
                "Mate"
            )
            client:receive("Sbroken", "Mate")
            assert.truthy(logged(calls, "info", "guild: hello sent"))
            assert.truthy(logged(calls, "info", "guild: counts sent, {1} characters"))
            assert.truthy(logged(calls, "info", "guild: counts from {1} kept"))
            assert.truthy(logged(calls, "warn", "guild: counts from {1} dropped"))
        end)
    end)
end)
