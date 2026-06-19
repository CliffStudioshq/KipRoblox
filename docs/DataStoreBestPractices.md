# DataTycoon — Roblox DataStore Best Practices (2025/2026)

This document summarizes modern Roblox **DataStore** guidance and applies it specifically to DataTycoon’s current implementation in:
- `src/ServerScriptService/Systems/Main.server.lua`

Primary references:
- Roblox Creator Hub: **Data store error codes and limits** (limits, throttling, queue sizes, storage): https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- Roblox Engine API: **DataStoreService** (budgets, APIs): https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- Roblox Creator Docs (GitHub mirror): **Best practices for data stores**: https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/best-practices.md
- Roblox DevForum (announcement): **DataStores Access and Storage Updates** (early 2026 changes): https://devforum.roblox.com/t/datastores-access-and-storage-updates/3597255
- Roblox Staff DevForum: **Implementing Player Data and Purchasing Systems** (retries + ordering + session locking): https://devforum.roblox.com/t/implementing-player-data-and-purchasing-systems/2839941

---

## 1) Current DataStore limits and quotas (2025/2026)

### 1.1 Per-object size limit (value size)
- Roblox’s current documented best-practice guidance references a **4 MB object size limit** per key/value object.  
  Source: Creator Docs best-practices page (object size limit).  
  https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/best-practices.md

Practical implication:
- Your `Player_<UserId>` payload must remain safely below this limit after serialization.
- Large arrays (plots/computers/inventories/logs) are the typical drivers of value bloat.

### 1.2 Request throttling, queues, and “dropped requests”
Roblox queues requests server-side and throttles when you exceed budget.

Key mechanics:
- **Each request queue has a limit of 30 requests.** If the queue fills, additional requests are **dropped** with error codes **301–306** (Get/Set/Increment/Update/GetSorted/Remove throttle).  
  Source: error codes and limits.  
  https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

Implications:
- Bursty patterns (many simultaneous `GetAsync` on join spikes, or autosave for many players at once) can overflow queues.
- When you see error codes 301–306, you’re not “slow” — requests were **discarded**, so retries must be done carefully.

### 1.3 Throughput measurement (KB rounding)
- Roblox counts throughput per request rounded **up to the next kilobyte**.  
  Source: error codes and limits.  
  https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

Implication:
- Many tiny writes are inefficient; prefer fewer, larger, well-structured writes.

### 1.4 Storage quota (latest version storage)
Roblox documents a storage limit formula:
- **Total latest version storage limit = `100 MB + 1 MB * lifetime user count`**  
  Source: error codes and limits.  
  https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

Operational implications:
- Storing lots of per-user keys or “event history” keys can scale storage quickly.
- Monitor via Creator Hub **Data Stores Manager** / dashboards, and delete test/event keys when done.

### 1.5 Access limits moving to “per-experience” (early 2026)
Roblox announced a major change:
- DataStore access limits move from **per-server** to **per-experience (per-universe)**, with **substantially increased limits** planned for **early 2026**.  
  Source: DevForum announcement.  
  https://devforum.roblox.com/t/datastores-access-and-storage-updates/3597255

The announcement includes an (upcoming) table for **requests per minute per universe** for standard DataStores, using formulas based on **CCU** (concurrent users), e.g.:
- **Get:** `250 + CCU * 40` requests/min/universe
- **Set:** `250 + CCU * 20` requests/min/universe
- **List:** `10 + CCU * 2` requests/min/universe
- **Remove:** `100 + CCU * 40` requests/min/universe

Notes:
- These are the **new model** described for early 2026; in-flight or staged rollout can mean your live experience may still be under older enforcement until Roblox flips it.

### 1.6 Request budgets at runtime
Roblox provides runtime introspection:
- `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.XXX)` returns current budget.  
  Source: DataStoreService docs.  
  https://create.roblox.com/docs/reference/engine/classes/DataStoreService

Best practice:
- Use budgets to smooth bursts (especially autosaves) rather than letting bursts hit the 30-queue drop limit.

---

## 2) Retry strategies for failed requests

### 2.1 Always wrap DataStore calls
- Wrap all calls in `pcall()`; errors can be connectivity, throttling, shutdown, payload size, etc.  
  Source: error codes and limits.  
  https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

### 2.2 Treat some failures as “unknown outcome”
Roblox explicitly warns:
- A failed write call (ex: `UpdateAsync`) means the server didn’t receive a success response, **but the backend write might still have occurred**. In some scenarios, the final state is unknown until verified by follow-up read (without cache).  
  Source: error codes and limits.  
  https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits

Practical implications:
- Naively retrying the exact same write can cause duplication or regression if the first attempt actually succeeded.
- Prefer **idempotent** updates or “merge” updates where safe.

### 2.3 Prefer exponential backoff + jitter
Typical modern pattern:
- Retry on transient failures with **exponential backoff** (e.g., 1s, 2s, 4s, 8s…) plus **random jitter** to avoid herd effects.
- Cap maximum delay and attempts.

