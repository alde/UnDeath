local UnDeath = _G.UnDeath
local Config = UnDeath:NewModule("Config")
local LSM = LibStub("LibSharedMedia-3.0")

function UnDeath:GetDefaults()
    return {
        profile = {
            debug = false,
            locked = false,
            -- Ability Panel
            shown = true,
            panelCombatOnly = false,
            historyCount = 6,
            growDirection = "right",
            iconSize = 40,
            iconAlpha = 1.0,
            opacityStep = 0.12,
            minOpacity = 0.3,
            bgAlpha = 0.8,
            borderTexture = "Blizzard Tooltip",
            position = nil,
            -- Pillar of Frost
            pillarAlert = true,
            pillarSound = "talent_ready",
            pillarSoundCustomId = "",
            pillarDuration = 12,
            pillarIconEnabled = true,
            pillarCombatOnly = false,
            pillarIconSize = 48,
            pillarIconAlpha = 1.0,
            pillarGlowStyle = "glow",
            pillarGlowColor = nil,
            pillarGlowIntensity = 0.9,
            pillarIconPosition = nil,
            -- Next Spell
            assistedCombat = false,
            assistedPosition = nil,
            -- Alerts
            soundEnabled = true,
            wasteSound = "raid_warning",
            wasteSoundCustomId = "",
            rimeExpireAlert = true,
            rimeExpireSound = "alarm1",
            rimeExpireSoundCustomId = "",
            idleCooldownAlert = true,
            idleCooldownNag = true,
            idleCooldownThreshold = 5,
            idleCooldownSound = "alarm1",
            idleCooldownSoundCustomId = "",
            warningBgAlpha = 0.7,
            warningBorderAlpha = 0.6,
            warningPosition = nil,
            -- Behaviour
            combatReport = true,
            timelineAutoShow = false,
            clearOnCombatEnd = false,
            timelinePosition = nil,
            timelineWidth = nil,
        },
    }
end

local SOUND_LIST = {
    { key = "wood_break",     name = "Wood Break",      id = 173248 },
    { key = "talent_ready",   name = "Talent Ready",    id = 73280 },
    { key = "raid_warning",   name = "Raid Warning",    id = 8959 },
    { key = "ready_check",    name = "Ready Check",     id = 8960 },
    { key = "alarm1",         name = "Alarm Clock 1",   id = 12867 },
    { key = "alarm2",         name = "Alarm Clock 2",   id = 12889 },
    { key = "alarm3",         name = "Alarm Clock 3",   id = 12890 },
    { key = "pvp_flag",       name = "PvP Flag Taken",  id = 8174 },
    { key = "levelup",        name = "Level Up",        id = 888 },
    { key = "map_ping",       name = "Map Ping",        id = 3175 },
    { key = "loot_coin",      name = "Loot Coin",       id = 120 },
    { key = "quest_complete", name = "Quest Complete",   id = 878 },
    { key = "none",           name = "None",             id = nil },
    { key = "custom",         name = "Custom SoundKit ID", id = nil },
}

local SOUND_BY_KEY = {}
local SOUND_VALUES = {}
for _, entry in ipairs(SOUND_LIST) do
    SOUND_BY_KEY[entry.key] = entry
    SOUND_VALUES[entry.key] = entry.name
end

function UnDeath:PlayConfigSound(settingKey)
    local key = self.db.profile[settingKey]
    if key == "custom" then
        local id = tonumber(self.db.profile[settingKey .. "CustomId"])
        if id then PlaySound(id, "Master") end
        return
    end
    local entry = SOUND_BY_KEY[key]
    if entry and entry.id then
        PlaySound(entry.id, "Master")
    end
end

local function AddSoundPicker(args, prefix, settingKey, baseOrder)
    args[prefix .. "Sound"] = {
        type = "select",
        name = "Sound",
        order = baseOrder,
        values = SOUND_VALUES,
        get = function() return UnDeath.db.profile[settingKey] end,
        set = function(_, val) UnDeath.db.profile[settingKey] = val end,
    }
    args[prefix .. "SoundCustom"] = {
        type = "input",
        name = "SoundKit ID",
        desc = "Enter a WoW soundKitID number.",
        order = baseOrder + 1,
        hidden = function() return UnDeath.db.profile[settingKey] ~= "custom" end,
        get = function() return UnDeath.db.profile[settingKey .. "CustomId"] end,
        set = function(_, val) UnDeath.db.profile[settingKey .. "CustomId"] = val end,
    }
    args[prefix .. "SoundTest"] = {
        type = "execute",
        name = "Test",
        order = baseOrder + 2,
        func = function() UnDeath:PlayConfigSound(settingKey) end,
    }
end

