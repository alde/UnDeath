local UnDeath = LibStub("AceAddon-3.0"):NewAddon("UnDeath", "AceConsole-3.0", "AceEvent-3.0")
_G.UnDeath = UnDeath

UnDeath:SetDefaultModuleState(false)
UnDeath.VERSION = "1"

local FROST_DK_SPEC_ID = 251

UnDeath.PILLAR_ID = 51271
UnDeath.KM_ID = 51124
UnDeath.RIME_ID = 59052

local lastDebugMsg = ""
function UnDeath:Debug(...)
    if not (self.db and self.db.profile.debug) then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    local msg = table.concat(parts, " ")
    if msg == lastDebugMsg then return end
    lastDebugMsg = msg
    self:Print("|cff888888[debug]|r", msg)
end

UnDeath.state = {
    history = {},
    lastSpellId = nil,
    kmWasted = false,
    combat = nil,
    keystone = nil,
    auras = {},
}

function UnDeath:IsFrostDK()
    local spec = GetSpecialization()
    return spec and GetSpecializationInfo(spec) == FROST_DK_SPEC_ID
end

function UnDeath:GetClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0.77, 0.12, 0.23
end

function UnDeath:GetGlowColor()
    local c = self.db.profile.pillarGlowColor
    if c then return c.r, c.g, c.b end
    return self:GetClassColor()
end

function UnDeath:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("UnDeathDB", self:GetDefaults(), true)
    self:RegisterChatCommand("undeath", "OnSlashCommand")
    self:RegisterChatCommand("ud", "OnSlashCommand")
    if not SlashCmdList["RELOADUI"] then
        self:RegisterChatCommand("rl", function() ReloadUI() end)
    end
end

function UnDeath:OnEnable()
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    local config = self:GetModule("Config", true)
    if config then config:Enable() end

    if self:IsFrostDK() then
        self:EnableModules()
    end
end

function UnDeath:PLAYER_SPECIALIZATION_CHANGED(_, unit)
    if unit and unit ~= "player" then return end

    if self:IsFrostDK() then
        self:EnableModules()
    else
        self:DisableModules()
    end
end

function UnDeath:EnableModules()
    for _, name in ipairs({ "Auras", "Core", "Display", "Timeline" }) do
        local mod = self:GetModule(name, true)
        if mod and not mod:IsEnabled() then
            mod:Enable()
        end
    end
end

function UnDeath:DisableModules()
    wipe(self.state.history)
    self.state.lastSpellId = nil
    self.state.kmWasted = false

    for _, name in ipairs({ "Timeline", "Display", "Core", "Auras" }) do
        local mod = self:GetModule(name, true)
        if mod and mod:IsEnabled() then
            mod:Disable()
        end
    end

    local display = self:GetModule("Display", true)
    if display and display.frame then
        display.frame:Hide()
    end
end

function UnDeath:CreateMovableFrame(name, positionKey, defaults)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(defaults.width or 48, defaults.height or 48)
    if defaults.backdrop then
        f:SetBackdrop(defaults.backdrop)
        if defaults.backdropColor then
            f:SetBackdropColor(unpack(defaults.backdropColor))
        end
        if defaults.borderColor then
            f:SetBackdropBorderColor(unpack(defaults.borderColor))
        end
    end
    f:SetFrameStrata(defaults.strata or "MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not UnDeath.db.profile.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        UnDeath.db.profile[positionKey] = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local pos = UnDeath.db.profile[positionKey]
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint(defaults.defaultPoint or "CENTER", UIParent,
            defaults.defaultRelPoint or "CENTER",
            defaults.defaultX or 0, defaults.defaultY or 0)
    end

    return f
end

function UnDeath:ToggleDisplay()
    self:GetModule("Display"):Toggle()
end

function UnDeath:SetLocked(locked)
    self.db.profile.locked = locked
    local display = self:GetModule("Display", true)
    if display then display:ApplyLock() end
end

function UnDeath:ToggleLock()
    self:SetLocked(not self.db.profile.locked)
    self:Print("Panel " .. (self.db.profile.locked and "locked" or "unlocked") .. ".")
end

function UnDeath:OnSlashCommand(input)
    local cmd = self:GetArgs(input, 1)
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        self:ToggleDisplay()
    elseif cmd == "config" or cmd == "options" then
        self:OpenConfig()
    elseif cmd == "timeline" or cmd == "tl" then
        self:ToggleTimeline()
    elseif cmd == "lock" then
        self:ToggleLock()
    elseif cmd == "reset" then
        wipe(self.state.history)
        self.state.lastSpellId = nil
        self.state.kmWasted = false
        self:SendMessage("UNDEATH_HISTORY_UPDATED")
        self:Print("History cleared.")
    elseif cmd == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print("Debug " .. (self.db.profile.debug and "enabled" or "disabled") .. ".")
    elseif cmd == "test" then
        self:GetModule("Core"):InjectTestData()
    else
        self:Print("UnDeath v" .. self.VERSION)
        self:Print("  /ud            — Toggle display")
        self:Print("  /ud config     — Open options")
        self:Print("  /ud timeline   — Show last encounter timeline")
        self:Print("  /ud lock       — Lock/unlock frame")
        self:Print("  /ud reset      — Clear history")
        self:Print("  /ud debug      — Toggle debug logging")
        self:Print("  /ud test       — Inject test data")
    end
end

function UnDeath:ToggleTimeline()
    self:GetModule("Timeline"):Toggle()
end

function UnDeath:OpenConfig()
    if InCombatLockdown() then
        self:Print("Cannot open settings during combat.")
        return
    end
    local config = self:GetModule("Config", true)
    if config and config.optionsFrame then
        local id = config.optionsFrame.name or config.optionsFrame
        Settings.OpenToCategory(id)
    end
end
