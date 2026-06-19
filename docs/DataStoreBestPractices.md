# Roblox DataStore Best Practices (2025/2026)

This document summarizes current (2025/2026) Roblox DataStore guidance and applies it to **DataTycoon**’s current implementation.

**Primary references (Creator Hub):**
- Data store error codes and limits: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- Implement player data & purchasing systems (includes retry ordering + session locking discussion): https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- Versioning, listing, and caching: https://create.roblox.com/docs/en-us/cloud-services/data-stores/versioning-listing-and-caching.md
- DataStoreService class reference (request budgets, rate limit formula, etc.): https://create.roblox.com/docs/en-us/reference/engine/classes/DataStoreService.md

---

## 1) Current DataStore limits and quotas

Roblox DataStores have **multiple, overlapping constraints**:

### A. Request budgets (throttling)
- DataStore calls are subject to **request budgets** by request type. Exceeding budgets leads to throttling.
- Roblox exposes budgets via:
  - `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.<...>)`
- **Important nuance:** `UpdateAsync()` consumes from **both** the **read** and **write** budgets (Creator Hub explicitly notes this).

**Best practice:**
- Avoid “high frequency” datastore reads/writes in normal gameplay. Keep state **in-memory** on the server and persist at key points (join, periodic autosave, leave, purchases).

### B. Per-request queue size
Creator Hub specifies:
- **Each queue has a limit of 30 requests**.
- If the queue is full, requests can be **dropped** with error codes in the **301–306** range.

What this means operationally:
- Even if your average rate is OK, **bursts** (e.g., server start with many `GetAsync`, autosave tick for all players, mass shutdown) can overflow the queue.

### C. Key name constraints
Creator Hub error codes document:
- Key name must not be empty (`KeyNameEmpty`).
- Key name length must be **≤ 50 characters** (`KeyNameLimit`).

### D. Value size constraints
Creator Hub notes that when using `SetAsync()` or `UpdateAsync()`:
- The **serialized value** can’t exceed the platform limit (the docs label this as “size X” and surface it via error `ValueTooLarge`).
- In practice, Roblox developers widely treat this as **~4 MB per key** (historically raised from 256 KB to 4 MB in 2020; still commonly cited and consistent with “ValueTooLarge” behavior).

**Best practice:**
- Keep player state compact; prefer IDs and small structs.
- Avoid storing large derived/duplicated data; recompute on load when possible.
- If approaching size limits, use **sharding** (split into multiple keys) or **compression/serialization**, but understand that sharding increases request count.

### E. Throughput rounding
Creator Hub notes:
- For throughput accounting, Roblox rounds each request up to the **next kilobyte**.

Practical implication:
- Many tiny writes still add up quickly; avoid frequent writes of small deltas.

### F. Versioning and retention (useful for rollback/migration)
From the **versioning** doc:
- `SetAsync`, `UpdateAsync`, `IncrementAsync` create versioned backups using the **first write to each key in each UTC hour**.
- Subsequent writes in the same UTC hour overwrite the previous state.
- Versioned backups expire **30 days after a new write overwrites them**.
- The **latest version never expires**.

**Best practice:**
- Treat DataStore versioning as a “safety net,” not a primary backup strategy.
- Before rolling out risky migrations, consider an **experience snapshot** (Open Cloud “Snapshot Data Stores” flow mentioned in docs).

---

## 2) Retry strategies for failed requests

### A. Always wrap calls in `pcall()`
Creator Hub recommends using `pcall()` to handle connectivity/platform failures.

### B. Use exponential backoff + jitter
A good general retry pattern for transient failures:
- Exponential backoff: `baseDelay * (2 ^ attempt)` or similar
- Add **jitter** (randomness) to avoid thundering herds across servers
- Cap the delay and total attempts

Example policy (typical):
- Attempts: 5–8
- Backoff: 0.5s, 1s, 2s, 4s, 8s (capped)
- Jitter: ±20–50%

### C. Avoid “naive retries” that reorder writes
Roblox’s **player-data-purchasing** doc calls out a key pitfall:
- If you retry failed writes independently, you can accidentally apply operations **out of order** (e.g., an earlier failed write retries later and overwrites a newer value).

Roblox recommends a per-key ordering approach:
- Queue operations **per key**
- Ensure that operations (and their retries) complete **in order**
- Yield the caller until the queued operation completes

