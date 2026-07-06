local UnDeath = _G.UnDeath
local Core = UnDeath:NewModule("Core", "AceEvent-3.0")

local HOWLING_BLAST_ID = 49184

local ROTATION_SPELLS = {
    [49020]  = true, -- Obliterate
    [49143]  = true, -- Frost Strike
    [49184]  = true, -- Howling Blast
    [207230] = true, -- Frostscythe
    [194913] = true, -- Glacial Advance
    [196770] = true, -- Remorseless Winter
    [279302] = true, -- Frostwyrm's Fury
    [47568]  = true, -- Empower Rune Weapon
    [152279] = true, -- Breath of Sindragosa
    [439843] = true, -- Reaper's Mark
    [343294] = true, -- Soul Reaper
    [46585]  = true, -- Raise Dead
    [49998]  = true, -- Death Strike
}

local KM_WASTERS = {
    [49143]  = true, -- Frost Strike
    [194913] = true, -- Glacial Advance
}

local IDLE_COOLDOWNS = {
    [51271]  = { name = "Pillar of Frost" },
    [47568]  = { name = "Empower Rune Weapon" },
    [279302] = { name = "Frostwyrm's Fury" },
}

local function NewCombatStats()
    return {
        totalCasts = 0,
        kmWastes = 0,
        rimeGained = 0,
        rimeExpired = 0,
        wasteLog = {},
        casts = {},
        startTime = GetTime(),
    }
end

local function RecordToStats(stats, spellId, now, kmWaste)
    stats.totalCasts = stats.totalCasts + 1
    table.insert(stats.casts, { spellId = spellId, time = now, kmWaste = kmWaste })
    if kmWaste then
        stats.kmWastes = stats.kmWastes + 1
        table.insert(stats.wasteLog, { spellId = spellId, time = now })
    end
end

function Core:OnEnable()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("CHALLENGE_MODE_RESET")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterMessage("UNDEATH_AURA_GAINED", "OnAuraGained")
    self:RegisterMessage("UNDEATH_AURA_LOST", "OnAuraLost")
end

function Core:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.pillarReady = nil
    self.pillarActiveUntil = nil
    self.idleState = nil
    self.lastHBTime = nil
end

-- Rotation tracking

function Core:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellId)
    if unit ~= "player" then return end
    if not ROTATION_SPELLS[spellId] then return end
    self:RecordAbility(spellId)
end

function Core:RecordAbility(spellId)
    local state = UnDeath.state
    local maxHistory = UnDeath.db.profile.historyCount

    local auras = UnDeath:GetModule("Auras", true)
    local kmActive = auras and auras:IsActive(UnDeath.KM_ID)
    local kmWaste = kmActive and KM_WASTERS[spellId] or false
    state.kmWasted = kmWaste

    if kmWaste and UnDeath.db.profile.soundEnabled then
        UnDeath:PlayConfigSound("wasteSound")
        UnDeath:SendMessage("UNDEATH_KM_WASTE", spellId)
    end

    if spellId == HOWLING_BLAST_ID then
        self.lastHBTime = GetTime()
    end

    state.lastSpellId = spellId

    table.insert(state.history, 1, {
        spellId = spellId,
        kmWaste = kmWaste,
        time = GetTime(),
    })

    while #state.history > maxHistory do
        table.remove(state.history)
    end

    local now = GetTime()
    if state.combat then RecordToStats(state.combat, spellId, now, kmWaste) end
    if state.keystone then RecordToStats(state.keystone, spellId, now, kmWaste) end

    UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
end

-- Rime tracking via aura events

function Core:OnAuraGained(_, spellId)
    if spellId == UnDeath.RIME_ID then
        local combat = UnDeath.state.combat
        if combat then combat.rimeGained = combat.rimeGained + 1 end
        local ks = UnDeath.state.keystone
        if ks then ks.rimeGained = ks.rimeGained + 1 end
        UnDeath:Debug("Rime proc gained")
    end
end