Your retry should be **selective**:
- Retry transient failures (throttling 301–306, internal errors, temporary outages)
- Don’t retry permanent input failures (key name empty/too long, value too large, serialization errors)

### 2.4 Preserve ordering per key (critical)
Roblox Staff calls out a common bug:
- Naive retries can execute out of order and overwrite newer state with older state.

Example from the Staff post:
- Request A sets K = 1, fails, retry scheduled.
- Request B sets K = 2.
- Retry of A later writes K back to 1.

Source (retries/order discussion):
- https://devforum.roblox.com/t/implementing-player-data-and-purchasing-systems/2839941

Best practice:
- Serialize requests **per key** (a per-key queue) so that retries for a key cannot overtake later writes.

### 2.5 Use `UpdateAsync` transforms for “merge” semantics
- `UpdateAsync(key, transformFn)` provides server-side atomic transforms for that key.

Caveat:
- `UpdateAsync` is not a magic bullet if your logic “returns an old snapshot”; you still need ordering and correctness.

Best practice:
- In your transform, merge *only the deltas you intend*, and consider embedding:
  - `_dataVersion`
  - `lastWriteUnix`
  - `sessionId`
  - `writeCounter` (monotonic per session)

### 2.6 Budget-aware throttling
- Before large bursts (e.g., autosave loop), read budgets via `GetRequestBudgetForRequestType` and either:
  - spread saves over time, or
  - skip a cycle for some players and save them next tick.

This reduces queue fill and dropped requests.

---

## 3) Data migration patterns

Data migrations are inevitable when you add new mechanics, rename fields, or change schemas.

### 3.1 Store an explicit data version
Best practice:
- Include `_dataVersion` in each saved object.
- Migrate on load from old versions to current.

DataTycoon already does this:
- `DATASTORE_VERSION = 5`
- loads saved data, checks `saved._dataVersion or saved.DataVersion`, then performs stepwise migrations.

### 3.2 Stepwise migration blocks (vN → vN+1)
Recommended pattern:
- Migrate in ordered steps (1→2, 2→3, …), and update the stored version once complete.
- Keep migrations **pure** (no yielding, no DataStore calls inside the migration itself).

### 3.3 Reconciliation / default merging
After migrations:
- Merge in new default fields so old saves don’t break code.

DataTycoon does a default merge:
- Loops `DEFAULT_DATA` and sets missing keys to default values.

### 3.4 Key versioning vs object versioning
Roblox’s docs emphasize:
- Data stores version **individual objects**, not the entire store; storing a “single object per player” works well with rollbacks/versions.  
  Source: best practices.  
  https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/best-practices.md

Practical guidance:
- Keep a **single key per player** for most player-state.
- Avoid creating new keys for every schema version; that inflates key counts and storage.

### 3.5 Migration safety checks
Recommended:
- Validate types after migration (tables vs numbers), clamp ranges, and sanitize user-controlled fields.
- Consider storing `schemaHash` or `lastMigratedAt` for debugging.

---

## 4) Session locking recommendations

### 4.1 Why session locking matters
Even without “trading,” session locking prevents:
- **data regression** (new session loads old data while prior session save is still in flight)
- duplication exploits (rejoin quickly to reload prior state)
- cross-server overwrites during teleports or fast reconnects

Roblox Staff explicitly lists session locking as a core problem player data systems should solve.  
Source: https://devforum.roblox.com/t/implementing-player-data-and-purchasing-systems/2839941

### 4.2 Lock record fields (common pattern)
In the player’s DataStore object (same key), store:
- `activeSession = {
    serverJobId = game.JobId,
    sessionId = <random GUID>,
    lockTime = os.time(),
    lastHeartbeat = os.time(),
  }`

Then:
- On load, attempt to acquire lock via `UpdateAsync`:
  - If no lock, take it.
  - If lock exists but stale (heartbeat older than threshold), steal lock.
  - If lock exists and fresh, reject loading and ask player to rejoin.

### 4.3 Heartbeats and stale lock timeouts
Because servers can crash, locks must expire:
- Update `lastHeartbeat` periodically (e.g., every 30–60 seconds).
- Consider lock stale if heartbeat is older than (e.g.) 120–180 seconds.

Budget note:
- Heartbeats cost writes; do not heartbeat too often.

### 4.4 Release lock on normal exit
On `PlayerRemoving` and `BindToClose`, attempt to:
- Save the data
- Clear or mark the lock as released (best-effort)

### 4.5 Use a proven library when possible
If you don’t want to implement session locking and ordered retries yourself, use a well-known wrapper library that provides:
- session locking
- auto-save scheduling
- reconciliation
- ordered write queue

(Examples in the community include ProfileService / ProfileStore; evaluate suitability for your codebase and constraints.)

---

## 5) Recommendations for DataTycoon’s current implementation

