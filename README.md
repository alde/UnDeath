# UnDeath

Frost Death Knight rotation tracker for retail WoW (12.0+). Monitors Killing Machine proc usage, Rime efficiency, Pillar of Frost cooldown, and more — helping you identify and fix rotation mistakes in real time.

Inspired by [ReWind](https://github.com/alde/ReWind) (Windwalker Monk tracker) and adapted for Frost DK best practices from community guides.

## Features

- **Ability History Strip** — movable panel showing recent rotational casts with shrink+fade for older icons
- **Killing Machine Waste Detection** — highlights when you cast Frost Strike or Glacial Advance while Killing Machine is active (should use Obliterate/Frostscythe instead)
- **Rime Tracking** — monitors Rime proc gains and warns when procs expire unused
- **Pillar of Frost Ready Icon** — standalone movable icon with configurable glow (pulse, proc flipbook, classic ants) when Pillar is off cooldown
- **Idle Cooldown Warnings** — alerts when Pillar of Frost, Empower Rune Weapon, or Frostwyrm's Fury sit available too long during combat
- **Combat Reports** — end-of-combat summary showing KM waste count and Rime efficiency percentage
- **Encounter Timeline** — scrollable post-encounter cast log with KM wastes highlighted, exportable as CSV
- **Assisted Combat** — optional next-spell display using Blizzard's `C_AssistedCombat` API (when available)
- **M+ Keystone Tracking** — aggregated stats across an entire keystone run
- **Masque Support** — three skinning groups (Ability History, Pillar of Frost, Next Spell)

## Tracked Abilities

| Spell | ID |
|---|---|
| Obliterate | 49020 |
| Frost Strike | 49143 |
| Howling Blast | 49184 |
| Frostscythe | 207230 |
| Glacial Advance | 194913 |
| Remorseless Winter | 196770 |
| Frostwyrm's Fury | 279302 |
| Empower Rune Weapon | 47568 |
| Breath of Sindragosa | 152279 |
| Reaper's Mark | 439843 |
| Soul Reaper | 343294 |
| Raise Dead | 46585 |
| Death Strike | 49998 |

## Tracked Auras

| Buff/Proc | ID |
|---|---|
| Killing Machine | 51124 |
| Rime | 59052 |
| Pillar of Frost | 51271 |
| Breath of Sindragosa | 152279 |
| Icy Talons | 194879 |

## Slash Commands

| Command | Action |
|---|---|
| `/ud` | Toggle display |
| `/ud config` | Open options |
| `/ud timeline` | Show last encounter timeline |
| `/ud lock` | Lock/unlock frames |
| `/ud reset` | Clear history |
| `/ud debug` | Toggle debug logging |
| `/ud test` | Inject test data |

## Installation

1. Clone or download into your `Interface/AddOns/UnDeath` folder
2. Run `./download_deps.sh` (or `download_deps.ps1` on Windows) to fetch libraries
3. Reload WoW UI

### Dependencies (bundled via download script)

- LibStub, CallbackHandler-1.0
- Ace3 (AceAddon, AceDB, AceEvent, AceGUI, AceConfig, AceConsole)
- LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets

### Optional

- [Masque](https://www.curseforge.com/wow/addons/masque) — icon skinning
