# DataTycoon — Plot Pricing Balance Analysis (v0.22)

Source: `/home/rob/datatycoon/src/ServerScriptService/Systems/Main.server.lua`

## 0) What the code does (ground truth)

### Plot positions (all 8) and coordinates
In `InitPlots()` the game defines **8 fixed plot coordinates** (grid coords, not world studs):

```lua
local coords = {{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
```

So the eight plots are:

| PlotId | (x, z) |
|---|---:|
| `plot_-3_-3` | (-3, -3) |
| `plot_-3_3`  | (-3, 3)  |
| `plot_3_-3`  | (3, -3)  |
| `plot_3_3`   | (3, 3)   |
| `plot_0_-3`  | (0, -3)  |
| `plot_0_3`   | (0, 3)   |
| `plot_-3_0`  | (-3, 0)  |
| `plot_3_0`   | (3, 0)   |

World positioning: each plot center is placed at `Vector3.new(x*170, 0.5, z*170)`.

### Plot pricing formula
Each plot price is computed as:

```lua
price = math.floor(50 * (2 ^ math.max(math.abs(x), math.abs(z))))
```

This matches the provided formula: **price = floor(50 * (2 ^ max(abs(x), abs(z))))**.

### How plots are purchased (and what they unlock)
Purchasing is handled by the `PurchasePlot` RemoteEvent:

* Validates `plotId` is a string, that the plot exists, and that it is not already owned.
* Checks the player has not exceeded the number of plots allowed by their current **House tier**:

```lua
local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
if safeLen(data.Plots) >= ht.maxPlots then
    Notify(player, "Upgrade house for more plots!", "error")
    return
end
```

* Checks the player has enough currency (`data.Data`) to pay `plot.price`.
* Deducts price, assigns ownership, and appends the plotId into `data.Plots`.
* Fires `PlotPurchased` to all clients for world/UI updates.

What a purchased plot unlocks in practice:

* **Ownership of that plot tile** (server-side state: `plot.owner` and the plotId in `data.Plots`).
* **Ability to place computers on that plot**, because `PlaceComputer` requires `plot.owner == player.UserId`.
* Therefore, plots indirectly unlock higher DPS by allowing more computer placements, but **the real cap is House tier** (`maxComputers` and `maxPlots`).

Selling is also supported (`SellPlot` RemoteEvent):

* Only the owner can sell.
* Refund is **50% of purchase price**: `math.floor(plot.price * 0.5)`.
* When selling, the server also removes any computers on that plot from the player’s `data.Computers` and clears `plot.computers`.

### Progression context: DPS / income
Passive income runs every second:

* Base income: `CONFIG.PASSIVE_INCOME = 1` Data/sec.
* Plus sum of `dps` from owned computers (tiers: 2, 8, 30, 120 Data/sec).

So “DPS” in this report means **Data per second**.

## 1) Plot prices for the 8 defined plots

Because all plots are at |x| or |z| = 3, every plot has the same distance term:

* `dist = max(abs(x), abs(z)) = 3`
* `price = floor(50 * 2^3) = floor(50 * 8) = 400`

| PlotId | (x, z) | dist | Price (Data) |
|---|---:|---:|---:|
| `plot_-3_-3` | (-3, -3) | 3 | 400 |
| `plot_-3_3`  | (-3, 3)  | 3 | 400 |
| `plot_3_-3`  | (3, -3)  | 3 | 400 |
| `plot_3_3`   | (3, 3)   | 3 | 400 |
| `plot_0_-3`  | (0, -3)  | 3 | 400 |
| `plot_0_3`   | (0, 3)   | 3 | 400 |
| `plot_-3_0`  | (-3, 0)  | 3 | 400 |
| `plot_3_0`   | (3, 0)   | 3 | 400 |

**Key balance observation:** with the current coordinate set, the exponential formula never actually creates a curve; it collapses to a single flat price point.

## 2) Time-to-earn each plot at different DPS levels

Time (seconds) = `price / DPS`.

Since all plots cost 400 Data, time-to-earn is identical for all 8 plots:

| DPS (Data/sec) | Time to 400 Data | Time (mm:ss) |
|---:|---:|---:|
| 10 | 40.0 s | 0:40 |
| 50 | 8.0 s | 0:08 |
| 100 | 4.0 s | 0:04 |
| 500 | 0.8 s | 0:00.8 |
| 1000 | 0.4 s | 0:00.4 |

If you want this expressed as “plots per minute”:

* 10 DPS: 1.5 plots/min
* 50 DPS: 7.5 plots/min
* 100 DPS: 15 plots/min

## 3) Comparison: pricing curves used in similar Roblox tycoon/expansion systems (web research)

The broader Roblox tycoon ecosystem typically uses one of these progression strategies for expansions/plot growth:

1. **Linear cost per expansion** (each expansion adds a fixed amount, or increases by a fixed increment)
2. **Exponential / multiplicative cost scaling** (each new expansion costs ~1.2×–2× the previous)
3. **Per-tile fixed cost** (tile painting / plot enlargement where each tile costs the same)
4. **Dual-currency gating** (cash + premium/mission currency) or gamepass shortcuts

Relevant examples located via web search:

* **Theme Park Tycoon 2 — Plot expansions** (wiki): total to unlock all space is on the order of **$1,600,000 + 9000 credits** (two-resource gate). This indicates a long-tail expansion system where the last expansions are meaningful, and also optionally monetized via gamepasses. Source: search result pointing to `tpt2.fandom.com/wiki/Plot_expansions` (direct page fetch failed from this environment).

