local UnDeath = _G.UnDeath
local Display = UnDeath:NewModule("Display", "AceEvent-3.0")
local MSQ = LibStub("Masque", true)

local PADDING = 4
local BORDER_SIZE = 2

local PILLAR_FLASH_DURATION = 3.0
local ASSISTED_COMBAT_POLL = 0.1

local msqHistory, msqPillar, msqAssisted
if MSQ then
    msqHistory = MSQ:Group("UnDeath", "Ability History")
    msqPillar = MSQ:Group("UnDeath", "Pillar of Frost")
    msqAssisted = MSQ:Group("UnDeath", "Next Spell")
end

local MASQUE_DISABLED = {
    Normal = false, Pushed = false, Highlight = false,
    Checked = false, Flash = false, Disabled = false,
    AutoCastable = false,
}

local function MasqueRegister(group, frame, icon, extras)
    if not group then return end
    local regions = { Icon = icon }
    for k, v in pairs(MASQUE_DISABLED) do regions[k] = v end
    if extras then
        for k, v in pairs(extras) do regions[k] = v end
    end
    group:AddButton(frame, regions)
end

local function CreateUnlockOverlay(frame, labelText)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameStrata("TOOLTIP")

    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(labelText)
    label:SetTextColor(1, 1, 1)

    overlay:Hide()
    frame.unlockOverlay = overlay
    return overlay
end

function Display:OnEnable()
    self:RegisterMessage("UNDEATH_HISTORY_UPDATED", "Refresh")
    self:RegisterMessage("UNDEATH_PILLAR_READY", "OnPillarReady")
    self:RegisterMessage("UNDEATH_PILLAR_COOLDOWN", "OnPillarCooldown")
    self:RegisterMessage("UNDEATH_COOLDOWN_IDLE", "OnCooldownIdle")
    self:RegisterMessage("UNDEATH_RIME_EXPIRED", "OnRimeExpired")
    self:RegisterMessage("UNDEATH_KM_WASTE", "OnKMWaste")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Display:OnDisable()
    self:UnregisterAllMessages()
    self:UnregisterAllEvents()
    if self.assistedFrame then self.assistedFrame:Hide() end
    self:HidePillarIcon()
    self:HideWarning()
end

function Display:GetFrame()
    if self.frame then return self.frame end

    local f = UnDeath:CreateMovableFrame("UnDeathPanel", "position", {
        defaultY = -200,
    })
    f.icons = {}
    self.frame = f
    CreateUnlockOverlay(f, "Ability Panel")
    UnDeath:ApplyAppearance()
    self:ApplyLock()
    self:LayoutFrame()

    return f
end

function Display:ShouldShowAssisted()
    return UnDeath.db.profile.assistedCombat
        and C_AssistedCombat ~= nil
        and C_AssistedCombat.GetNextCastSpell ~= nil
end

local function IsVertical(dir)
    return dir == "up" or dir == "down"
end

