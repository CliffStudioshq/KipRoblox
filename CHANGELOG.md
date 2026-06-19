# DataTycoon — Changelog

This changelog documents notable changes for **DataTycoon** from **v0.1** through **v0.22**.

Conventions:
- **Added**: new features
- **Changed**: behavior changes / refactors
- **Fixed**: bug fixes
- **Tuned**: balance/pacing changes

> Note: Versions prior to v0.21 are reconstructed from repository state and feature intent. If you have release notes/commits, we can replace placeholders with exact details.

---

## v0.22 — 2026-06 (Current)

### What’s new

#### Server reliability & replication safety
- **Added** an **early invisible baseplate** (`EarlyBase`) plus a **SpawnLocation** before any yielding work, preventing players from falling into the void during initial load.
- **Changed** RemoteEvents replication to be **atomic**:
  - Builds the `ReplicatedStorage/Events` folder and all children first.
  - Parents the folder last so clients don’t see partial/half-created events.
- **Changed** leaderstats replication to be **atomic**:
  - Creates all `leaderstats` children first, then parents folder to the player.
- **Fixed** DataStore initialization so failures won’t prevent Events creation:
  - DataStore creation wrapped in `pcall` with clear warnings about enabling API Services.

#### Orb collection feedback (client/server)
- **Added** `OrbCollected` RemoteEvent (server → client) so the client can animate the specific orb that was collected.
- **Changed** orb collection flow:
  - Client sends `ring.Position` to `CollectOrb`.
  - Server rewards and then fires `OrbCollected` back to the collector with orb position and respawn timer.
- **Added** client-side orb visuals:
  - Parts within ~12 studs of the collected orb fade out and disable collisions.
  - Restores transparency/collision after `ORB_RESPAWN` (default **30s**).

#### Client startup & UI improvements
- **Fixed** “connection failed / ERR / missing WaitForChild target” class of issues by requiring `game.Loaded:Wait()` **before any** `WaitForChild`.
- **Added** compact number formatting (`1234 → 1.2K`, `1,000,000 → 1.0M`, etc.).
- **Added** a structured HUD:
  - Top bar showing **Data**, **House**, and **DPS**.
  - Sidebar buttons for **Daily Reward**, **Shop**, **Buy Plot [E]**, **Stats**.
- **Added** a proper **Shop panel**:
  - Tiered computer purchases.
  - House upgrade buttons.
- **Added** **Stats panel** that pulls authoritative server data via `GetPlayerData` RemoteFunction.
- **Changed** DPS display to update periodically while Stats panel is open (refresh every 5s).

### Balance / configuration notes
- `STARTING_DATA`: **50**
- `ORB_REWARD`: **5**
- `PASSIVE_INCOME`: **1 Data/sec** base
- `ORB_RESPAWN`: **30s** (visual respawn on client)
- House tiers (max computers / max plots):
  - Shack: **1 / 2**
  - Small House: **2 / 4**
  - Modern House: **4 / 8**
  - Tech Villa: **8 / 8**
  - Mega Compound: **16 / 8**

---

## v0.21 — 2026-06

### Added
- **WorldBuilder** pass for a more “premium tycoon” feel:
  - Grass terrain floor (FillBlock) and perimeter rolling hills.
  - Mountain ring / landscape shaping.
  - Decorative nature pass (trees, bushes, rocks, flowers).
  - Hub buildout (platform, tower, fountain, server racks, arches, lamps).
  - Walkways to plot areas with lamps, benches, kiosks, flowers.
  - Plot markers/signage with price display.
  - “Data Orbs” arranged in rings around the hub.
- **Golden hour lighting** preset:
  - `ShadowMap` lighting technology.
  - ClockTime ~17.5, warm atmosphere, tuned bloom, subtle sun rays.
  - Dynamic clouds parented to Terrain.

### Changed
- Terrain decoration disabled (`terrain.Decoration = false`) to avoid oversized grass blades.

---

## v0.20 — (Reconstructed)

### Added
- First complete playable loop draft:
  - Data currency, plots, computers, house tiers.
  - Passive income concept.
  - Orb/collectible concept (early form).

### Fixed
- Basic client/server wiring issues found during initial end-to-end playtesting.

---

## v0.19 — (Reconstructed)

### Added
- Early progression scaffolding:
  - Starting resources and early upgrade costs.
  - First draft of daily reward concept.

