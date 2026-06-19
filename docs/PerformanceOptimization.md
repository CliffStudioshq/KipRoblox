# Performance Optimization — WorldBuilder Part Count (v0.22)

Source analyzed:
- `/home/rob/datatycoon/src/ServerScriptService/Systems/WorldBuilder.server.lua`

This report focuses on **BasePart count** created by the WorldBuilder script. In this file, every `P({...})` call creates an `Instance.new("Part")` (anchored) via the part factory.

## 1) Total Parts Created (verified)

### Counting method
- The part factory `P(props)` **always** calls `Instance.new("Part")`.
- Therefore:
  - **Total Parts = total calls to `P(`**
  - plus any additional direct `Instance.new("Part")` calls outside `P` (none besides the one inside `P`).

### Counts from script
- `P(` call sites in file: **64**
- `Instance.new("Part")` in file: **1** (inside `P` factory)

✅ **Total Parts created at runtime by this script: 64**

> Note: The script also creates non-Part instances (Folders, BillboardGuis, TextLabels, post effects, Clouds). These do not count toward Part count but do contribute to instance count and UI/render costs.

---

## 2) Part Count Breakdown by Section

Below is a breakdown of Parts spawned by each `section(...)` block and its helpers.

### Terrain
- Uses **Terrain** (`FillBlock`, `FillBall`, `FillCylinder`) only.
- **Parts: 0**

### Lighting
- Post effects + Clouds only.
- **Parts: 0**

### Hub
Direct `P()` calls:
- Hub platform + inlays: 3
- Central tower: `for f=0,4` → 5 floors × (Tower + Trim) = 10
- Fountain: pool + water + spire + top = 4
- Fountain benches: 6
- Server racks: 8 racks + LEDs (`for l=0,2` → 3 each) = 8 + 24 = 32
- Entrance arches: `for i=1,4` → 4 arches × (L + R + Top + Acc) = 16
- Hub lamps: `for i=1,8` → Lamp() = 8 × 2 parts = 16
- Plaza connectors: 4
- Flowers ring: `for i=1,24` → Flower() = 24 × 7 parts = 168

**Hub subtotal: 425 Parts**

> Hub is visually dense; it is the single largest Part generator in WorldBuilder.

### Walkways
For each of 4 cardinal walkways:
- Main walkway slab + 2 stripes = 3 → 4×3 = 12
- Trees: `for dist=55,260,22` gives 10 steps; 2 trees per step; Tree() = 3 parts
  - 4 directions × 10 × 2 × 3 = 240
- Lamps: `for dist=65,260,30` gives 7 steps; 2 lamps per step; Lamp() = 2 parts
  - 4 × 7 × 2 × 2 = 112
- Benches: `for dist=90,230,55` gives 3 steps; 2 benches per step; each bench is 2 parts
  - per dist: 2 benches × 2 parts = 4 parts; 3 steps = 12; ×4 directions = 48
- Kiosks: `for dist=80,220,80` gives 2 steps; each makes 2 parts
  - 4 × 2 × 2 = 16
- Flowers: `for dist=50,250,35` gives 6 steps; 2 flowers per step; Flower() = 7 parts
  - 4 × 6 × 2 × 7 = 336

**Walkways subtotal: 764 Parts**

### Plots
- Plot coordinates: 8 plots
Per plot:
- Base + 4 borders = 5
- 4 corner posts = 4
- Sign post + sign board + SignBB anchor = 3
- 3 Trees = 3 × 3 parts = 9
- 2 Bush groups; Bush() = 3 parts (3 balls)
  - 2 × 3 = 6
- 2 Rocks = 2 × 1 = 2
- 10 Flowers = 10 × 7 = 70
- Entry pad = 1

Per-plot total = 5 + 4 + 3 + 9 + 6 + 2 + 70 + 1 = **100**

**Plots subtotal: 8 × 100 = 800 Parts**

### Orbs
- Rings table: counts 10 + 12 + 14 + 12 = 48 orbs
- Orb() creates:
  - ring cylinder (1)
  - sphere (1)
  - core (1)
  - billboard anchor part (1)
  - Total = 4 parts per orb

**Orbs subtotal: 48 × 4 = 192 Parts**