function Core:OnAuraLost(_, spellId)
    if spellId == UnDeath.RIME_ID then
        local now = GetTime()
        local consumed = self.lastHBTime and (now - self.lastHBTime) < 0.5
        if not consumed then
            local combat = UnDeath.state.combat
            if combat then combat.rimeExpired = combat.rimeExpired + 1 end
            local ks = UnDeath.state.keystone
            if ks then ks.rimeExpired = ks.rimeExpired + 1 end

            if UnDeath.db.profile.rimeExpireAlert and UnitAffectingCombat("player") then
                UnDeath:PlayConfigSound("rimeExpireSound")
                UnDeath:SendMessage("UNDEATH_RIME_EXPIRED")
            end
            UnDeath:Debug("Rime expired (wasted)")
        else
            UnDeath:Debug("Rime consumed by Howling Blast")
        end
    end
end

-- Pillar of Frost cooldown tracking

function Core:SPELL_UPDATE_COOLDOWN()
    self:CheckPillarReady()
    if UnDeath.db.profile.idleCooldownAlert and UnitAffectingCombat("player") then
        self:CheckIdleCooldowns()
    end
end

function Core:CheckPillarReady()
    if not IsPlayerSpell(UnDeath.PILLAR_ID) then return end

    local info = C_Spell.GetSpellCooldown(UnDeath.PILLAR_ID)
    if not info then return end

    local ready = not info.isActive

    if ready and not self.pillarReady then
        self.pillarReady = true
        if UnDeath.db.profile.pillarAlert and UnitAffectingCombat("player") then
            UnDeath:PlayConfigSound("pillarSound")
        end
        UnDeath:SendMessage("UNDEATH_PILLAR_READY", "Pillar of Frost")
    elseif not ready and self.pillarReady then
        self.pillarReady = false
        local dur = UnDeath.db.profile.pillarDuration
        self.pillarActiveUntil = GetTime() + dur
        UnDeath:Debug("Pillar pressed, window for", dur .. "s")
        UnDeath:SendMessage("UNDEATH_PILLAR_COOLDOWN", "Pillar of Frost")
    elseif not ready then
        self.pillarReady = false
    end
end

function Core:CheckIdleCooldowns()
    local now = GetTime()
    local threshold = UnDeath.db.profile.idleCooldownThreshold

    if not self.idleState then self.idleState = {} end

    for spellId, info in pairs(IDLE_COOLDOWNS) do
        if IsPlayerSpell(spellId) then
            local cdInfo = C_Spell.GetSpellCooldown(spellId)
            local usable = C_Spell.IsSpellUsable(spellId)
            local ready = cdInfo and not cdInfo.isActive and usable

            if ready then
                local state = self.idleState[spellId]
                if not state then
                    self.idleState[spellId] = { readySince = now, warned = false }
                elseif not state.warned and (now - state.readySince) >= threshold then
                    state.warned = true
                    UnDeath:Debug("Idle cooldown:", info.name, string.format("%.0fs", now - state.readySince))
                    UnDeath:PlayConfigSound("idleCooldownSound")
                    UnDeath:SendMessage("UNDEATH_COOLDOWN_IDLE", spellId, info.name)
                end
            else
                self.idleState[spellId] = nil
            end
        end
    end
end

-- Combat tracking

function Core:PLAYER_REGEN_DISABLED()
    UnDeath.state.combat = NewCombatStats()
    self.idleState = nil
end

function Core:PLAYER_REGEN_ENABLED()
    self.idleState = nil

    local combat = UnDeath.state.combat
    if combat and combat.totalCasts > 0 then
        combat.endTime = GetTime()
        self:PrintCombatReport(combat, "Combat")
        UnDeath.state.lastEncounter = combat
        UnDeath:SendMessage("UNDEATH_ENCOUNTER_END", combat)
    end
    UnDeath.state.combat = nil

    if UnDeath.db.profile.clearOnCombatEnd then
        wipe(UnDeath.state.history)
        UnDeath.state.lastSpellId = nil
        UnDeath.state.kmWasted = false
        UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
    end
end

-- M+ keystone tracking

function Core:CHALLENGE_MODE_START()
    UnDeath.state.keystone = NewCombatStats()
    UnDeath:Print("Keystone started — tracking rotation.")
