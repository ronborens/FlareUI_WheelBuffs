local addonName, ns = ...

--------------------------------------------------
-- OPTIONS (the same file in each of the FlareUI extensions)
-- Saved settings, shown in three places: inside FlareUI's own settings window (beside the options they
-- belong with), on a page in the game's Options > AddOns list, and through a slash command that opens
-- that page. Should a FlareUI update change its settings window, or the game's page fail to build,
-- the others still set every option.
--------------------------------------------------

-- Saved settings: a missing one takes its default
function ns.InitDB(name, defaults)
    local db = _G[name]
    if type(db) ~= "table" then
        db = {}
        _G[name] = db
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    ns.db, ns.defaults = db, defaults
    return db
end

function ns.Print(text)
    print("|cff00ccff" .. (ns.title or addonName) .. ":|r " .. text)
end

local function ValueText(row, value)
    if row.choices then
        for _, choice in ipairs(row.choices) do
            if choice[1] == value then return choice[2] end
        end
        return tostring(value)
    end
    return value and "on" or "off"
end

-- A row inside FlareUI's settings window. FlareUI builds the window from a list of rows (its
-- Settings:Row) and takes every text from a table by row key (its Copy.rows): both are filled in here.
-- row.flare: { key = "ab.extName" (FlareUI's page, then a name of our own), section, tab, half,
-- sectionTitle (for a section of our own) }
local function AddFlareRow(row, Set)
    local F = _G.FlareUI
    local S, Copy = type(F) == "table" and F.Settings, type(F) == "table" and F.Copy
    if not (type(S) == "table" and type(S.Row) == "function" and type(Copy) == "table" and type(Copy.rows) == "table") then
        return
    end
    local where = row.flare
    local values, labels
    if row.choices then
        values, labels = {}, {}
        for i, choice in ipairs(row.choices) do values[i], labels[i] = choice[1], choice[2] end
    end
    if where.sectionTitle and type(Copy.sections) == "table" and not Copy.sections[where.section] then
        Copy.sections[where.section] = where.sectionTitle
    end
    Copy.rows[where.key] = { label = row.label, desc = row.tip, section = where.section, choices = labels,
                             tags = { "extension" } }
    S:Row{
        key = where.key, kind = row.choices and "choice" or nil, choices = values,
        section = where.section, tab = where.tab, half = where.half,
        get = function()
            local value = ns.db and ns.db[row.key]
            if row.choices then return value end
            return value and true or false
        end,
        set = function(value) Set(row.key, value) end,
    }
end

-- rows: { key = "enabled", label = "...", tip = "...", choices = { { value, label }, ... }, flare = {...} }
-- (no choices: a checkbox). slash: "/name". onChange(key, value): after a setting changed.
function ns.RegisterOptions(title, rows, slash, onChange)
    ns.title = title

    local function Set(key, value)
        if not ns.db then return end
        ns.db[key] = value
        if onChange then onChange(key, value) end
    end

    for _, row in ipairs(rows) do
        if row.flare then pcall(AddFlareRow, row, Set) end
    end

    local category
    pcall(function()
        local made = Settings.RegisterVerticalLayoutCategory(title)
        for _, row in ipairs(rows) do
            local variable = addonName .. "_" .. row.key
            local get = function() return ns.db[row.key] end
            local set = function(value) Set(row.key, value) end
            if row.choices then
                local setting = Settings.RegisterProxySetting(made, variable, Settings.VarType.String, row.label,
                    ns.defaults[row.key], get, set)
                Settings.CreateDropdown(made, setting, function()
                    local container = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(row.choices) do container:Add(choice[1], choice[2]) end
                    return container:GetData()
                end, row.tip)
            else
                local setting = Settings.RegisterProxySetting(made, variable, Settings.VarType.Boolean, row.label,
                    ns.defaults[row.key], get, set)
                Settings.CreateCheckbox(made, setting, row.tip)
            end
        end
        Settings.RegisterAddOnCategory(made)
        category = made
    end)

    local function List()
        ns.Print("options (" .. slash .. " <option> <value>):")
        for _, row in ipairs(rows) do
            local values = "on / off"
            if row.choices then
                local list = {}
                for _, choice in ipairs(row.choices) do list[#list + 1] = tostring(choice[1]) end
                values = table.concat(list, " / ")
            end
            print(("  %s = %s  (%s: %s)"):format(row.key, ValueText(row, ns.db[row.key]), row.label, values))
        end
    end

    local id = addonName:upper()
    _G["SLASH_" .. id .. "1"] = slash
    SlashCmdList[id] = function(text)
        local key, value = (text or ""):lower():match("^%s*(%S+)%s*(%S*)")
        if not key then
            if category and not InCombatLockdown() and pcall(Settings.OpenToCategory, category:GetID()) then return end
            List()
            return
        end
        for _, row in ipairs(rows) do
            if row.key:lower() == key then
                if row.choices then
                    for _, choice in ipairs(row.choices) do
                        if tostring(choice[1]):lower() == value then
                            Set(row.key, choice[1])
                            ns.Print(row.label .. ": " .. choice[2])
                            return
                        end
                    end
                elseif value == "on" or value == "off" or value == "" then
                    local on = value == "on" or (value == "" and not ns.db[row.key])
                    Set(row.key, on)
                    ns.Print(row.label .. ": " .. (on and "on" or "off"))
                    return
                end
            end
        end
        List()
    end
end

-- start(): once the player is in the world and FlareUI has set itself up
function ns.OnReady(dbName, defaults, setup, start)
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self, event, name)
        if event == "ADDON_LOADED" then
            if name ~= addonName then return end
            self:UnregisterEvent("ADDON_LOADED")
            ns.InitDB(dbName, defaults)
            setup()
        else
            self:UnregisterEvent("PLAYER_LOGIN")
            C_Timer.After(0, start)
        end
    end)
end