function Display:LayoutFrame()
    local f = self:GetFrame()
    local db = UnDeath.db.profile
    local iconSize = db.iconSize
    local visible = math.min(#UnDeath.state.history, db.historyCount)
    if visible == 0 then visible = 1 end

    local span = (iconSize * visible) + (PADDING * (visible - 1)) + (BORDER_SIZE * 2) + 8

    if IsVertical(db.growDirection) then
        local w = iconSize + (BORDER_SIZE * 2) + 8
        f:SetSize(w, span)
    else
        local h = iconSize + (BORDER_SIZE * 2) + 8
        f:SetSize(span, h)
    end
end

function Display:GetIcon(index)
    local f = self.frame
    if f.icons[index] then return f.icons[index] end

    local container = CreateFrame("Frame", nil, f)

    local border = container:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    if msqHistory then border:Hide() end
    container.border = border

    local icon = container:CreateTexture(nil, "ARTWORK")
    if msqHistory then
        icon:SetAllPoints()
    else
        icon:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
        icon:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    container.icon = icon

    local glow = container:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    container.glow = glow

    MasqueRegister(msqHistory, container, icon, { Border = glow })

    f.icons[index] = container
    return container
end

local GROW_CONFIG = {
    right = { anchor = "BOTTOMLEFT", xMul = 1,  yMul = 0 },
    left  = { anchor = "BOTTOMRIGHT", xMul = -1, yMul = 0 },
    up    = { anchor = "BOTTOMLEFT", xMul = 0,  yMul = 1 },
    down  = { anchor = "TOPLEFT",    xMul = 0,  yMul = -1 },
}

function Display:Refresh()
    local f = self:GetFrame()
    if not f:IsShown() then return end

    local db = UnDeath.db.profile
    local history = UnDeath.state.history
    local count = db.historyCount
    local baseSize = db.iconSize
    local grow = GROW_CONFIG[db.growDirection] or GROW_CONFIG.right

    self:LayoutFrame()

    local offset = BORDER_SIZE + 4
    for i = 1, count do
        local container = self:GetIcon(i)
        local entry = history[i]

        if entry then
            local age = i - 1
            local scale = math.max(0.6, 1.0 - (age * 0.06))
            local alpha = db.iconAlpha * math.max(db.minOpacity, 1.0 - (age * db.opacityStep))
            local iconPixels = math.floor(baseSize * scale)

            container:SetSize(iconPixels, iconPixels)
            container.glow:SetSize(iconPixels * 1.7, iconPixels * 1.7)
            container:ClearAllPoints()
            container:SetPoint(grow.anchor, f, grow.anchor,
                offset * grow.xMul + (grow.xMul == 0 and (BORDER_SIZE + 4) or 0),
                offset * grow.yMul + (grow.yMul == 0 and (4 + BORDER_SIZE) or 0))
            container:SetAlpha(alpha)

            local spellInfo = C_Spell.GetSpellInfo(entry.spellId)
            local texture = spellInfo and spellInfo.iconID
            container.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

            if entry.kmWaste then
                if not msqHistory then
                    container.border:SetColorTexture(0.9, 0.1, 0.1, 1.0)
                end
                container.glow:SetVertexColor(1, 0, 0)
                container.glow:SetAlpha(0.6)
            else
                if not msqHistory then
                    container.border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                end
                container.glow:SetAlpha(0)
            end

            container:Show()
            offset = offset + iconPixels + PADDING
        else
            container:Hide()
        end
    end

    for i = count + 1, #f.icons do
        f.icons[i]:Hide()
    end

    if msqHistory then msqHistory:ReSkin() end

    self:RefreshAssisted()
end

local function IsCombatVisible(combatOnlySetting)
    return not combatOnlySetting or UnitAffectingCombat("player")
end

function Display:ApplyLock()
    local locked = UnDeath.db.profile.locked
    if not locked then
        self:GetWarningFrame()
        self:GetAssistedFrame()
        self:GetPillarIcon()
    end
    local frames = { self.frame, self.pillarIcon, self.assistedFrame, self.warningFrame }
    for _, f in ipairs(frames) do
        if f then
            f:EnableMouse(not locked)
            if f.unlockOverlay then
                if locked then
                    f.unlockOverlay:Hide()
                else
                    f:Show()
                    f:SetAlpha(1)
                    f.unlockOverlay:Show()
                end
            end
        end
    end

    if locked then
        self:UpdatePanelVisibility()
        self:RefreshAssisted()
        if self.pillarIcon then
            local core = UnDeath:GetModule("Core", true)
            if core and core.pillarReady then
                self.pillarIcon:SetAlpha(UnDeath.db.profile.pillarIconAlpha)
            else
                self.pillarIcon:SetAlpha(0)
            end
        end
        self:HideWarning()
    end
end

function Display:UpdatePanelVisibility()
    local f = self:GetFrame()
    local db = UnDeath.db.profile
    if db.shown then
        f:Show()
        f:SetAlpha(IsCombatVisible(db.panelCombatOnly) and 1 or 0)
    else
        f:SetAlpha(0)
    end
end

function Display:Toggle()
    local db = UnDeath.db.profile
    db.shown = not db.shown
    self:UpdatePanelVisibility()
    if db.shown then self:Refresh() end
end

function Display:PLAYER_ENTERING_WORLD()
    keybindCacheDirty = true
    self:UpdatePanelVisibility()
    if UnDeath.db.profile.shown then self:Refresh() end
end

function Display:PLAYER_REGEN_DISABLED()
    keybindCacheDirty = true
    self:UpdatePanelVisibility()
    local db = UnDeath.db.profile
    if db.pillarCombatOnly and self.pillarIcon and self.pillarIcon:IsShown() then
        self:SetPillarIconAlpha(db.pillarIconAlpha)
    end
end

function Display:PLAYER_REGEN_ENABLED()
    self:UpdatePanelVisibility()
    self:HideWarning()
    if UnDeath.db.profile.pillarCombatOnly then
        self:SetPillarIconAlpha(0)
    end
end

-- Assisted Combat — standalone movable frame

local ICON_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

function Display:GetAssistedFrame()
    if self.assistedFrame then return self.assistedFrame end

    local size = UnDeath.db.profile.iconSize
    local af = UnDeath:CreateMovableFrame("UnDeathAssistedIcon", "assistedPosition", {
        width = size, height = size,
        backdrop = not MSQ and ICON_BACKDROP or nil,
        backdropColor = { 0.05, 0.05, 0.1, 0.8 },
        borderColor = { 0.4, 0.6, 0.9, 0.8 },
        defaultX = 60, defaultY = -200,
    })

    local icon = af:CreateTexture(nil, "ARTWORK")
    if MSQ then
        icon:SetAllPoints()
    else
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    af.icon = icon

    local keybind = af:CreateFontString(nil, "OVERLAY")
    keybind:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, math.floor(size * 0.25)), "OUTLINE")
    keybind:SetPoint("TOPLEFT", 4, -3)
    keybind:SetTextColor(1, 1, 1)
    af.keybind = keybind

    MasqueRegister(msqAssisted, af, icon, { HotKey = keybind })

    af.elapsed = 0
    af:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.elapsed < ASSISTED_COMBAT_POLL then return end
        self.elapsed = 0
        Display:UpdateAssisted()
    end)

    CreateUnlockOverlay(af, "Next Spell")
    af:Hide()
    self.assistedFrame = af
    self:ApplyLock()
    return af