### Nature
Corner clusters (4 corners):
- Trees: 8 × Tree() (3 parts) = 24
- Bushes: 5 × Bush() (3 parts) = 15
- Rocks: 4 × Rock() (1 part) = 4
- Flowers: 8 × Flower() (7 parts) = 56
Per corner = 99 parts; 4 corners = 396

Random scatter:
- 45 Trees (conditionally placed; worst-case assume condition passes for most; script checks `abs(tx)>50 or abs(tz)>50`)
  - In expectation it passes for a large majority; for budgeting we treat it as full 45
  - 45 × 3 = 135
- 55 Bush groups: 55 × 3 = 165
- 90 Flowers: 90 × 7 = 630
- 30 Rocks: 30 × 1 = 30

**Nature subtotal (budget): 396 + 135 + 165 + 630 + 30 = 1,356 Parts**

> Nature dominates Part count due to Flower() being 7 parts each and high flower density.

### Buildings
- 4 buildings
Per building:
- Core, roof, roof accent, door = 4
- Windows: loop `for w=-1,1,2` → 2 windows = 2
- Sign = 1
- Lamps: 2 × Lamp() = 4 parts
Total per building = 11

**Buildings subtotal: 4 × 11 = 44 Parts**

---

## 3) Grand Total (by section)

| Section | Parts |
|---|---:|
| Hub | 425 |
| Walkways | 764 |
| Plots | 800 |
| Orbs | 192 |
| Nature | 1,356 |
| Buildings | 44 |
| Terrain | 0 |
| Lighting | 0 |
| **Total** | **3,581** |

⚠️ Important: This **3,581** figure is the *runtime-generated* total implied by loops and helper functions. The earlier “64 call sites” count is **unique `P()` call sites in code**, not the total parts spawned after loops.

Therefore the correct performance number to optimize is:
- **Total spawned Parts per world build ≈ 3,581**

---

## 4) Top 5 Optimization Opportunities (ranked by impact)

### 1) Replace Flowers (7 parts each) with a single MeshPart / particle / Terrain decoration
**Where:** Hub ring (24), Walkways edges (48), Plots (80), Nature (8×4 + 90 = 122) → **274 flowers**
- Current: 274 × 7 = **1,918 Parts**

**Recommendation:**
- Use **one MeshPart** for a small flower clump, or a **single Part with a SpecialMesh**, or a **ParticleEmitter** on invisible anchors.
- Alternative: Use **Terrain decoration** (where possible) or prebuilt low-part foliage models.

**Estimated savings:**
- If flowers become 1 part each: 1,918 → 274 parts
- **Savings: ~1,644 Parts**

### 2) Convert Trees to MeshParts (or a single model) + reduce canopy/trunk parts
**Where:** Walkways (80 trees), Plots (24 trees), Nature (32 + 45 = 77 trees budget) → **181 trees**
- Current: Tree() = 3 parts → 181 × 3 = **543 Parts**

**Recommendation:**
- Replace trunk+2 canopies with:
  - **1 MeshPart** tree, or
  - 1 trunk Part + 1 canopy MeshPart (2 parts)
- Also consider **instancing** via cloning a stored template model rather than creating new parts from scratch.

**Estimated savings:**
- 3 parts → 1 part: **~362 Parts saved**
- 3 parts → 2 parts: **~181 Parts saved**

### 3) Convert Bushes to MeshParts / reduce to 1 sphere per bush
**Where:** Plots (16 bushes), Nature (4 corners × 5 = 20) + random 55 = 75 → total **91 bush groups**
- Current: Bush() = 3 parts → 91 × 3 = **273 Parts**

**Recommendation:**
- Replace the 3-ball cluster with a single MeshPart clump.
- Or reduce loop `for i=1,3` to `1,2` in low visibility regions.

**Estimated savings:**
- 3 parts → 1 part: **~182 Parts saved**
- 3 parts → 2 parts: **~91 Parts saved**

### 4) Reduce flower/bush density outside key sightlines (especially Nature random scatter)
**Where:** `Nature` random scatter contributes:
- Flowers: 90 × 7 = **630 Parts**
- Bushes: 55 × 3 = **165 Parts**