end

function Core:CHALLENGE_MODE_COMPLETED()
    self:EndKeystone()
end

function Core:CHALLENGE_MODE_RESET()
    self:EndKeystone()
end

function Core:PLAYER_ENTERING_WORLD()
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
        and not UnDeath.state.keystone then
        UnDeath.state.keystone = NewCombatStats()
    end
end

function Core:EndKeystone()
    local ks = UnDeath.state.keystone
    if ks and ks.totalCasts > 0 then
        ks.endTime = GetTime()
        self:PrintCombatReport(ks, "Keystone")
        UnDeath.state.lastEncounter = ks
        UnDeath:SendMessage("UNDEATH_ENCOUNTER_END", ks)
    end
    UnDeath.state.keystone = nil
end

-- Reporting

function Core:PrintCombatReport(stats, label)
    if not UnDeath.db.profile.combatReport then return end

    local kmColor = stats.kmWastes == 0 and "|cff00ff00"
        or (stats.kmWastes <= 2 and "|cffffff00" or "|cffff4444")

    local rimePct = stats.rimeGained > 0
        and (1 - stats.rimeExpired / stats.rimeGained) * 100 or 100
    local rimeColor = rimePct == 100 and "|cff00ff00"
        or (rimePct >= 90 and "|cffffff00" or "|cffff4444")

    if stats.rimeGained > 0 then
        UnDeath:Print(string.format(
            "%s end — %s%d KM waste%s|r, %s%.0f%% Rime|r (%d/%d procs)",
            label, kmColor, stats.kmWastes, stats.kmWastes == 1 and "" or "s",
            rimeColor, rimePct,
            stats.rimeGained - stats.rimeExpired, stats.rimeGained
        ))
    else
        UnDeath:Print(string.format(
            "%s end — %s%d KM waste%s|r",
            label, kmColor, stats.kmWastes, stats.kmWastes == 1 and "" or "s"
        ))
    end

    if #stats.wasteLog > 0 then
        local counts = {}
        for _, entry in ipairs(stats.wasteLog) do
            local info = C_Spell.GetSpellInfo(entry.spellId)
            local name = info and info.name or tostring(entry.spellId)
            counts[name] = (counts[name] or 0) + 1
        end

        local parts = {}
        for name, count in pairs(counts) do
            parts[#parts + 1] = string.format("%s x%d", name, count)
        end
        table.sort(parts)
        UnDeath:Print("  KM wastes: " .. table.concat(parts, ", "))
    end

    if stats.rimeExpired > 0 then
        UnDeath:Print(string.format("  Rime expired: %d proc%s",
            stats.rimeExpired, stats.rimeExpired == 1 and "" or "s"))
    end
end

function Core:InjectTestData()
    local testSpells = {
        49020,  -- Obliterate
        49143,  -- Frost Strike
        49184,  -- Howling Blast
        49020,  -- Obliterate
        194913, -- Glacial Advance
        207230, -- Frostscythe
        49143,  -- Frost Strike (potential KM waste if KM active)
    }
    wipe(UnDeath.state.history)
    UnDeath.state.lastSpellId = nil
    UnDeath.state.kmWasted = false

    UnDeath.state.combat = NewCombatStats()
    for _, id in ipairs(testSpells) do
        self:RecordAbility(id)
    end

    -- Simulate a KM waste for the last Frost Strike
    local history = UnDeath.state.history
    if history[1] then
        history[1].kmWaste = true
    end
    local combat = UnDeath.state.combat
    combat.kmWastes = 1
    combat.wasteLog = { { spellId = 49143, time = GetTime() } }
    combat.rimeGained = 3
    combat.rimeExpired = 1

    combat.endTime = GetTime()
    self:PrintCombatReport(combat, "Test")
    UnDeath.state.lastEncounter = combat
    UnDeath.state.combat = nil

    local timeline = UnDeath:GetModule("Timeline", true)
    if timeline then timeline:Show(combat) end

    UnDeath:Print("Injected test data (last Frost Strike is a KM waste, 1 Rime expired).")
end