end

function Display:RefreshAssisted()
    if not self:ShouldShowAssisted() then
        if self.assistedFrame then self.assistedFrame:Hide() end
        return
    end

    local af = self:GetAssistedFrame()
    local db = UnDeath.db.profile
    local size = db.iconSize
    af:SetSize(size, size)
    af.keybind:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, math.floor(size * 0.25)), "OUTLINE")
    af:Show()
    self:UpdateAssisted()
end

-- Keybinding lookup

local ACTION_BAR_BINDINGS = {
    { prefix = "ACTIONBUTTON",           offset = 0 },
    { prefix = "MULTIACTIONBAR1BUTTON",  offset = 60 },
    { prefix = "MULTIACTIONBAR2BUTTON",  offset = 48 },
    { prefix = "MULTIACTIONBAR3BUTTON",  offset = 24 },
    { prefix = "MULTIACTIONBAR4BUTTON",  offset = 36 },
    { prefix = "MULTIACTIONBAR5BUTTON",  offset = 72 },
    { prefix = "MULTIACTIONBAR6BUTTON",  offset = 84 },
    { prefix = "MULTIACTIONBAR7BUTTON",  offset = 96 },
    { prefix = "MULTIACTIONBAR8BUTTON",  offset = 108 },
}

local function ShortenKey(key)
    if not key then return nil end
    key = key:gsub("SHIFT%-", "s-")
    key = key:gsub("CTRL%-", "c-")
    key = key:gsub("ALT%-", "a-")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("MOUSEWHEELUP", "WU")
    key = key:gsub("MOUSEWHEELDOWN", "WD")
    return key
