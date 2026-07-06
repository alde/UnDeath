local UnDeath = _G.UnDeath
local Auras = UnDeath:NewModule("Auras", "AceEvent-3.0")

local TRACKED_AURAS = {
    [UnDeath.KM_ID] = {
        name = "Killing Machine",
        baseDuration = 10,
        stacks = true,
    },
    [UnDeath.RIME_ID] = {
        name = "Rime",
        baseDuration = 15,
        stacks = false,
    },
    [UnDeath.PILLAR_ID] = {
        name = "Pillar of Frost",
        baseDuration = 12,
        stacks = false,
    },
    [152279] = {
        name = "Breath of Sindragosa",
        baseDuration = 0,
        stacks = false,
    },
    [194879] = {
        name = "Icy Talons",
        baseDuration = 6,
        stacks = true,
    },
}

UnDeath.TRACKED_AURAS = TRACKED_AURAS

local nameToId = {}
for id, info in pairs(TRACKED_AURAS) do
    nameToId[info.name] = id
end

local auraIdCache = {}

local function ResolveSpellId(auraSpellId)
    if auraIdCache[auraSpellId] ~= nil then
        return auraIdCache[auraSpellId]
    end

    if TRACKED_AURAS[auraSpellId] then
        auraIdCache[auraSpellId] = auraSpellId
        return auraSpellId
    end

    local name = C_Spell.GetSpellName(auraSpellId)
    if name and nameToId[name] then
        auraIdCache[auraSpellId] = nameToId[name]
        return nameToId[name]
    end

    auraIdCache[auraSpellId] = false
    return false
end

local scanErrorLogged = false

function Auras:ScanPlayer()
    local found = {}

    local ids = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL")
    if not ids then return found end

    for _, instanceId in ipairs(ids) do
        local ok, err = pcall(function()
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceId)
            if not aura then return end

            local trackedId
            local spellIdOk, sid = pcall(function() return aura.spellId end)
            if spellIdOk and sid and not issecretvalue(sid) then
                trackedId = ResolveSpellId(sid)
            end

            if not trackedId then
                local nameOk, auraName = pcall(function() return aura.name end)
                if nameOk and auraName and not issecretvalue(auraName) and nameToId[auraName] then
                    trackedId = nameToId[auraName]
                end
            end

            if not trackedId then return end

            local info = TRACKED_AURAS[trackedId]

            local duration, expirationTime, stacks
            local durOk, d, e = pcall(function()
                return tonumber(aura.duration) or 0, tonumber(aura.expirationTime) or 0
            end)
            if durOk and d and d > 0 then
                duration = d
                expirationTime = e
            else
                duration = info.baseDuration
                expirationTime = duration > 0 and (GetTime() + duration) or 0
            end

            local stackOk, s = pcall(function()
                return aura.applications or 0
            end)
            stacks = stackOk and s or 0

            found[trackedId] = {
                name = info.name,
                duration = duration,
                expirationTime = expirationTime,
                stacks = stacks,
            }
        end)

        if not ok and not scanErrorLogged then
            UnDeath:Print("Aura scan error (subsequent errors suppressed): " .. tostring(err))
            scanErrorLogged = true
        end
    end

    return found
end

function Auras:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    UnDeath.state.auras = self:ScanPlayer()
end

function Auras:OnDisable()
    self:UnregisterEvent("UNIT_AURA")
    wipe(UnDeath.state.auras)
end

function Auras:UNIT_AURA(_, unit)
    if unit ~= "player" then return end

    local previous = UnDeath.state.auras or {}
    local current = self:ScanPlayer()

    for spellId, aura in pairs(current) do
        if not previous[spellId] then
            UnDeath:Debug("Aura gained:", aura.name, "stacks:", aura.stacks)
            UnDeath:SendMessage("UNDEATH_AURA_GAINED", spellId, aura)
        elseif aura.stacks ~= previous[spellId].stacks then
            UnDeath:Debug("Aura stacks:", aura.name, previous[spellId].stacks, "->", aura.stacks)
            UnDeath:SendMessage("UNDEATH_AURA_STACKS", spellId, aura)
        end
    end

    for spellId in pairs(previous) do
        if not current[spellId] then
            UnDeath:Debug("Aura lost:", TRACKED_AURAS[spellId] and TRACKED_AURAS[spellId].name or spellId)
            UnDeath:SendMessage("UNDEATH_AURA_LOST", spellId)
        end
    end

    UnDeath.state.auras = current
    UnDeath:SendMessage("UNDEATH_AURAS_UPDATED")
end

function Auras:GetAura(spellId)
    local auras = UnDeath.state.auras
    return auras and auras[spellId]
end

function Auras:IsActive(spellId)
    return self:GetAura(spellId) ~= nil
end