This matters even with `UpdateAsync`:
- `UpdateAsync` reads latest value, but **the sequence of transformations must still be consistent** to avoid invalid intermediate states (e.g., subtracting currency before adding currency).

### D. Treat some failures as “unknown write state”
Creator Hub warns:
- A failed write response does **not always guarantee** the write didn’t occur.
- In some scenarios the final write state is **unknown** until verified by a follow-up read.

**Best practice:**
- For critical writes (purchases, irreversible progression), record an **idempotency token** (e.g., purchase receipt ID / transaction ID) in the stored data so replays don’t double-award.
- If a write fails after retries, consider reading back (possibly with cache-bypass techniques if available) to confirm state.

### E. Respect budgets to prevent self-inflicted throttling
- Use `GetRequestBudgetForRequestType` to avoid bursts.
- If budget is low, delay non-critical saves rather than spamming retries into a full queue.

---

## 3) Data migration patterns

Data migrations are inevitable as your saved schema evolves.

### A. Version your data explicitly
- Store a version field in each saved record:
  - e.g. `_dataVersion = 5`
- On load, detect old versions and migrate forward.

### B. Prefer “forward-only, incremental” migrations
- Apply migrations in steps: v1→v2→v3...
- Keep migrations **deterministic** and **idempotent**.

### C. Merge defaults after migrations
- After applying migrations, ensure any new fields exist by merging in a default template.

### D. Migrate on read (lazy migration)
Common pattern:
1. Load saved data.
2. If version < current:
   - Transform in memory.
   - Mark version updated.
3. Save back at the next safe save point.

Pros:
- No expensive “migrate everyone” job.
- Only active players are migrated.

Cons:
- Old schema lives longer for inactive players.

### E. Migration safety with backups/snapshots
- Use DataStore **versioning** as rollback support.
- For major changes, take an **experience snapshot** prior to release when possible.

### F. Sharding strategy for future growth
If player data risks exceeding per-key size limits, plan sharding early:
- `Player_<id>:core` (currency, tier, timestamps)
- `Player_<id>:inventory` (items)
- `Player_<id>:plots` (owned plots)

Sharding reduces “one giant blob” risk but increases request volume—budget accordingly.

---

## 4) Session locking recommendations

### Why session locking matters
Roblox explicitly calls out session locking as a core concern:
- If a player’s data is loaded on multiple servers concurrently, you can get:
  - stale overwrites
  - duplication exploits
  - progress loss

This can happen due to:
- Player reconnecting quickly
- Teleports
- Roblox server migration edge cases
- Slow shutdown saving

### Common locking approaches

#### Option 1: MemoryStore-based lock (recommended when available)
Use `MemoryStoreService` as a cross-server ephemeral lock:
- Key: `lock:Player_<UserId>`
- Value: `{serverId, timestamp}`
- TTL: 60–180 seconds
- Acquire on join; renew periodically.
- Release on clean leave.

If lock acquisition fails:
- Wait and retry for a short window (e.g., up to 10–20 seconds), then decide:
  - allow with read-only mode, or
  - kick with a friendly “Data still loading, rejoin in a moment” message.

#### Option 2: DataStore lock field (fallback)
Store a lock field inside the player record:
- `{ lock = { jobId, time } }`
- On load, if lock is recent and jobId differs, treat as locked.

Downsides:
- Consumes DataStore ops to manage lock.
- Susceptible to stale locks if save fails.

### Additional best practices
- On load, if you detect lock held elsewhere, **do not proceed** to modify and save the same key.
- Use TTLs and renewal so crashes don’t lock forever.

---

## 5) Specific recommendations for DataTycoon’s current implementation

### Current implementation summary (from `Main.server.lua`)
DataTycoon currently:
- Uses `DataStoreService:GetDataStore("DataTycoon_v" .. DATASTORE_VERSION)`.
- Loads with `GetAsync` wrapped in `pcall` with **3 attempts** and exponential-ish wait (`1.5 ^ attempt`).
- Saves with `UpdateAsync(key, function() return value end)` (effectively a Set) wrapped in `pcall`, **no retries**.
- Keeps player state in-memory (`PlayerData[userId]`).
- Autosaves every **60s** for all players.
- Saves on `PlayerRemoving` and `BindToClose`.
- Includes a data migration block (v1→v5) and merges defaults.

