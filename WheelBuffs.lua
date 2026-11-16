local _, ns = ...

--------------------------------------------------
-- CAST MISSING BUFFS ON MOUSE WHEEL (an extension for FlareUI's Buff Reminders)
-- While a reminder's spell is missing, scrolling the mouse wheel casts it, and zooms the camera as the
-- wheel did. The game only casts from a key or a click, so the wheel's zoom keys are bound, for that
-- while, to a hidden secure button holding the spell (an override binding: the player's own bindings
-- are untouched and back the moment it is cleared); the button's PostClick does the zoom.
-- Only wheel keys bound to the camera's zoom are taken. Only a reminder that casts a plain spell: no
-- item is used and no macro run by a scroll. With nothing to cast the binding is cleared, so the
-- wheel is the game's own again. Bindings and a secure button's spell can't change in a fight, and
-- buffs can't be read there: the binding is cleared as one begins.
-- The reminders showing come from FlareUI: its Buff Reminders hand their list to BR.ShowFaded after
-- every check, and this addon listens in.
--------------------------------------------------
local Wheel = { KEYS = { MOUSEWHEELUP = "CAMERAZOOMIN", MOUSEWHEELDOWN = "CAMERAZOOMOUT" } }
ns.Wheel = Wheel

local DEFAULTS = { enabled = true, selfOnly = true }

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

-- list: the reminders showing now
function Wheel.Set(list)
    if InCombatLockdown() then return end
    local castID, unit
    if ns.db and ns.db.enabled and type(list) == "table" and not EditPreviewing() then
        castID, unit = Wheel.Pick(list)
    end
    if not castID then
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
Wheel.events:SetScript("OnEvent", Wheel.Clear)

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
          flare = { key = "br.extCastOnWheel", section = "br.alertsSection", tab = "alerts" },
          tip = "While one of FlareUI's Buff Reminders shows a missing buff, scrolling the mouse wheel casts it and still zooms the camera. Out of combat only. Spells only: no items or macros. Only wheel keys bound to camera zoom. With nothing missing the wheel is left exactly as it is." },
        { key = "selfOnly", label = "Only Buffs on Myself",
          flare = { key = "br.extWheelSelfOnly", section = "br.alertsSection", tab = "alerts" },
          tip = "The wheel never casts a buff that is missing on someone else in your group, only on you. Switch this off to let a scroll buff your group too." },
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