---

## v0.18 — (Reconstructed)

### Added
- Data persistence experiment:
  - DataStore keys by user id.
  - Default data schema (Data, Plots, Computers, HouseTier, etc.).

---

## v0.17 — (Reconstructed)

### Added
- Plot ownership skeleton:
  - Plot identifiers and coordinate-based layout.
  - Purchase/sell placeholders.

---

## v0.16 — (Reconstructed)

### Added
- House upgrade tiering concept (Shack → larger homes).

---

## v0.15 — (Reconstructed)

### Added
- Computer tiering concept (Budget → Gaming → Rack → Supercomputer) and DPS-style income.

---

## v0.14 — (Reconstructed)

### Added
- Notifications UX concept (server-driven toast messages).

---

## v0.13 — (Reconstructed)

### Added
- Leaderstats display (“Data” as primary visible stat).

---

## v0.12 — (Reconstructed)

### Added
- First client HUD experiments.

---

## v0.11 — (Reconstructed)

### Added
- Event-driven architecture direction:
  - Central `Events` folder in ReplicatedStorage.
  - RemoteEvents for gameplay actions.

---

## v0.10 — (Reconstructed)

### Added
- Initial economy loop:
  - Earn currency, spend on upgrades.

---

## v0.9 — (Reconstructed)

### Added
- First collectible prototype (orbs/blocks) to support active play.

---

## v0.8 — (Reconstructed)

### Added
- Baseline “tycoon” structure:
  - Central hub concept.
  - Multiple plot locations around a shared center.

---

## v0.7 — (Reconstructed)

### Added
- Simple autosave concept.

---

## v0.6 — (Reconstructed)

### Added
- Passive income tick loop prototype.

---

## v0.5 — (Reconstructed)

### Added
- First shop/upgrade triggers.

---

## v0.4 — (Reconstructed)

### Added
- Server/client split (ServerScriptService + StarterPlayerScripts).

---

## v0.3 — (Reconstructed)

### Added
- Project setup and first gameplay scripts.

---

## v0.2 — (Reconstructed)

### Added
- Basic movement/test map and initial code organization.

---

## v0.1 — (Reconstructed)

### Added
- Initial concept prototype (“DataTycoon”): tech-themed currency and progression direction.

---

## Known issues (as of v0.22)

### Data & persistence
- If **API Services** are disabled or DataStore is unavailable, progression will **not save** (server logs warnings and continues).
- DataStore writes use `UpdateAsync` returning the whole table; schema changes should be done carefully to avoid clobbering/overwriting fields.

### Orb system
- Orb “respawn” is currently **visual client-side only** (parts fade back in after timer). There is no server-side per-orb state; multiple players may see/collect the same orb concurrently.
- Client finds affected orb parts by searching within radius of the position sent back; if two orbs are close, fade sets may overlap.

### Client input & plot purchasing
- “Buy Plot [E]” cycles a hard-coded plot order rather than selecting the plot the player is standing on.

### UI polish
- Some UI text includes emoji; ensure font/platform support (especially on low-end devices) or provide fallback.

---

## Next steps / roadmap

### Short term (v0.23–v0.24)
- **Server-authoritative orb state**:
  - Track orb cooldown per-orb (not just per-player), prevent multi-collect races.
  - Replicate orb availability via attributes or a dedicated state event.
- **Plot interaction improvements**:
  - Buy the plot the player is looking at/nearest to.
  - Add clear ownership visuals (coloring, signage updates).
- **Better onboarding**:
  - First-time tutorial prompt with “collect your first orb” guidance.
  - Highlight next recommended purchase.

### Mid term
- **Retention features** from DESIGN_RESEARCH.md:
  - Improve daily rewards with catch-up mechanics.
  - Expand offline income messaging and summaries.
- **Social & competitive**:
  - Leaderboards (richest, highest DPS, most orbs collected).
  - Base visiting / teleport to owned plots.

### Long term
- **PvP / Raiding** (core differentiator per design research):
  - Defenses, raid timers, protection windows.
  - Reward loops that don’t hard-punish casual players.
- **Monetization** aligned with best practices:
  - 2x income pass, extra plots, cosmetics/quality-of-life.
- **Content depth**:
  - More computer tiers with distinct stats.
  - Cosmetic base upgrades and seasonal events.
