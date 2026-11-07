-- Sharing with the guild (Core\Share.lua): guildmates with the addon swap their accounts'
-- counts by addon message. Each account has an ID of its own, so two characters of one player count
-- once. A hello 10 s after login asks for the guild's counts; whoever hears one answers within a
-- few seconds, at most once every 5 minutes; putting the pole away sends the counts too. What
-- arrives is checked before it is kept, and the Guild view adds it to the account's.

local SNAPSHOT_MATE = "mate-account"

---A logged-in client in a guild.
local function guilded(opts)
    local client = NewClient(opts)
    client.inGuild = true
    return client:login()
end

---The snapshots among the guild messages sent: what each holds.
local function snapshots(client)
    local out = {}
    for _, text in ipairs(client:guildSent()) do
        if text:sub(1, 1) == "S" then out[#out + 1] = { client.Addon.DecodeSnapshot(text:sub(2)) } end
    end
    return out
end

---A guildmate's snapshot as it arrives.
local function mateSnapshot(client, zones)
    return "S" .. client.Addon.EncodeSnapshot(SNAPSHOT_MATE, zones)
end

describe("sharing with the guild", function()
    it("says hello to the guild 10 seconds after login", function()
        local client = guilded()
        assert.are.same({}, client:guildSent())
        client:advance(11):nextFrame()
        assert.are.same({ "H" }, client:guildSent())
    end)

    it("says nothing outside a guild, or with sharing off", function()
        local alone = NewClient():login()
        alone:advance(11):nextFrame()
        assert.are.same({}, alone:guildSent())
        local off = guilded({ saved = { profiles = { Default = { share = false } } } })
        off:advance(11):nextFrame()
        assert.are.same({}, off:guildSent())
    end)

    it("answers a guildmate's hello with the account's counts, at most every 5 minutes", function()
        local client = guilded():equip(ITEMS.pole):catch(ITEMS.snapper)
        client:advance(11):nextFrame()
        client:receive("H", "Mate-Doomhowl"):advance(20):nextFrame()
        local sent = snapshots(client)
        assert.are.equal(1, #sent)
        assert.are.equal(client.Addon:ShareId(), sent[1][1])
        assert.are.equal(1, sent[1][2][MAPS.elwynn][AREAS.crystalLake][ITEMS.snapper])
        client:receive("H", "Other-Doomhowl"):advance(20):nextFrame()
        assert.are.equal(1, #snapshots(client), "too soon after the last")
        client:advance(300):receive("H", "Other-Doomhowl"):advance(20):nextFrame()
        assert.are.equal(2, #snapshots(client))
    end)

    it("does not answer its own hello", function()
        local client = guilded()
        client:receive("H", "Fisher"):advance(20):nextFrame()
        assert.are.same({}, snapshots(client))
    end)

    it("sends the counts when the pole goes away", function()
        local client = guilded():equip(ITEMS.pole):catch(ITEMS.snapper):equip(nil)
        client:nextFrame()
        assert.are.equal(1, #snapshots(client))
    end)

    it("keeps a guildmate's counts under their account, and the Guild view adds them", function()
        local client = guilded():equip(ITEMS.pole):catch(ITEMS.snapper)
        client:receive(
            mateSnapshot(client, { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.sickly] = 4 } } }),
            "Mate-Doomhowl"
        )
        local kept = client.Addon.db.global.guild[SNAPSHOT_MATE]
        assert.are.equal("Mate-Doomhowl", kept.name)
        local _, n, total = client.Addon:PlaceCounts("guild", MAPS.elwynn, AREAS.crystalLake)
        assert.are.same({ 2, 5 }, { n, total })
        local window = client.Addon.catchWindow
        window.buttons.guild.scripts.OnClick(window.buttons.guild)
        assert.are.equal("guild", client.Addon.db.profile.view)
    end)

    it("lists a guildmate's places in the item tooltip", function()
        local client = guilded():equip(ITEMS.pole):catch(ITEMS.snapper)
        client:receive(
            mateSnapshot(client, { [MAPS.westfall] = { [AREAS.daggerHills] = { [ITEMS.snapper] = 2 } } }),
            "Mate-Doomhowl"
        )
        local places = client.Addon:ItemPlaces(ITEMS.snapper)
        assert.are.equal(2, #places)
    end)

    it("keeps nothing that is its own, broken, or not from the guild", function()
        local client = guilded()
        client:receive("S" .. client.Addon.EncodeSnapshot(client.Addon:ShareId(), {}), "Fisher")
        client:receive("Snot base64 !", "Mate-Doomhowl")
        client:receive(
            "S" .. client.Addon.EncodeSnapshot(SNAPSHOT_MATE, { [MAPS.elwynn] = "nonsense" }),
            "Mate-Doomhowl"
        )
        client:receive(mateSnapshot(client, {}), "Mate-Doomhowl", "WHISPER")
        assert.are.same({}, client.Addon.db.global.guild)
        assert.are.same({}, client.errors)
    end)

    it("drops the parts of a snapshot that are not counts", function()
        local client = guilded()
        client:receive(
            mateSnapshot(client, {
                [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.snapper] = 3, [ITEMS.sickly] = "x" }, [true] = {} },
                ["bad"] = {},
            }),
            "Mate-Doomhowl"
        )
        assert.are.same(
            { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.snapper] = 3 } } },
            client.Addon.db.global.guild[SNAPSHOT_MATE].zones
        )
    end)

    it("keeps nothing and answers nothing with sharing off", function()
        local client = guilded({ saved = { profiles = { Default = { share = false } } } })
        client:receive(
            mateSnapshot(client, { [MAPS.elwynn] = { [AREAS.crystalLake] = { [ITEMS.sickly] = 1 } } }),
            "Mate-Doomhowl"
        )
        client:receive("H", "Mate-Doomhowl"):advance(20):nextFrame()
        assert.are.same({}, client.Addon.db.global.guild)
        assert.are.same({}, client:guildSent())
    end)

    it("has an account ID of its own that stays", function()
        local client = guilded()
        local id = client.Addon:ShareId()
        assert.is_string(id)
        assert.are.equal(id, client.Addon:ShareId())
        assert.are.equal(id, client.Addon.db.global.shareId)
    end)
end)
