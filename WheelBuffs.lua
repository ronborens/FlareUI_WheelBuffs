local _, ns = ...

--------------------------------------------------
-- CAST MISSING BUFFS ON MOUSE WHEEL (an extension for FlareUI's Buff Reminders)
-- While a reminder's spell is missing, scrolling the mouse wheel casts it, and zooms the camera as the
-- wheel did. The game only casts from a key or a click, so the wheel's zoom keys are bound, for that
-- while, to a hidden secure button holding the spell (an override binding: the player's own bindings
-- are untouched and back the moment it is cleared); the button's PostClick does the zoom.
-- Only on foot and in your own shape: never mounted, and never in a druid's form or Ghost Wolf, which a
-- cast would end. Only wheel keys bound to the camera's zoom are taken. Only a reminder that casts a plain spell: no
-- item is used and no macro run by a scroll. With nothing to cast the binding is cleared, so the
-- wheel is the game's own again. Bindings and a secure button's spell can't change in a fight, and
-- buffs can't be read there: the binding is cleared as one begins.
-- The reminders showing come from FlareUI: its Buff Reminders hand their list to BR.ShowFaded after
-- every check, and this addon listens in.
--------------------------------------------------
local Wheel = { KEYS = { MOUSEWHEELUP = "CAMERAZOOMIN", MOUSEWHEELDOWN = "CAMERAZOOMOUT" } }
ns.Wheel = Wheel

local DEFAULTS = { enabled = true, selfOnly = true, minMana = 0 }

local function Reminders()
    local F = _G.FlareUI
    local BR = type(F) == "table" and F.BuffReminders
    return type(BR) == "table" and BR or nil
end

local function EditPreviewing()
    local F = _G.FlareUI
    if type(F) ~= "table" or type(F.EditPreviewing) ~= "function" then return false end
    local ok, previewing = pcall(F.EditPreviewing)
    return ok and previewing and true or false
end

-- the first reminder a scroll may cast: missing (not just running out), and a plain spell
function Wheel.Pick(list)
    local selfOnly = ns.db.selfOnly
    for _, s in ipairs(list) do
        local castID = s.castID or (s.entry and s.entry.castID)
        local action = s.action
        local unit = s.unit or "player"
        if castID and not s.running and not (action and (action.item or action.macro or action.none))
            and not (selfOnly and unit ~= "player") then
            return castID, unit
        end
    end
end

local function Button()
    local b = Wheel.button
    if b then return b end
    b = CreateFrame("Button", "FlareUI_WheelBuffsButton", UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    -- the zoom the wheel key had; once per scroll (a click can come as a press and a release)
    b:SetScript("PostClick", function(self, zoom)
        local now = GetTime()
        if self.zoomedAt == now then return end
        self.zoomedAt = now
        if zoom == "CAMERAZOOMIN" then CameraZoomIn(1) elseif zoom == "CAMERAZOOMOUT" then CameraZoomOut(1) end
    end)
    Wheel.button = b
    return b
end

function Wheel.Clear()
    if not Wheel.bound or InCombatLockdown() then return end
    Wheel.bound = false
    ClearOverrideBindings(Wheel.button)
end

-- Mounted, eating or drinking, busy with a cast or channel, or in another shape (a druid's forms, a
-- shaman's Ghost Wolf): a cast would dismount you, stand you up, cut the other cast short or drop the
-- form, so the wheel is left alone until you are on foot, free and in your own shape again
-- Eating or drinking: the buff every food and drink puts on you while you sit, known by its name in
-- the game's language ("Food", "Drink": spells 433 and 430) or by its icon. A cast would stand you up
-- and waste the food.
local MEAL_SPELLS = { 433, 430 }
local MEAL_ICONS = { [134062] = true, [132794] = true }   -- the fork and knife, the water glass
local mealNames
function Wheel.Eating()
    if not mealNames then
        mealNames = {}
        for _, id in ipairs(MEAL_SPELLS) do
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
            if name then mealNames[name] = true end
        end
    end
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura or (canaccessvalue and not canaccessvalue(aura)) then break end
        local name, icon = aura.name, aura.icon
        if canaccessvalue == nil or (canaccessvalue(name) and canaccessvalue(icon)) then
            if (name and mealNames[name]) or (icon and MEAL_ICONS[icon]) then return true end
        end
    end
    return false
end

-- In the middle of something a cast would cut short: any cast or channel (a bandage, fishing, the
-- hearthstone, a profession, gathering), hidden in stealth, feigning death, or dead. A value the game
-- won't let an addon read counts as busy.
function Wheel.Occupied()
    local ok, casting = pcall(UnitCastingInfo, "player")
    if not ok or casting ~= nil then return true end
    local okChannel, channel = pcall(UnitChannelInfo, "player")
    if not okChannel or channel ~= nil then return true end
    if IsStealthed and IsStealthed() then return true end
    if UnitIsDeadOrGhost("player") then return true end
    if UnitIsFeignDeath and UnitIsFeignDeath("player") then return true end
    return false
end

-- Only Above Mana: your mana, as a share of the whole, is under the setting. A class without mana, or
-- mana the game won't let an addon read, never counts as low.
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
function Wheel.LowMana()
    local floor = tonumber(ns.db and ns.db.minMana) or 0
    if floor <= 0 then return false end
    local ok, mana, max = pcall(function() return UnitPower("player", MANA), UnitPowerMax("player", MANA) end)
    if not ok or type(mana) ~= "number" or type(max) ~= "number" then return false end
    if canaccessvalue and not (canaccessvalue(mana) and canaccessvalue(max)) then return false end
    if max <= 0 then return false end
    return mana / max * 100 < floor
end

local shifter   -- this class changes shape
function Wheel.Busy()
    if IsMounted() or Wheel.Occupied() or Wheel.LowMana() or Wheel.Eating() then return true end
    if shifter == nil then
        local _, class = UnitClass("player")
        if class then shifter = class == "DRUID" or class == "SHAMAN" end
    end
    return shifter and (GetShapeshiftForm() or 0) > 0 or false
end

-- list: the reminders showing now
function Wheel.Set(list)
    if InCombatLockdown() then return end
    local castID, unit
    if ns.db and ns.db.enabled and type(list) == "table" and not EditPreviewing() then
        castID, unit = Wheel.Pick(list)
    end
    Wheel.wanted, Wheel.wantedUnit = castID, unit   -- (kept for Wheel.Again)
    Wheel.Bind(castID, unit)
end

-- You mounted, dismounted or changed shape: the same reminder, bound or let go as it now stands
function Wheel.Again()
    if InCombatLockdown() then return end
    Wheel.Bind(Wheel.wanted, Wheel.wantedUnit)
end

function Wheel.Bind(castID, unit)
    local busy = Wheel.Busy()
    Wheel.wasBusy = busy
    if not castID or busy then
        Wheel.Clear()
        return
    end
    local b = Button()
    b:SetAttribute("type", "spell")
    -- by name: the game casts your highest rank
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(castID)
    b:SetAttribute("spell", name or castID)
    b:SetAttribute("unit", unit)
    ClearOverrideBindings(b)
    Wheel.bound = false
    for key, zoom in pairs(Wheel.KEYS) do
        if GetBindingAction(key) == zoom then
            SetOverrideBindingClick(b, false, key, b:GetName(), zoom)
            Wheel.bound = true
        end
    end
end

-- a fight begins (this comes just before the lockdown): the wheel is the game's own in it
Wheel.events = CreateFrame("Frame")
Wheel.events:RegisterEvent("PLAYER_REGEN_DISABLED")
Wheel.events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
Wheel.events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
Wheel.events:RegisterEvent("UPDATE_STEALTH")
Wheel.events:RegisterEvent("PLAYER_DEAD")
Wheel.events:RegisterEvent("PLAYER_ALIVE")
Wheel.events:RegisterEvent("PLAYER_UNGHOST")
Wheel.events:RegisterUnitEvent("UNIT_AURA", "player")
Wheel.events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")   -- (Only Above Mana)
Wheel.events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                         "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    pcall(Wheel.events.RegisterUnitEvent, Wheel.events, event, "player")
end

-- These events come all the time: the wheel is only touched when being busy starts or ends
function Wheel.Check()
    if InCombatLockdown() then return end
    if Wheel.Busy() ~= Wheel.wasBusy then Wheel.Again() end
end

Wheel.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        Wheel.Clear()
        return
    end
    Wheel.Check()
    -- (a cast that has just ended can still read as running in the same moment: looked at again next frame)
    if not Wheel.rechecking then
        Wheel.rechecking = true
        C_Timer.After(0, function()
            Wheel.rechecking = false
            Wheel.Check()
        end)
    end
end)

-- FlareUI checks the reminders again (the list comes back through the hook below)
local function Recheck()
    local BR = Reminders()
    if BR and type(BR.Refresh) == "function" and not InCombatLockdown() then
        pcall(BR.Refresh, BR)
    end
    if not (ns.db and ns.db.enabled) then Wheel.Clear() end
end

local started = false
ns.OnReady("FlareUI_WheelBuffsDB", DEFAULTS, function()
    ns.RegisterOptions("FlareUI: Cast Missing Buffs on Mouse Wheel", {
        { key = "enabled", label = "Cast on Mouse Wheel",
          flare = { key = "br.extCastOnWheel", section = "br.alertsSection", tab = { "alerts", "when" } },
          tip = "While one of FlareUI's Buff Reminders shows a missing buff, scrolling the mouse wheel casts it and still zooms the camera. Only out of combat, unmounted, in your normal form, and when you are not eating, drinking, bandaging or casting something else. Spells only: no items or macros. Only wheel keys bound to camera zoom. With nothing missing the wheel is left exactly as it is." },
        { key = "selfOnly", label = "Only Buffs on Myself",
          flare = { key = "br.extWheelSelfOnly", section = "br.alertsSection", tab = { "alerts", "when" } },
          tip = "The wheel never casts a buff that is missing on someone else in your group, only on you. Switch this off to let a scroll buff your group too." },
        { key = "minMana", label = "Only Above Mana", slider = true,
          flare = { key = "br.extWheelMinMana", section = "br.alertsSection", tab = { "alerts", "when" } },
          tip = "The wheel only casts while your mana is at or above this much, so a scroll never spends mana you are saving or waiting to regain. Off: it casts at any mana.",
          choices = { { 0, "Off" }, { 10, "10%" }, { 20, "20%" }, { 30, "30%" }, { 40, "40%" }, { 50, "50%" },
                      { 60, "60%" }, { 70, "70%" }, { 80, "80%" }, { 90, "90%" } } },
    }, "/flarewheel", function() if started then Recheck() end end)
end, function()
    started = true
    local BR = Reminders()
    if not BR or type(BR.ShowFaded) ~= "function" then
        ns.Print("FlareUI's Buff Reminders were not found (this FlareUI version may have changed them), so the mouse wheel is left alone.")
        return
    end
    -- a check that ends early (reminders switched off, a fight) shows no list: the wheel is given back
    local listed = false
    hooksecurefunc(BR, "ShowFaded", function(list)
        listed = true
        Wheel.Set(list)
    end)
    if type(BR.Update) == "function" then
        hooksecurefunc(BR, "Update", function()
            if not listed then Wheel.Clear() end
            listed = false
        end)
    end
    Recheck()
end)
