# DataTycoon — v0.30 "One Plot, Infinite Upgrades" Design Doc

## Vision

Shift from "buy 8 plots" → "own ONE plot, upgrade it endlessly." Every player gets a single plot. Progression comes from upgrading that plot with buildings, decorations, and machines that increase their Data income. A central shop sells player-wide upgrades. The economy starts slow and snowballs hard.

## Core Loop

```
Collect Orbs → Earn Data → Upgrade Plot → Generate More Data → Upgrade Player → Repeat
```

## Plot System (v0.30)

### Single Plot Per Player
- Each player gets ONE plot assigned on first join
- Plot is pre-placed in a grid around the hub
- New plots are generated in expanding rings as players join
- Plot ownership is permanent (no selling, no buying more)

### Plot Tiers (Buildings)
Players walk onto upgrade buttons ON their plot to purchase upgrades:

| Tier | Building | Cost (Data) | DPS Bonus | Unlocks |
|------|----------|-------------|-----------|---------|
| 1 | Empty Plot | 0 | 0/s | Starting state |
| 2 | Data Outpost | 500 | +5/s | Basic building |
| 3 | Server Room | 2,000 | +15/s | +Decoration Slot 1 |
| 4 | Data Center | 8,000 | +50/s | +Decoration Slot 2 |
| 5 | Tech Campus | 25,000 | +150/s | +Decoration Slot 3 |
| 6 | Quantum Labs | 75,000 | +400/s | +Decoration Slot 4 |
| 7 | Neural Nexus | 200,000 | +1,000/s | +Decoration Slot 5 |
| 8 | Singularity Core | 500,000 | +3,000/s | Ultimate building |

### Plot Decorations (Cosmetic + Small Bonuses)
Each decoration slot can hold ONE decoration. Replacing removes the old one.

| Decoration | Cost (Data) | Bonus |
|------------|-------------|-------|
| Flower Garden | 200 | +1/s |
| Fountain | 800 | +3/s |
| Neon Sign | 1,500 | +5/s |
| Hologram Tree | 3,000 | +10/s |
| Dragon Statue | 8,000 | +25/s |
| Particle Fountain | 15,000 | +50/s |
| Mining Drones | 30,000 | +100/s |
| Satellite Dish | 50,000 | +200/s |

### How Plot Upgrades Work
1. Physical buttons (Parts) appear on the plot for each available upgrade
2. Button shows cost and what it does
3. Player walks onto button → checks funds → if affordable, applies upgrade
4. Old building is replaced with new one (Model swap)
5. DPS bonus is applied to the player's income

## Player Upgrade Shop (Central Hub)

Located at the center of the baseplate. Players walk up to a shop NPC or terminal.

### Data Rate Upgrades (Permanent)

| Upgrade | Base Cost | Max Level | Effect per Level | Cost Scaling |
|---------|-----------|-----------|------------------|--------------|
| Data Mining Speed | 500 | 20 | +2 Data/sec | ×1.5 per level |
| Orb Magnetism | 1,000 | 10 | +1 orb range (studs) | ×1.8 per level |
| Orb Value | 2,000 | 10 | +1 Data per orb | ×2.0 per level |
| Idle Mining | 5,000 | 5 | +50% offline income | ×2.5 per level |

### Player Speed Upgrades

| Upgrade | Base Cost | Max Level | Effect per Level | Cost Scaling |
|---------|-----------|-----------|------------------|--------------|
| Walk Speed | 300 | 10 | +2 speed | ×1.6 per level |
| Sprint Power | 2,000 | 5 | +10 sprint speed | ×2.0 per level |
| Jump Boost | 1,500 | 5 | +5 jump power | ×2.0 per level |

### Fun Upgrades

