local _, ns = ...

-- The slash command, NAME in lower case or SLASH_ALIAS (/fishcatchvisualizer, /fcv): the first
-- word picks a command, which gets the rest of the line; anything else lists the commands.

---@type Addon
local Addon = ns
local L = Addon.L

---Command word -> what it takes, what it does, and its function; and the words in list order.
---@type table<string, AddonCommand>
local commands = {}
---@type string[]
local order = {}

---@param word string lower case
---@param args string what it takes, for the list ("" for nothing)
---@param help string
---@param run fun(rest: string)
local function AddCommand(word, args, help, run)
    commands[word] = { args = args, help = help, run = run }
    order[#order + 1] = word
end

---Prints every command with what it does.
local function Usage()
    for _, word in ipairs(order) do
        local command = commands[word]
        local line = command.args == "" and word or (word .. " " .. command.args)
        Addon:Print(("/%s %s - %s"):format(Addon.SLASH_ALIAS, line, command.help))
    end
end

---A command that sets a profile field to one value of an enum, saying what it did (L.<FIELD>_<VALUE>).
---@param word string the command, also the profile field
---@param enum table<string, string>
---@param values string[] the enum's values in the order the list shows them
---@param help string
local function AddChoice(word, enum, values, help)
    AddCommand(word, table.concat(values, "|"), help, function(rest)
        local value = enum[rest:lower()]
        if not value then
            Usage()
            return
        end
        Addon.db.profile[word] = value
        Addon:Print(L[word:upper() .. "_" .. value:upper()])
        Addon:UpdateCatchWindow()
    end)
end

AddCommand("options", "", L.HELP_OPTIONS, function()
    Addon:OpenOptions()
end)
AddChoice("show", Addon.showModes, { "pole", "always", "never" }, L.HELP_SHOW)
AddChoice("scope", Addon.scopes, { "area", "zone" }, L.HELP_SCOPE)
AddChoice("view", Addon.views, Addon.VIEW_ORDER, L.HELP_VIEW)
-- Left out of the list: the options' other name.
commands.config = commands.options

---@param line string
local function OnSlash(line)
    local word, rest = strsplit(" ", strtrim(line), 2)
    local command = commands[word:lower()]
    if command then
        command.run(strtrim(rest or ""))
    else
        Usage()
    end
end

function Addon:SetupCommands()
    self:RegisterChatCommand(self.NAME:lower(), OnSlash)
    self:RegisterChatCommand(self.SLASH_ALIAS, OnSlash)
end