* **Lumber Tycoon 2 — Land** (wiki, per web snippet): “first land expansion costs $3,000 and each subsequent expansion costs $3,000 more than the last” (classic linear-increment model). Source: search result pointing to `lumber-tycoon-2.fandom.com/wiki/Land` (direct page fetch failed from this environment).

* **Roblox DevForum discussion**: devs commonly describe tycoon pricing as **linear or exponential**, and recommend making pricing a function of progression order/importance rather than manually setting each purchase. Source (successfully fetched): https://devforum.roblox.com/t/how-would-i-make-a-auto-calculating-tycoon-price-script/2069090

Takeaway vs DataTycoon:

* DataTycoon currently *intends* an exponential-with-distance pricing curve, but because all plots are at the same `dist=3`, it behaves like a **flat per-plot fee**.
* Many established tycoon games ensure that later expansions are significantly more expensive or require special currency, so expansions remain meaningful after early-game acceleration.

## 4) Balance assessment & recommendations (with specific numbers)

### A. Main problem: the curve is neutralized by coordinates
With only distance=3 plots available, the formula yields a single cost (400). This creates these gameplay effects:

* Plot purchasing quickly becomes trivial even at moderate DPS.
* There is little sense of “working outward” or unlocking increasingly valuable land.
* House tiers allow up to 8 plots by tier 3 (`Modern House`), meaning by the time a player can own all plots, each additional plot is still only 400.

If the design goal is “expanding outward gets pricier,” you need either:

1) plots at different distances (dist 1,2,3,4,...) **or**
2) a different formula driven by purchase order rather than coordinate distance.

### B. Recommendation path 1 (minimal code change): adjust coordinates to create distance tiers
Keep the existing formula, but redefine `coords` to include multiple distances.

Example: 8 plots with dist spread {1,1,2,2,3,3,4,4}.

One possible set:

* dist 1: (1,0), (-1,0)
* dist 2: (0,2), (0,-2)
* dist 3: (3,0), (-3,0)
* dist 4: (0,4), (4,0)

Then prices become:

* dist 1: floor(50*2^1)=100
* dist 2: 200
* dist 3: 400
* dist 4: 800

This gives a clear early-to-mid ramp and keeps the formula’s original intent.

If you want a longer tail without adding more than 8 plots, increase the base or exponent:

* Option: `price = floor(75 * 2^dist)` → dist 1..4 = 150, 300, 600, 1200
* Option: `price = floor(50 * 2^(dist+1))` → dist 1..4 = 200, 400, 800, 1600

### C. Recommendation path 2 (keep the 8 positions): rebase price on purchase index, not distance
If those 8 coordinates are fixed for layout reasons, then compute price by “which number plot this is for the player.”

For example, let the nth purchased plot cost:

* `price(n) = floor(200 * 1.6^(n-1))`

This yields (rounded):

1) 200
2) 320
3) 512
4) 819
5) 1310
6) 2096
7) 3354
8) 5366

Why this helps:

* Maintains excitement: later plots remain meaningful even with high DPS.
* Produces a curve similar to many tycoon upgrade chains (multiplicative growth).

### D. Specific tuning suggestions relative to DataTycoon DPS
Given computer tiers add substantial DPS (2, 8, 30, 120) and passive base is 1, players can quickly move from 1–10 DPS into 50+ DPS.

A good target is often:

* Early plots: 10–60 seconds each at “early DPS” (5–15 DPS)
* Mid plots: 1–3 minutes each at “mid DPS” (20–80 DPS)
* Late plots: 3–10 minutes each at “late DPS” (100–300 DPS)

Current system: at 50 DPS, plots are 8 seconds → far below those targets.

Concrete adjustment (if keeping dist=3 for all 8 plots):

* Raise base cost from 50 to **500** (10×): `price = floor(500 * 2^3) = 4000`.
  * Then time at 10 DPS: 400s (6:40), 50 DPS: 80s (1:20), 100 DPS: 40s.
  * Still might be too long for the first plot unless the player starts with higher DPS.

Better: make costs varied (either coordinate tiers or purchase-index tiers). If you implement purchase-index pricing, recommended parameters:

* Start: **250**
* Multiplier: **1.5**

`price(n)=floor(250*1.5^(n-1))` gives:

1) 250
2) 375
3) 562
4) 843
5) 1265
6) 1898
7) 2847
8) 4271

At 10 DPS: 25s → 7m7s by plot 8. At 50 DPS: 5s → 1m25s by plot 8. This creates a decent ramp without becoming extreme.

### E. Design note: house tier gating should align with plot costs
House tiers cap plots as: 2, 4, 8, 8, 8.

If plot prices ramp significantly, consider making house upgrades the main “spend” while plots are cheap, **or** plots the main spend while house upgrades are cheap — but avoid both spiking simultaneously.

Current house costs: 0 → 300 → 1500 → 8000 → 30000.

If you keep house costs as-is, plot costs probably should not exceed ~5k total to acquire all 8, otherwise players may feel forced into house upgrades *and* expensive plots at the same time.

## 5) Summary

* The plot price formula is exponential with distance, but all 8 plots have distance 3, so **every plot costs 400 Data**.
* At typical DPS levels, plots are purchased extremely quickly, making plot expansion a weak progression lever.
* Comparable Roblox tycoon systems commonly use linear-increment, multiplicative/exponential, per-tile, or dual-currency gating to keep later expansions meaningful.
* Best fix: either add plot distance variety (minimal code change) or price plots by purchase order (best for fixed-layout maps).