| Upgrade | Cost | Effect |
|---------|------|--------|
| Particle Trail | 5,000 | Colorful particle trail follows player |
| Music Pack | 3,000 | Play music while walking |
| Title: Data Miner | 10,000 | "Data Miner" title above head |
| Title: Data Baron | 50,000 | "Data Baron" title above head |
| Title: Data Tycoon | 200,000 | "Data Tycoon" title above head |
| Aura Effect | 25,000 | Glowing aura around player |
| Fire Trail | 100,000 | Fire particles trail behind player |
| Rainbow Mode | 500,000 | Everything goes rainbow |
| Pet: Data Orb | 75,000 | A small orb pet follows you |
| Pet: Robot Dog | 150,000 | Robot dog pet walks with you |

### Shop Mechanics
- Each upgrade tracks its own level per player
- Cost for next level = baseCost × costScaling^(currentLevel)
- Upgrades are purchased via a shop GUI (walk up to shop, press E)
- Purchases are instant and permanent

## Economy Balance

### Starting State (Intentionally Slow)
- Starting Data: 10
- Base DPS: 0.5 Data/sec (was 1)
- Orb Reward: 2 Data (was 5)
- Orb Count: ~30 (reduced from 48)

### Income Scaling
Early game (first 5 min): ~0.5-5 DPS → 500 Data feels meaningful
Mid game (15-30 min): 50-200 DPS → buildings pay for themselves in minutes
Late game (1+ hour): 1000+ DPS → massive plot upgrades feel epic

### Cost Reference Points
- First plot upgrade (Data Outpost): 500 Data → ~17 min at start, ~5 min with orbs
- Mid building (Data Center): 8,000 Data → reachable in ~30 min
- End building (Singularity Core): 500,000 Data → ~2-3 hours of play
- Fun upgrades scattered throughout for variety

## Bridges

Buildings already exist. Now:
- Each plot gets an automatic bridge on first join
- Bridge connects plot to the hub
- Bridge upgrades visually as plot tier increases (planks → metal → neon → hologram)

## Technical Changes

### Data Schema Addition
```lua
PlayerData.Plot = {
    tier = 1,          -- building tier 1-8
    decorations = {},  -- table of decoration names
    x = 0, z = 0,     -- grid position
}
PlayerData.Upgrades = {
    dataMiningSpeed = 0,
    orbMagnetism = 0,
    orbValue = 0,
    idleMining = 0,
    walkSpeed = 0,
    sprintPower = 0,
    jumpBoost = 0,
}
PlayerData.FunUpgrades = {
    particleTrail = 0,
    musicPack = 0,
    title = "",
    auraEffect = 0,
    -- etc
}
Pet = ""  -- pet type if any
```

### New Configuration Tables
```lua
CONFIG.PLOT_BUILDINGS = { ... }
CONFIG.PLOT_DECORATIONS = { ... }
CONFIG.PLAYER_UPGRADES = { ... }
CONFIG.FUN_UPGRADES = { ... }
```

### New RemoteEvents
- PurchasePlotBuilding (client→server, sends plotId)
- PurchaseDecoration (client→server, sends slotIndex, decorationName)
- PurchasePlayerUpgrade (client→server, sends upgradeName)
- PurchaseFunUpgrade (client→server, sends upgradeName)
- PlotUpgraded (server→client, tier, plotId)
- DecorationChanged (server→client, slot, decorationName, plotId)

## Implementation Plan

### Phase 1: Core Systems (Agents 1-3)
1. Server: Plot tier system, building upgrade logic
2. Server: Player upgrade shop backend (persistent upgrades)
3. Client: Shop GUI + Plot upgrade buttons

### Phase 2: Content (Agents 4-6)
4. Buildings: Create 8 building models (WorldBuilder or simple parts)
5. Decorations: Create decoration models
6. Central hub: Shop terminal/NPC placement

### Phase 3: Bridges + Polish (Agents 7-8)
7. Auto-bridge generation on player join
8. Economy tuning, orb rebalance, bug fixes

## Success Metrics
- Player can progress for 2+ hours without hitting a wall
- Each upgrade feels meaningful (visible income increase)
- Fun upgrades give players something to show off
- The game feels slow at first but snowballs excitingly