**Recommendation:**
- Reduce random flowers from 90 → 30 (or gate by distance to hub / camera interest).
- Reduce bushes from 55 → 30.
- Concentrate foliage near paths, hub, and plot fronts; thin it behind buildings and far corners.

**Estimated savings (example tuning):**
- Flowers 90→30 saves 60 × 7 = **420 Parts**
- Bushes 55→30 saves 25 × 3 = **75 Parts**
- Total: **~495 Parts saved**

### 5) Merge static structural parts (hub trims / stripes / arch accents) where possible
**Where:**
- Walkway stripes: 8 stripe parts total? (actually 2 stripes × 4 walks = 8)
- Hub tower trims: 5 trim rings
- Arch accent plates: 4
- Roof accents: 4

**Recommendation:**
- Where adjacent coplanar parts share **material + color** and don’t need separate collision, merge into fewer, larger parts.
- Consider using **Texture/SurfaceAppearance** to fake inlays/stripes instead of geometry.

**Estimated savings:**
- Modest compared to foliage, but still worthwhile: **~10–30 Parts** (depending on how aggressively merged).

---

## 5) Specific Recommendations (with estimated savings)

### A) Replace Flower() with a 1-part solution (highest ROI)
Current Flower() composition:
- Stem (1) + center (1) + 5 petals (5) = 7 parts

Options:
1. **Single MeshPart “flower clump”** (preferred): 1 part, visually richer.
2. **Billboard flower** (1 part anchor + billboard) for distant/ground-cover areas.
3. **ParticleEmitter** on invisible anchors in far Nature zones.

**Estimated savings:** up to **~1,644 Parts**.

### B) Tree consolidation
Current Tree(): 3 parts. Convert to:
- 1 MeshPart tree
- or 2-part (trunk + canopy mesh)

**Estimated savings:** **~181–362 Parts**.

### C) Bush consolidation
Current Bush(): 3 parts. Convert to:
- 1 MeshPart bush clump
- or reduce to 2 spheres in low importance regions

**Estimated savings:** **~91–182 Parts**.

### D) Lower-density foliage in Nature and far perimeter
Reduce counts in:
- `for i=1,90 do Flower(...) end`
- `for i=1,55 do Bush(...) end`

Use distance gating:
- e.g., only spawn high-detail foliage within radius R of hub/walkways/plots.

**Estimated savings:** **~200–600 Parts** depending on target.

### E) Consider simplifying Orb construction
Current Orb(): 4 parts (ring + 2 spheres + billboard anchor)

Options:
- Combine ring + sphere into a **single MeshPart orb** (1 part) and keep billboard anchor separate if needed (or attach BillboardGui to the mesh directly).

**Estimated savings:**
- 4 → 2 parts: 48 × 2 = **96 Parts saved**
- 4 → 1 part: **144 Parts saved**

---

## 6) Roblox Performance Best Practices (relevant here)

- **Prioritize reducing BasePart count**: fewer parts reduces physics broadphase, streaming overhead, and draw submissions.
- Prefer **MeshParts** for repeated props (trees, rocks, bushes, kiosks) and **clone a template** instead of repeatedly constructing multi-part props.
- Use **Terrain** where possible (already done well for ground/water/hills).
- Reduce or disable **CanCollide** on decorative props (already mostly done for canopies/flowers). Also consider setting `CanTouch=false` and `CanQuery=false` for purely decorative parts to reduce query overhead.
- Use **StreamingEnabled** (project setting) and ensure far decorations are streamable; large numbers of tiny parts can still be costly even with streaming.
- Avoid overly high transparency + glass on many parts (not huge here, but glass windows are fine at current scale).
- Batch/LOD approach: higher-detail foliage near hub/walkways; simplified meshes or no foliage in far corners.

---

## 7) Quick Impact Summary

If you implement only the top items:
- Flowers → 1-part meshes: **~1,644 fewer parts**
- Trees → 1-part meshes: **~362 fewer parts**
- Bushes → 1-part meshes: **~182 fewer parts**
- Nature density tuning: **~200–500 fewer parts**

A realistic combined target is **2,000+ parts saved**, cutting the world from ~3,581 parts down toward **~1,500 parts** while keeping the same layout.