end

local keybindCache = {}
local keybindNameCache = {}
local keybindCacheDirty = true

local function CacheKey(id, key)
    if not id then return end
    local short = ShortenKey(key)
    local existing = keybindCache[id]
    if existing and #existing <= #short then return end
    keybindCache[id] = short
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        local existingName = keybindNameCache[info.name]
        if not existingName or #short < #existingName then
            keybindNameCache[info.name] = short
        end
    end
end

local function RebuildKeybindCache()
    if not keybindCacheDirty then return end
    keybindCacheDirty = false
    wipe(keybindCache)
    wipe(keybindNameCache)

    for _, bar in ipairs(ACTION_BAR_BINDINGS) do
        for i = 1, 12 do
            local key1, key2 = GetBindingKey(bar.prefix .. i)
            local key = key1 or key2
            local slot = bar.offset + i
            local actionType, id = GetActionInfo(slot)
            if key and id then
                if actionType == "spell" then
                    CacheKey(id, key)
                elseif actionType == "macro" then
                    local macroSpell = GetMacroSpell(id)
                    if macroSpell then
                        CacheKey(macroSpell, key)
                    else
                        CacheKey(id, key)
                    end
                end
            end
        end
    end

    UnDeath:Debug("--- Keybind cache ---")
    for id, key in pairs(keybindCache) do
        local info = C_Spell.GetSpellInfo(id)
        UnDeath:Debug("  ", id, info and info.name or "?", "->", key)
    end
end

local function GetSpellKeybind(spellId)
    RebuildKeybindCache()
    if keybindCache[spellId] then return keybindCache[spellId] end
    local info = C_Spell.GetSpellInfo(spellId)
    if info and info.name then return keybindNameCache[info.name] end
    return nil
end

function Display:UpdateAssisted()
    local af = self.assistedFrame
    if not af or not af:IsShown() then return end
    if not C_AssistedCombat then return end

    local spellId = C_AssistedCombat.GetNextCastSpell()
    if not spellId then
        af.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        af.icon:SetDesaturated(true)
        af.keybind:SetText("")
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    local texture = spellInfo and spellInfo.iconID
    af.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    af.icon:SetDesaturated(false)

    local key = GetSpellKeybind(spellId)
    UnDeath:Debug("Next spell:", spellId, spellInfo and spellInfo.name or "?", "key:", key or "none")
    af.keybind:SetText(key or "")
end

function Display:OnPillarReady(_, label)
    self:ShowWarning(label .. " READY", "info", PILLAR_FLASH_DURATION)
    self:ShowPillarIcon(label)
end

function Display:OnPillarCooldown()
    self:HidePillarIcon()
end

function Display:OnRimeExpired()
    self:ShowWarning("Rime expired!", "warning", 2)
end

function Display:OnKMWaste(_, spellId)
    local info = C_Spell.GetSpellInfo(spellId)
    local name = info and info.name or "?"
    self:ShowWarning("KM wasted: " .. name, "mistake", 2)
end

-- Text warning frame

local WARNING_COLORS = {
    info    = { text = { 0.4, 0.8, 1.0 },  border = { 0.3, 0.6, 0.9, 0.6 } },
    warning = { text = { 1.0, 0.8, 0.2 },  border = { 1.0, 0.7, 0.1, 0.6 } },
    mistake = { text = { 1.0, 0.3, 0.3 },  border = { 0.9, 0.1, 0.1, 0.6 } },
}

function Display:GetWarningFrame()
    if self.warningFrame then return self.warningFrame end

    local db = UnDeath.db.profile
    local wf = UnDeath:CreateMovableFrame("UnDeathWarning", "warningPosition", {
        width = 250, height = 28,
        backdrop = ICON_BACKDROP,
        backdropColor = { 0.05, 0.05, 0.05, db.warningBgAlpha },
        borderColor = { 0.5, 0.5, 0.5, db.warningBorderAlpha },
        defaultY = -240,
    })

    local label = wf:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    label:SetPoint("CENTER")
    wf.label = label

    local ag = wf:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.5)
    pulse:SetToAlpha(1.0)
    pulse:SetDuration(0.6)
    pulse:SetSmoothing("IN_OUT")
    wf.ag = ag

    CreateUnlockOverlay(wf, "Text Warnings")
    wf:Hide()
    self.warningFrame = wf
    self:ApplyLock()
    return wf