This is already aligned with several platform best practices (in-memory session state, load-time migrations).

### Recommendations (actionable)

#### 5.1 Add ordered, per-player save queue (prevents out-of-order retries)
Problem:
- The current `dsSet()` does not retry and does not enforce ordering across concurrent save triggers:
  - autosave tick
  - PlayerRemoving
  - BindToClose
  - potential future purchase saves

If you add retries later without ordering, you risk **older saves overwriting newer saves**.

Recommendation:
- Implement a per-player key queue (like Roblox’s documented approach) so only one write per player runs at a time, and retries happen inside that queued op.

Minimal design:
- `SaveQueue[userId] = Promise/Coroutine chain`
- Enqueue saves; if a newer save is queued, collapse intermediate saves (“keep last”) for autosave.

#### 5.2 Add retries to saves, with jitter and budget-awareness
Problem:
- Writes can fail transiently; current save path logs once and returns.

Recommendation:
- Retry `UpdateAsync` 5–8 times with exponential backoff + jitter.
- Before retrying, check write budget; if near 0, delay instead of spamming.

Also note:
- Since `UpdateAsync` consumes both read/write budgets, heavy autosave can be more expensive than expected.

#### 5.3 Prefer `UpdateAsync` transformation semantics (merge) where it matters
Current code uses `UpdateAsync(function() return value end)` which overwrites.

Recommendation:
- When feasible, use `UpdateAsync` to merge server state into the latest stored state:
  - `return deepMerge(old or default, value)`

This protects against rare cases where:
- session locking fails (two servers), or
- last save is stale.

(Still: proper session locking is the real fix.)

#### 5.4 Introduce session locking before PvP/raids and purchases
DataTycoon’s roadmap mentions PvP raiding and monetization-like mechanics. These increase the cost of data loss/exploits.

Recommendation:
- Add MemoryStore-based session locks per user.
- On join, acquire lock; on leave, release.
- If lock can’t be acquired quickly, prevent play to avoid dupe/stale-write exploits.

#### 5.5 Reduce autosave burstiness
Current autosave loops over all players every 60 seconds and spawns a task per player.

Risk:
- Large servers can create synchronized bursts that hit queue limits (30) and budgets.

Recommendations:
- Add per-player randomized offset (jitter) so saves are staggered.
- Save only if dirty (data changed) since last save.
- Consider saving less frequently for stable players (e.g., 90–180s) while still saving on critical events.

#### 5.6 Track “dirty” state and last successful save time
Recommendation:
- Mark PlayerData dirty on any change (currency, plots, computers, house).
- Autosave only dirty players.
- Record `lastSaveAttempt` and `lastSaveSuccess` for diagnostics and throttling.

#### 5.7 Harden against “default data overwrite” failure mode
Roblox warns: fallback-to-default must not overwrite real data later.

Current risk scenario:
- `dsGet` fails and returns nil → game treats as new player and begins play.
- Later, a save succeeds and overwrites the real existing record with defaults + new progress.

Recommendation:
- If load fails due to DataStore outage, consider:
  - temporary kick with message “Data failed to load; please rejoin” (safest), or
  - allow play in a “no-save” session mode that never writes, and clearly inform player.

#### 5.8 Add a lightweight schema checksum / validation
Recommendation:
- Validate loaded data types (numbers/tables) before trusting it.
- If corrupt, restore from defaults and/or roll back to a prior version (manual tooling).

#### 5.9 Plan for future key organization
Roblox warns that legacy **scopes** are discouraged for new experiences; prefer prefixes/listing.

Current code uses a single store name per version and keys like `Player_<id>`.

Recommendation:
- Keep key prefixes consistent (`player:<userId>` style is also common).
- If you later add global state, don’t mix it with player keys without clear prefixes.

---

## Quick checklist (for DataTycoon)

- [ ] Add session locking (MemoryStore TTL lock) per user
- [ ] Implement ordered per-key save queue; retries happen inside queue
- [ ] Add save retries with exponential backoff + jitter
- [ ] Stagger autosaves and save only dirty players
- [ ] Avoid overwriting real data when load fails (kick or no-save mode)
- [ ] Keep migrations forward-only, deterministic; merge defaults
- [ ] Monitor throttling error codes (301–306) and experience-level throttles