function UnDeath:GetBorderTexture()
    local name = self.db.profile.borderTexture
    if name == "None" then return nil end
    return LSM:Fetch("border", name)
end

function UnDeath:ApplyAppearance()
    local borderPath = self:GetBorderTexture()
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }
    if borderPath then
        backdrop.edgeFile = borderPath
        backdrop.edgeSize = 12
    end

    local opacity = self.db.profile.bgAlpha

    local display = self:GetModule("Display", true)
    if display and display.frame then
        display.frame:SetBackdrop(backdrop)
        display.frame:SetBackdropColor(0.05, 0.05, 0.05, opacity)
        display.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end
end

local function GetOptions()
    local opts = {
        type = "group",
        name = "UnDeath",
        args = {
            abilityPanel = {
                type = "group",
                name = "Ability Panel",
                order = 1,
                inline = true,
                args = {
                    shown = {
                        type = "toggle",
                        name = "Show Panel",
                        desc = "Show the ability history strip.",
                        order = 1,
                        get = function() return UnDeath.db.profile.shown end,
                        set = function(_, val)
                            UnDeath.db.profile.shown = val
                            local display = UnDeath:GetModule("Display")
                            display:UpdatePanelVisibility()
                            if val then display:Refresh() end
                        end,
                    },
                    panelCombatOnly = {
                        type = "toggle",
                        name = "Only in Combat",
                        order = 2,
                        get = function() return UnDeath.db.profile.panelCombatOnly end,
                        set = function(_, val)
                            UnDeath.db.profile.panelCombatOnly = val
                            UnDeath:GetModule("Display"):UpdatePanelVisibility()
                        end,
                    },
                    iconsHeader = {
                        type = "header",
                        name = "Icons",
                        order = 10,
                    },
                    historyCount = {
                        type = "range",
                        name = "History Length",
                        order = 11,
                        min = 2, max = 12, step = 1,
                        get = function() return UnDeath.db.profile.historyCount end,
                        set = function(_, val)
                            UnDeath.db.profile.historyCount = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    growDirection = {
                        type = "select",
                        name = "Growth",
                        order = 12,
                        values = { right = "Right", left = "Left", up = "Up", down = "Down" },
                        get = function() return UnDeath.db.profile.growDirection end,
                        set = function(_, val)
                            UnDeath.db.profile.growDirection = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    iconSize = {
                        type = "range",
                        name = "Icon Size",
                        order = 13,
                        min = 20, max = 64, step = 2,
                        get = function() return UnDeath.db.profile.iconSize end,
                        set = function(_, val)
                            UnDeath.db.profile.iconSize = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    fadingHeader = {
                        type = "header",
                        name = "Icon Fading",
                        order = 20,
                    },
                    iconAlpha = {
                        type = "range",
                        name = "Base Opacity",
                        order = 21,
                        min = 0.2, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.iconAlpha end,
                        set = function(_, val)
                            UnDeath.db.profile.iconAlpha = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    opacityStep = {
                        type = "range",
                        name = "Fade Per Icon",
                        order = 22,
                        min = 0, max = 0.3, step = 0.02, isPercent = true,
                        get = function() return UnDeath.db.profile.opacityStep end,
                        set = function(_, val)
                            UnDeath.db.profile.opacityStep = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    minOpacity = {
                        type = "range",
                        name = "Fade Floor",
                        order = 23,
                        min = 0.1, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.minOpacity end,
                        set = function(_, val)
                            UnDeath.db.profile.minOpacity = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                    appearanceHeader = {
                        type = "header",
                        name = "Panel Appearance",
                        order = 30,
                    },
                    bgAlpha = {
                        type = "range",
                        name = "Background Opacity",
                        order = 31,
                        min = 0, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.bgAlpha end,
                        set = function(_, val)
                            UnDeath.db.profile.bgAlpha = val
                            UnDeath:ApplyAppearance()
                        end,
                    },
                    borderTexture = {
                        type = "select",
                        dialogControl = "LSM30_Border",
                        name = "Border",
                        order = 32,
                        values = LSM:HashTable("border"),
                        get = function() return UnDeath.db.profile.borderTexture end,
                        set = function(_, val)
                            UnDeath.db.profile.borderTexture = val
                            UnDeath:ApplyAppearance()
                        end,
                    },
                },
            },
            pillar = {
                type = "group",
                name = "Pillar of Frost",
                order = 2,
                inline = true,
                args = {
                    pillarAlert = {
                        type = "toggle",
                        name = "Ready Sound & Flash",
                        order = 1,
                        get = function() return UnDeath.db.profile.pillarAlert end,
                        set = function(_, val) UnDeath.db.profile.pillarAlert = val end,
                    },
                    pillarDuration = {
                        type = "range",
                        name = "Pillar Duration",
                        desc = "Adjust if modified by talents (e.g. The Long Winter).",
                        order = 5,
                        min = 5, max = 30, step = 1,
                        get = function() return UnDeath.db.profile.pillarDuration end,
                        set = function(_, val) UnDeath.db.profile.pillarDuration = val end,
                    },
                    iconHeader = {
                        type = "header",
                        name = "Ready Icon",
                        order = 20,
                    },
                    pillarIconEnabled = {
                        type = "toggle",
                        name = "Show Icon",
                        order = 21,
                        get = function() return UnDeath.db.profile.pillarIconEnabled end,
                        set = function(_, val) UnDeath.db.profile.pillarIconEnabled = val end,
                    },
                    pillarCombatOnly = {
                        type = "toggle",
                        name = "Only in Combat",
                        order = 22,
                        get = function() return UnDeath.db.profile.pillarCombatOnly end,
                        set = function(_, val)
                            UnDeath.db.profile.pillarCombatOnly = val
                            local display = UnDeath:GetModule("Display", true)
                            if not display then return end
                            if val and not UnitAffectingCombat("player") then
                                display:SetPillarIconAlpha(0)
                            elseif not val then
                                display:SetPillarIconAlpha(UnDeath.db.profile.pillarIconAlpha)
                            end
                        end,
                    },
                    pillarIconSize = {
                        type = "range",
                        name = "Icon Size",
                        order = 23,
                        min = 24, max = 80, step = 2,
                        get = function() return UnDeath.db.profile.pillarIconSize end,
                        set = function(_, val)
                            UnDeath.db.profile.pillarIconSize = val
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:UpdatePillarIconAppearance() end
                        end,
                    },
                    pillarIconAlpha = {
                        type = "range",
                        name = "Icon Opacity",
                        order = 24,
                        min = 0.2, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.pillarIconAlpha end,
                        set = function(_, val)
                            UnDeath.db.profile.pillarIconAlpha = val
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:UpdatePillarIconAppearance() end
                        end,
                    },
                    glowHeader = {
                        type = "header",
                        name = "Glow Effect",
                        order = 30,
                    },
                    pillarGlowStyle = {
                        type = "select",
                        name = "Style",
                        order = 31,
                        values = { glow = "Pulse", proc = "Proc", ants = "Ants (Classic)", none = "None" },
                        get = function() return UnDeath.db.profile.pillarGlowStyle end,
                        set = function(_, val)
                            UnDeath.db.profile.pillarGlowStyle = val
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:ApplyPillarGlow() end
                        end,
                    },
                    pillarGlowColor = {
                        type = "color",
                        name = "Color",
                        desc = "Defaults to class color.",
                        order = 32,
                        get = function() return UnDeath:GetGlowColor() end,
                        set = function(_, r, g, b)
                            UnDeath.db.profile.pillarGlowColor = { r = r, g = g, b = b }
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:ApplyPillarGlow() end
                        end,
                    },
                    pillarGlowClassColor = {
                        type = "execute",
                        name = "Class Color",
                        order = 33,
                        func = function()
                            UnDeath.db.profile.pillarGlowColor = nil
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:ApplyPillarGlow() end
                        end,
                    },
                    pillarGlowIntensity = {
                        type = "range",
                        name = "Intensity",
                        order = 34,
                        min = 0.2, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.pillarGlowIntensity end,
                        set = function(_, val)
                            UnDeath.db.profile.pillarGlowIntensity = val
                            local display = UnDeath:GetModule("Display", true)
                            if display then display:ApplyPillarGlow() end
                        end,
                    },
                },
            },
            nextSpell = {
                type = "group",
                name = "Next Spell",
                order = 3,
                inline = true,
                hidden = function() return C_AssistedCombat == nil end,
                args = {
                    assistedCombat = {
                        type = "toggle",
                        name = "Show Next Spell",
                        desc = "Show Blizzard's recommended next ability with keybinding.",
                        order = 1,
                        get = function() return UnDeath.db.profile.assistedCombat end,
                        set = function(_, val)
                            UnDeath.db.profile.assistedCombat = val
                            UnDeath:SendMessage("UNDEATH_HISTORY_UPDATED")
                        end,
                    },
                },
            },
            alerts = {
                type = "group",
                name = "Alerts",
                order = 4,
                inline = true,
                args = {
                    soundEnabled = {
                        type = "toggle",
                        name = "KM Waste Sound",
                        desc = "Play a sound when Killing Machine is wasted.",
                        order = 1,
                        get = function() return UnDeath.db.profile.soundEnabled end,
                        set = function(_, val) UnDeath.db.profile.soundEnabled = val end,
                    },
                    rimeHeader = {
                        type = "header",
                        name = "Rime",
                        order = 5,
                    },
                    rimeExpireAlert = {
                        type = "toggle",
                        name = "Rime Expire Warning",
                        desc = "Warn when a Rime proc expires without being used.",
                        order = 6,
                        get = function() return UnDeath.db.profile.rimeExpireAlert end,
                        set = function(_, val) UnDeath.db.profile.rimeExpireAlert = val end,
                    },
                    cdHeader = {
                        type = "header",
                        name = "Cooldown Idle",
                        order = 10,
                    },
                    idleCooldownAlert = {
                        type = "toggle",
                        name = "Idle Warning",
                        desc = "Warn when major cooldowns sit available too long during combat.",
                        order = 11,
                        get = function() return UnDeath.db.profile.idleCooldownAlert end,
                        set = function(_, val) UnDeath.db.profile.idleCooldownAlert = val end,
                    },
                    idleCooldownNag = {
                        type = "toggle",
                        name = "Visual Nag",
                        desc = "Show a pulsing text reminder while a cooldown sits unused.",
                        order = 12,
                        get = function() return UnDeath.db.profile.idleCooldownNag end,
                        set = function(_, val) UnDeath.db.profile.idleCooldownNag = val end,
                    },
                    idleCooldownThreshold = {
                        type = "range",
                        name = "Delay (seconds)",
                        order = 13,
                        min = 2, max = 15, step = 1,
                        get = function() return UnDeath.db.profile.idleCooldownThreshold end,
                        set = function(_, val) UnDeath.db.profile.idleCooldownThreshold = val end,
                    },
                    warningHeader = {
                        type = "header",
                        name = "Text Warning Frame",
                        order = 20,
                    },
                    warningBgAlpha = {
                        type = "range",
                        name = "Background Opacity",
                        order = 21,
                        min = 0, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.warningBgAlpha end,
                        set = function(_, val)
                            UnDeath.db.profile.warningBgAlpha = val
                            local display = UnDeath:GetModule("Display", true)
                            if display and display.warningFrame then
                                display.warningFrame:SetBackdropColor(0.05, 0.05, 0.05, val)
                            end
                        end,
                    },
                    warningBorderAlpha = {
                        type = "range",
                        name = "Border Opacity",
                        order = 22,
                        min = 0, max = 1.0, step = 0.05, isPercent = true,
                        get = function() return UnDeath.db.profile.warningBorderAlpha end,
                        set = function(_, val) UnDeath.db.profile.warningBorderAlpha = val end,
                    },
                },
            },
            general = {
                type = "group",
                name = "General",
                order = 5,
                inline = true,
                args = {
                    locked = {
                        type = "toggle",
                        name = "Lock Frames",
                        order = 1,
                        get = function() return UnDeath.db.profile.locked end,
                        set = function(_, val) UnDeath:SetLocked(val) end,
                    },
                    behaviourHeader = {
                        type = "header",
                        name = "Behaviour",
                        order = 10,
                    },
                    combatReport = {
                        type = "toggle",
                        name = "Combat Report",
                        order = 11,
                        get = function() return UnDeath.db.profile.combatReport end,
                        set = function(_, val) UnDeath.db.profile.combatReport = val end,
                    },
                    timelineAutoShow = {
                        type = "toggle",
                        name = "Auto-show Timeline",
                        order = 12,
                        get = function() return UnDeath.db.profile.timelineAutoShow end,
                        set = function(_, val) UnDeath.db.profile.timelineAutoShow = val end,
                    },
                    clearOnCombatEnd = {
                        type = "toggle",
                        name = "Clear on Combat End",
                        order = 13,
                        get = function() return UnDeath.db.profile.clearOnCombatEnd end,
                        set = function(_, val) UnDeath.db.profile.clearOnCombatEnd = val end,
                    },
                    debugHeader = {
                        type = "header",
                        name = "",
                        order = 20,
                    },
                    debug = {
                        type = "toggle",
                        name = "Debug Logging",
                        desc = "Also toggleable via /ud debug.",
                        order = 21,
                        get = function() return UnDeath.db.profile.debug end,
                        set = function(_, val) UnDeath.db.profile.debug = val end,
                    },
                },
            },
        },
    }

    AddSoundPicker(opts.args.pillar.args, "pillar", "pillarSound", 2)
    AddSoundPicker(opts.args.alerts.args, "waste", "wasteSound", 2)
    AddSoundPicker(opts.args.alerts.args, "rimeExpire", "rimeExpireSound", 7)
    AddSoundPicker(opts.args.alerts.args, "idle", "idleCooldownSound", 14)

    return opts
end

function Config:OnEnable()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("UnDeath", GetOptions)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("UnDeath", "UnDeath")
end