end

function Display:ShowWarning(text, severity, duration, onUpdate)
    local wf = self:GetWarningFrame()
    local colors = WARNING_COLORS[severity] or WARNING_COLORS.warning
    local borderAlpha = UnDeath.db.profile.warningBorderAlpha

    wf.label:SetText(text)
    wf.label:SetTextColor(unpack(colors.text))
    local bc = colors.border
    wf:SetBackdropBorderColor(bc[1], bc[2], bc[3], borderAlpha)

    wf.ag:Stop()
    wf:SetScript("OnUpdate", onUpdate)
    wf:Show()
    wf:SetAlpha(1)
    wf.ag:Play()

    if duration then
        C_Timer.After(duration, function()
            if wf:IsShown() and wf.label:GetText() == text then
                Display:HideWarning()
            end
        end)
    end
end

function Display:HideWarning()
    if not self.warningFrame then return end
    self.warningFrame.ag:Stop()
    self.warningFrame:SetScript("OnUpdate", nil)
    self.warningFrame:SetAlpha(0)
end

function Display:OnCooldownIdle(_, spellId, spellName)
    if not UnDeath.db.profile.idleCooldownNag then return end

    local idleSince = GetTime() - UnDeath.db.profile.idleCooldownThreshold

    self:ShowWarning(spellName .. " available", "warning", nil, function()
        local elapsed = GetTime() - idleSince
        local wf = Display.warningFrame
        wf.label:SetText(string.format("%s available for %ds", spellName, elapsed))
        local info = C_Spell.GetSpellCooldown(spellId)
        if info and info.isActive then
            Display:HideWarning()
        end
    end)
end

-- Standalone movable Pillar of Frost ready icon

local FLIPBOOK_STYLES = {
    proc = {
        atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
        rows = 6, columns = 5, frames = 30, duration = 1.0,
        texPadding = 1.4,
    },
    ants = {
        texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
        rows = 5, columns = 5, frames = 22, duration = 0.3,
        frameW = 48, frameH = 48, texPadding = 1.25,
    },
}

local function StartFlipBookGlow(frame, size, entry, r, g, b)
    local texSize = size * (entry.texPadding or 1)

    if not frame._flipData then
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetPoint("CENTER")
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local anim = ag:CreateAnimation("FlipBook")
        frame._flipData = { tex = tex, ag = ag, anim = anim }
    end

    local d = frame._flipData
    d.tex:SetSize(texSize, texSize)
    if entry.atlas then
        d.tex:SetAtlas(entry.atlas)
    elseif entry.texture then
        d.tex:SetTexture(entry.texture)
    end
    d.tex:SetDesaturated(true)
    d.tex:SetVertexColor(r, g, b)
    d.tex:Show()
    d.anim:SetFlipBookRows(entry.rows or 6)
    d.anim:SetFlipBookColumns(entry.columns or 5)
    d.anim:SetFlipBookFrames(entry.frames or 30)
    d.anim:SetDuration(entry.duration or 1.0)
    d.anim:SetFlipBookFrameWidth(entry.frameW or 0)
    d.anim:SetFlipBookFrameHeight(entry.frameH or 0)
    if d.ag:IsPlaying() then d.ag:Stop() end
    d.ag:Play()
end

local function StopFlipBookGlow(frame)
    if not frame._flipData then return end
    frame._flipData.tex:Hide()
    frame._flipData.ag:Stop()
end

