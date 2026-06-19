# DataTycoon — Sprint Plan v0.23 (2-week sprint)

Owner: Nina (PM)  
Scope baseline: current codebase is **v0.22** (`Main.server.lua`, `GameClient.client.lua`) + review reports (Tess) + existing design notes in `CHANGELOG.md`.

## Sprint goals (v0.23)
1. **Make orb collection server-authoritative** (no multi-collect races; consistent for all players).
2. **Improve plot interaction** (buy nearest/targeted plot; better ownership visuals; remove hard-coded plot order).
3. **Stabilize data APIs** (safer `GetPlayerData`, reduce race conditions, add basic telemetry).
4. **Ship at least one performance win** from WorldBuilder part-count analysis.

Non-goals (explicitly out of scope for v0.23): PvP/raiding, monetization/gamepasses, full tutorial system, full ProfileService migration.

---

## 1) Current bugs / risks (from code + review reports)

> Count below includes code-level correctness issues, reliability risks, and balance/UX “bugs” called out in `CHANGELOG.md` known issues.

### A) Server / gameplay correctness
1) **Orbs are not server-authoritative (multi-collect / race condition)**  
- Source: `CHANGELOG.md` Known issues + server has no per-orb cooldown; client visuals only.  
- Impact: multiple players can collect the same orb at the same time; inconsistent “respawn” across clients.

2) **Orb anti-cheat response is too harsh: kicks on missing `workspace.DataOrbs`**  
- Source: `Main.server.lua` lines ~369–375.  
- Impact: if the world hasn’t spawned/streamed DataOrbs yet (or folder renamed), legitimate players can be kicked.

3) **`GetPlayerData` returns raw server table and can be `nil` during load**  
- Source: Tess report 1 + `Main.server.lua` lines ~485–487 and `PlayerAdded` uses `task.spawn(LoadPlayerData, player)`.  
- Impact: client invokes before data is ready → nil; also returns full table (unnecessary exposure / serialization risk / future schema coupling).

4) **Overlapping saves can occur (autosave + leaving) with no per-player ordering**  
- Source: DataStore best practices doc + code: autosave spawns SavePlayerData per player; PlayerRemoving also spawns SavePlayerData.  
- Impact: potential out-of-order writes; increases chance of lost progress under throttle.

5) **RemoteEvent handlers silently return on malformed input (low observability)**  
- Source: Tess report 1.  
- Impact: hard to debug mismatched client/server; exploit attempts produce no signal.

6) **Plot pricing curve is unintentionally flat**  
- Source: `docs/PlotPricingAnalysis.md`.  
- Impact: all 8 plots are at dist=3 → all cost 400; pacing is likely too fast and formula intent (“outward expansion”) is not realized.

### B) Client stability / UX
7) **Infinite yield risk: `player:WaitForChild("PlayerGui")` has no timeout**  
- Source: Tess report 2 + `GameClient.client.lua` line ~26.  
- Impact: rare but catastrophic “client HUD never loads.”

8) **Buy Plot [E] uses hard-coded plot order (not contextual)**  
- Source: `CHANGELOG.md` known issues + client code lines ~395–406.  
- Impact: confusing UX; players cannot intentionally buy the plot they’re near/looking at.

9) **Orb fade radius can affect adjacent orbs**  
- Source: `CHANGELOG.md` known issues + client fades all parts within 12 studs of returned orbPos.  
- Impact: if two orb rings are close, collecting one may visually hide multiple.

### C) Performance / scalability risks
10) **WorldBuilder runtime-generated parts are extremely high (~3,581 parts)**  
- Source: `docs/PerformanceOptimization.md`.  
- Impact: lower FPS on mobile/low-end; more physics/draw overhead; increased replication/streaming work.

**Bug/risk count: 10**

---

## 2) Prioritized v0.23 feature list (roadmap-driven)

Roadmap guidance pulled from `CHANGELOG.md` “Next steps / roadmap” short-term section.

### P0 (must ship)
1) **Server-authoritative orb state**  
- Track per-orb cooldown/state on server; prevent multi-collect; replicate availability to clients.

2) **Plot interaction improvements**  
- Buy nearest/targeted plot instead of cycling fixed order.
- Add clear ownership visuals (color/sign updates) so players understand what’s owned.

3) **Data API hardening (client/server contract)**  
- Make `GetPlayerData` safe (ready checks + return a sanitized snapshot).
- Reduce load races between UI and server data readiness.

### P1 (should ship)
4) **Performance pass: reduce WorldBuilder part count (high ROI)**  
- Convert flowers/foliage to MeshParts or lower density in far areas.

5) **Orb UX polish with authoritative state**  
- Client should hide/show only the specific orb instance; avoid radius-based overlap.

### P2 (nice-to-have if time remains)
6) **Plot pricing rebalance**  
- Either introduce distance tiers (new coords) or change pricing to purchase-index based.

7) **Telemetry / exploit visibility**  
- Lightweight server warnings / counters for invalid remote calls (rate-limited).

---

## 3) Task breakdown with effort estimates