This section is based on `Main.server.lua` as of **DataTycoon v0.22**.

### 5.1 What DataTycoon currently does well
- Uses **in-memory** `PlayerData` table and only hits DataStore on:
  - join (load)
  - leave (save)
  - autosave (every 60s)
  - server close (`BindToClose`)
- Uses `UpdateAsync` for saves (`dsSet`)
- Has basic `pcall` wrappers
- Implements **schema versioning + stepwise migration**
- Merges defaults to ensure forward compatibility

### 5.2 Gaps / risks to address

#### A) `dsSet` has no retry/backoff
Current:
- `dsSet` calls `UpdateAsync` once; if it fails, it logs and returns `false`.

Why it matters:
- transient failures are common (throttle/queues/shutdown). A single failure at `PlayerRemoving` can lose a whole session.

Recommendation:
- Implement retry with exponential backoff + jitter for writes.
- Preserve ordering per key (see below).

#### B) `dsGet` retries but backoff math is a bit odd
Current:
- `task.wait(1.5 ^ attempt)` which yields 1.5s, 2.25s, 3.375s.

Recommendation:
- Use standard exponential backoff with jitter, e.g. `base * 2^(attempt-1) + random()`.
- Consider a slightly larger cap for production (e.g. up to 10–15 seconds), especially during outages.

#### C) No request ordering / per-key queue
Current:
- Autosave loop spawns `SavePlayerData` for each player concurrently (`task.spawn(SavePlayerData, p)`), and `PlayerRemoving` also spawns a save.

Risk:
- Multiple saves for the same key can overlap and arrive out of order.
- Roblox Staff explicitly warns naive retries can apply out-of-order.

Recommendation:
- Add a **per-player (per-key) save queue**:
  - Only one in-flight DataStore operation per player key.
  - Coalesce multiple save requests into “save latest state” when appropriate.

#### D) No session locking
Current:
- Loads `Player_<UserId>` and then writes back on timers/exit.

Risk:
- If the player rejoins quickly or teleports and old server saves late, the old server can overwrite newer state.

Recommendation:
- Implement session locking (fields inside the saved object + `UpdateAsync` acquisition).
- If lock cannot be acquired, inform the player (“Data still saving from another server; please rejoin”).

#### E) “Whole-object overwrite” behavior in `dsSet`
Current:
- `UpdateAsync(key, function() return value end)` returns the entire in-memory `data` table.

Risk:
- If multiple systems ever write to the same key (or you later add cross-server write patterns), returning the full snapshot can overwrite changes.

Recommendation:
- Continue saving a single object, but prefer update transforms that merge and/or validate:
  - Ensure `_dataVersion` always set
  - Ensure lock/session fields are correct
  - Optionally keep a `lastWrite` time and `writeCounter`

#### F) BindToClose save does not yield for completion
Current:
- `BindToClose` loops `SavePlayerData(p)` directly (not spawned) which is good, but `SavePlayerData` itself doesn’t retry.

Recommendation:
- Ensure `BindToClose` uses a bounded “save with retries” and yields until either success or timeout, to maximize last-chance persistence.

### 5.3 Concrete improvements checklist for DataTycoon

1) **Implement a DataStore wrapper module** (recommended) that provides:
   - per-key request queue
   - retries with exponential backoff + jitter
   - budget-aware scheduling
   - optional “verify after ambiguous write failure” for critical transactions

2) **Add session locking** to the player object:
   - acquire lock on load via `UpdateAsync`
   - heartbeat at a low rate
   - release on exit (best effort)

3) **Autosave smoothing**:
   - rather than saving all players in one 60s burst, stagger across the minute
   - skip saves when budget is low

4) **Instrument failures**:
   - log error codes and categorize (throttle vs validation)
   - track save success rate in analytics/logging to catch issues early

5) **Keep payload small**:
   - avoid storing derived values (like `dps`) if it can be recomputed
   - avoid unbounded logs/history arrays in the player object

---

## Appendix: Mapping common failure modes to actions

- **301–306 throttle / queue full:** backoff + retry; reduce burstiness; check budgets.
- **105 ValueTooLarge:** reduce saved payload size (prune arrays, compress, store less).
- **401/402 shutdown access:** expect in shutdown; rely on earlier autosaves; keep close handler efficient.
- **103/104 serialization errors:** validate data types before saving; avoid Instances, userdata, functions.

---

## DataTycoon quick notes (schema)
Current saved keys include:
- `Data`, `TotalEarned`, `TotalSpent`
- `Plots` (array of plotIds)
- `Computers` (array of {tier, plotId, name, dps})
- `HouseTier`, `DailyStreak`, `LastDailyReward`
- `BlocksCollected`, `LastSeen`
- `_dataVersion`

Consider pruning derived fields:
- `Computers[*].name` and `Computers[*].dps` can be recomputed from `tier` (saves space and prevents mismatch if CONFIG changes).