function Display:GetPillarIcon()
    if self.pillarIcon then return self.pillarIcon end

    local db = UnDeath.db.profile
    local size = db.pillarIconSize
    local gr, gg, gb = UnDeath:GetGlowColor()

    local f = UnDeath:CreateMovableFrame("UnDeathPillarIcon", "pillarIconPosition", {
        width = size, height = size,
        backdrop = not MSQ and ICON_BACKDROP or nil,
        backdropColor = { 0.05, 0.05, 0.05, 0.8 },
        borderColor = { gr, gg, gb, 0.9 },
        defaultY = -150,
    })

    local icon = f:CreateTexture(nil, "ARTWORK")
    if MSQ then
        icon:SetAllPoints()
    else
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon

    MasqueRegister(msqPillar, f, icon)

    local glow = CreateFrame("Frame", nil, f)
    glow:SetPoint("CENTER")
    glow:SetFrameLevel(f:GetFrameLevel() + 1)
    local glowTex = glow:CreateTexture(nil, "OVERLAY")
    glowTex:SetAllPoints()
    glowTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowTex:SetBlendMode("ADD")
    f.glowFrame = glow
    f.glowTex = glowTex

    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.3)
    pulse:SetToAlpha(0.9)
    pulse:SetDuration(0.8)
    pulse:SetSmoothing("IN_OUT")
    f.ag = ag

    local pos = db.pillarIconPosition
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end

    CreateUnlockOverlay(f, "Pillar of Frost")
    f:Hide()
    self.pillarIcon = f
    self:ApplyLock()
    return f
end

function Display:UpdatePillarIconAppearance()
    if not self.pillarIcon then return end
    local db = UnDeath.db.profile
    local size = db.pillarIconSize
    self.pillarIcon:SetSize(size, size)
    self.pillarIcon:SetAlpha(db.pillarIconAlpha)
    self:ApplyPillarGlow()
end

function Display:ApplyPillarGlow()
    if not self.pillarIcon then return end
    local f = self.pillarIcon
    local db = UnDeath.db.profile
    local style = db.pillarGlowStyle
    local r, g, b = UnDeath:GetGlowColor()
    local intensity = db.pillarGlowIntensity
    local size = db.pillarIconSize

    f:SetBackdropBorderColor(r, g, b, 0.9)
    self:StopPillarGlow()

    local visible = f:IsShown() and f:GetAlpha() > 0

    if style == "glow" then
        f.glowFrame:SetSize(size * 1.7, size * 1.7)
        f.glowTex:SetVertexColor(r, g, b)
        f.ag:GetAnimations():SetFromAlpha(intensity * 0.3)
        f.ag:GetAnimations():SetToAlpha(intensity)
        f.glowFrame:Show()
        if visible then f.ag:Play() end
    elseif FLIPBOOK_STYLES[style] then
        if visible then
            StartFlipBookGlow(f, size, FLIPBOOK_STYLES[style], r, g, b)
        end
    end
end

function Display:StopPillarGlow()
    if not self.pillarIcon then return end
    self.pillarIcon.ag:Stop()
    self.pillarIcon.glowFrame:Hide()
    StopFlipBookGlow(self.pillarIcon)
end

function Display:SetPillarIconAlpha(alpha)
    if not self.pillarIcon then return end
    self.pillarIcon:SetAlpha(alpha)
end

function Display:ShowPillarIcon(label)
    if not UnDeath.db.profile.pillarIconEnabled then return end

    local f = self:GetPillarIcon()
    local db = UnDeath.db.profile
    f:SetSize(db.pillarIconSize, db.pillarIconSize)
    if db.pillarCombatOnly and not UnitAffectingCombat("player") then
        f:SetAlpha(0)
    else
        f:SetAlpha(db.pillarIconAlpha)
    end
    local spellInfo = C_Spell.GetSpellInfo(UnDeath.PILLAR_ID)
    local texture = spellInfo and spellInfo.iconID
    f.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    f:Show()
    self:ApplyPillarGlow()
end

function Display:HidePillarIcon()
    if not self.pillarIcon then return end
    self:StopPillarGlow()
    self.pillarIcon:SetAlpha(0)
end