Effort scale: **S** (≤0.5d), **M** (1–2d), **L** (3–5d), **XL** (6–10d).

### P0 — Orb server authority
1. Implement orb registry on server (unique orb ids, positions, cooldown timestamps) — **L**  
   - Dependencies: WorldBuilder naming/structure (need stable orb instance identification).
2. Change `CollectOrb` flow to validate **orbId** rather than raw position — **M**  
   - Client sends orbId; server checks orb available + distance to player + cooldown.
3. Replicate orb availability to clients (Attributes on orb parts or `OrbStateChanged` event) — **M**
4. Replace kick-on-missing-DataOrbs with “deny + warn + retry later” — **S**

### P0 — Plot interaction
5. Implement “buy nearest plot” (server-side: compute nearest unowned plot to player HRP within range) — **M**
6. Update client Buy Plot button + E-key to request “buy nearest” (no hard-coded list) — **S**
7. Ownership visuals: update plot markers/signs for owner + price + availability (client listens to PlotPurchased/PlotSold; server provides initial state) — **L**  
   - Dependency: plot marker instances exist (WorldBuilder).

### P0 — Data API hardening
8. Make `GetPlayerData` return a sanitized snapshot + readiness response — **M**  
   - Return `{ok=true, data={...}}` with whitelisted fields only.
9. Add server “data ready” signal (e.g., `PlayerDataReady` RemoteEvent or attribute on player) — **M**
10. Client: handle “data not ready” gracefully in Stats panel (retry/backoff, disable button temporarily) — **S**

### P1 — Performance
11. Reduce foliage part count (flowers first): swap 7-part flower to 1 MeshPart or particle approach — **L**  
   - Target: save ~1,000+ parts (see PerformanceOptimization doc).
12. Mark decorative parts `CanQuery=false`, `CanTouch=false` where appropriate — **M**

### P2 — Economy / telemetry
13. Plot pricing rebalance proposal + implement chosen model — **M**  
   - Dependency: design decision (coordinate tiers vs purchase-index).
14. Rate-limited invalid-remote telemetry (server counters + occasional warn) — **S**
15. Client: add timeout to `WaitForChild("PlayerGui")` with fallback — **S**

---

## 4) 2-week timeline (week-by-week)

### Week 1 (Days 1–5): Core correctness + contracts
**Primary objective:** ship authoritative orb state end-to-end and remove major race conditions.
- Day 1–2: Tasks (8–10) Data API hardening + client fallback handling.
- Day 2–4: Tasks (1–4) Orb registry + orbId protocol + replication.
- Day 4–5: Task (5–6) Buy nearest plot (server+client) + quick sanity playtests.

Deliverable by end of Week 1:
- Orbs cannot be multi-collected; orb visibility consistent.
- Stats panel does not break if data isn’t ready.
- Buy Plot no longer cycles hard-coded list.

### Week 2 (Days 6–10): UX + performance + balance
**Primary objective:** clarity (ownership visuals) + measurable performance win.
- Day 6–7: Task (7) Ownership visuals + initial plot state sync.
- Day 7–9: Tasks (11–12) WorldBuilder optimization pass (flowers/foliage + touch/query flags).
- Day 9–10: Task (15) client PlayerGui timeout + (13–14) depending on remaining time.

Deliverable by end of Week 2:
- Plot ownership is obvious in-world.
- Part count reduced (target: meaningful, ideally >30% reduction in foliage-driven parts).
- v0.23 release candidate playtest + bugfix sweep.

---

## 5) Blockers, dependencies, and assumptions

### Dependencies
- **WorldBuilder structure**: orb instances and plot markers must have stable names/ids. If currently generated without ids, we need to add them (or derive via position hashing).
- **Client/server protocol changes**: switching from orbPos → orbId requires coordinated deploy (server should support both temporarily or gate by version).
- **Performance work depends on asset availability**: MeshParts for flowers/trees/bushes may require art pipeline or choosing lightweight primitives/particles.

### Blockers / risks
- **StreamingEnabled / replication timing**: if DataOrbs or plot markers stream in late, server logic must not kick players and client must handle late appearance.
- **DataStore throttling remains a risk**: v0.23 plan does not include full session-locking + save-queue refactor (flagged for v0.24 unless scope expands).
- **Economy tuning decision needed**: plot pricing model choice affects player pacing; requires quick design sign-off before implementing task (13).

### Assumptions
- We can add one or more RemoteEvents/Functions in `ReplicatedStorage/Events` without breaking existing flows.
- We can safely modify WorldBuilder to reduce part count without changing gameplay collision paths.

---

## Acceptance criteria (v0.23)
- Orb can only be collected if server says it’s available; no concurrent multi-collect; no kicks due solely to missing `DataOrbs` folder.
- Buy Plot action purchases the plot the player is near/targeting; no fixed cycling list.
- `GetPlayerData` never hard-errors the client; returns `{ok=false}` while loading; returns sanitized data once ready.
- Performance: observable reduction in runtime part count / improved FPS on a low-end test device (or at minimum, significant instance-count reduction from foliage).
