# DataTycoon RemoteEvents & RemoteFunctions API (v0.22)

This document describes every networked **RemoteEvent** and **RemoteFunction** created by the server and consumed by the client.

**Source of truth (code):**
- `src/ServerScriptService/Systems/Main.server.lua`
- `src/StarterPlayerScripts/Client/GameClient.client.lua`

## Location / Replication

All remotes are created under:

- `ReplicatedStorage/Events` *(Folder)*

The server constructs the full folder (and all children) **before** setting `Events.Parent = ReplicatedStorage`, so clients should receive the full set atomically.

```lua
-- Server
local Events = Instance.new("Folder")
Events.Name = "Events"
-- ...create remotes...
Events.Parent = ReplicatedStorage
```

```lua
-- Client
local Events = ReplicatedStorage:WaitForChild("Events", 20)
```

---

## Quick reference

### RemoteEvents

| Name | Direction | Arguments (in order) | Fired/Invoked by | Purpose |
|---|---|---|---|---|
| `ClaimDailyReward` | Client → Server | *(none)* | Client UI (Daily Reward button) | Request daily reward claim |
| `DailyRewardClaimed` | Server → Client | `reward:number`, `streak:number` | Server after successful claim | Confirm claim + provide reward/streak for UI |
| `Notification` | Server → Client | `msg:string`, `t:string` | Server (many actions) | Toast-style messages (`t` = `"success"`/`"error"`/`"info"`) |
| `DataUpdated` | Server → Client | `dataValue:number` | Server whenever player data changes | Backup sync for the Data display |
| `CollectOrb` | Client → Server | `orbPos:Vector3` | Client orb touch handler | Request orb collection (anti-cheat validated on server) |
| `OrbCollected` | Server → Client | `orbPos:Vector3`, `respawnTime:number` | Server after validated collection | Tell client which orb area to fade out + when to respawn visuals |
| `PurchasePlot` | Client → Server | `plotId:string` | Client “Buy Plot” button / `E` key | Request plot purchase |
| `PlotPurchased` | Server → Client *(broadcast)* | `plotId:string`, `ownerUserId:number`, `ownerName:string` | Server after successful purchase | Inform all clients that a plot is owned (UI/announcements) |
| `SellPlot` | Client → Server | `plotId:string` | (Not used by v0.22 client UI) | Request plot sale |
| `PlotSold` | Server → Client *(broadcast)* | `plotId:string` | Server after successful sale | Inform all clients plot is unowned |
| `PlaceComputer` | Client → Server | `plotId:string`, `tier:number` | Client shop “Computer” buy | Request computer placement on a plot |
| `ComputerPlaced` | Server → Client | `plotId:string`, `tier:number`, `name:string`, `dps:number` | Server after successful placement | Confirm placement + provide stats for UI feedback |
| `UpgradeHouse` | Client → Server | *(none)* | Client shop “House Upgrades” buy | Request house tier upgrade |
| `HouseUpgraded` | Server → Client | `tier:number`, `name:string` | Server after successful upgrade | Confirm upgrade + update UI |

### RemoteFunctions

| Name | Direction | Arguments | Returns | Called by | Purpose |
|---|---|---|---|---|---|
| `GetPlayerData` | Client → Server | *(none)* | `PlayerData:table` | Client Stats panel + shop logic | Fetch the player’s current server-side data snapshot |

---

## Detailed API

### `ClaimDailyReward` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `ClaimDailyReward:FireServer()`

**Arguments:** none

**Triggered by (client):** Clicking **🎁 Daily Reward** button.

**Server behavior:**
- Validates whether the player already claimed today (`LastDailyReward`).
- Updates streak (`DailyStreak`) and awards from `CONFIG.DAILY_REWARDS`.
- Calls `UpdateData(player)` which also fires `DataUpdated`.
- Fires `DailyRewardClaimed` back to the requesting client.
- Fires `Notification` back to the requesting client.

**Examples**

Client:
```lua
local claimEv = Events:WaitForChild("ClaimDailyReward")
claimEv:FireServer()
```

Server (handler):
```lua
ClaimDailyReward.OnServerEvent:Connect(function(player)
    -- computes reward + streak
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
end)
```

---

### `DailyRewardClaimed` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `DailyRewardClaimed:FireClient(player, reward, streak)`

**Arguments:**
1. `reward: number` — amount of Data awarded
2. `streak: number` — updated daily streak count

**Triggered by (server):** Successful daily reward claim.

**Client behavior:**
- Displays a local notification.
- Temporarily changes the daily button text to "✅ Claimed!".

**Examples**

Server:
```lua
DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
```

Client:
```lua
local claimedEv = Events:WaitForChild("DailyRewardClaimed")
claimedEv.OnClientEvent:Connect(function(reward, streak)
    print("Claimed", reward, "streak", streak)
end)
```

---

### `Notification` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `Notification:FireClient(player, msg, t)`

**Arguments:**
1. `msg: string` — user-facing message
2. `t: string` — message type, used by client for color mapping
   - expected values in current code: `"success"`, `"error"`, otherwise treated as info

**Triggered by (server):** Many gameplay actions, including:
- Offline bonus message (delayed after join)
- Daily reward results and errors
- Plot purchase/sale results
- Computer placement results
- House upgrade results

**Client behavior:** Shows queued fading text notifications.

**Examples**

Server:
```lua
Notification:FireClient(player, "Upgrade house for more plots!", "error")
```

Client:
```lua
local notifEv = Events:WaitForChild("Notification")
notifEv.OnClientEvent:Connect(function(msg, t)
    -- t == "success" | "error" | anything else
    print("NOTIF", t, msg)
end)
```

---

### `DataUpdated` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `DataUpdated:FireClient(player, dataValue)`

**Arguments:**
1. `dataValue: number` — current player Data balance

**Triggered by (server):** Any time `UpdateData(player)` is called, including:
- Passive income tick (every 1 second)
- Orb collection
- Plot purchase/sale
- Computer placement
- House upgrade
- Daily reward

**Client behavior:** Updates the top HUD “Data” label as a backup sync (in addition to leaderstats replication).

**Examples**

Server:
```lua
local function UpdateData(player)
    DataUpdated:FireClient(player, data.Data)
end
```

Client:
```lua
local dataUpdEv = Events:WaitForChild("DataUpdated")
dataUpdEv.OnClientEvent:Connect(function(dataValue)
    print("Data is now", dataValue)
end)
```

---

### `CollectOrb` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `CollectOrb:FireServer(orbPos)`

**Arguments:**
1. `orbPos: Vector3` — the position of the orb ring that was touched

**Triggered by (client):**
- A part named `"OrbRing"` in `workspace.DataOrbs` is touched by the local player.

**Server behavior (anti-cheat):**
- Requires `orbPos` to be a `Vector3`.
- Requires `workspace.DataOrbs` to exist (otherwise kicks).
- Finds nearest orb part to `orbPos` and rejects if too far (`> 5`).
- Rejects if player is too far from `orbPos` (`> 50`).
- Rate limits per-player (`~0.4s`).
- Awards `CONFIG.ORB_REWARD` Data, increments `BlocksCollected`.
- Calls `UpdateData(player)`.
- Fires `OrbCollected` back to the same client to drive visuals.

**Examples**

Client (touch hook):
```lua
local collectEv = Events:WaitForChild("CollectOrb")
ring.Touched:Connect(function(hit)
    collectEv:FireServer(ring.Position)
end)
```

Server:
```lua
CollectOrb.OnServerEvent:Connect(function(player, orbPos)
    -- validate + award
    OrbCollected:FireClient(player, orbPos, CONFIG.ORB_RESPAWN)
end)
```

---

### `OrbCollected` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `OrbCollected:FireClient(player, orbPos, respawnTime)`

**Arguments:**
1. `orbPos: Vector3` — position the server accepted as collected
2. `respawnTime: number` — seconds until the client should restore orb visuals (`CONFIG.ORB_RESPAWN`)

**Triggered by (server):** After the server validates and processes an orb collection.

**Client behavior:**
- Searches `workspace.DataOrbs` for parts within 12 studs of `orbPos`.
- Immediately hides them (`Transparency = 1`, `CanCollide = false`).
- After `respawnTime`, restores original transparency; sets `CanCollide` only for parts named `"OrbRing"`.

**Examples**

Server:
```lua
OrbCollected:FireClient(player, orbPos, CONFIG.ORB_RESPAWN)
```

Client:
```lua
local orbCollected = Events:WaitForChild("OrbCollected")
orbCollected.OnClientEvent:Connect(function(orbPos, respawnTime)
    print("Orb collected at", orbPos, "respawn in", respawnTime)
end)
```

---

### `PurchasePlot` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `PurchasePlot:FireServer(plotId)`

**Arguments:**
1. `plotId: string` — e.g. `"plot_0_3"`

**Triggered by (client):**
- Clicking **📦 Buy Plot [E]** button
- Pressing the `E` key (cycles through a predefined plot order)

**Server behavior:**
- Validates `plotId` is a string and exists.
- Ensures plot is unowned.
- Ensures the player has house capacity for additional plots.
- Ensures the player can afford `plot.price`.
- Deducts Data, records ownership, inserts `plotId` into `data.Plots`.
- Calls `UpdateData(player)`.
- Broadcasts `PlotPurchased` to all clients.
- Sends `Notification` to purchaser.

**Examples**

Client:
```lua
local buyPlotEv = Events:WaitForChild("PurchasePlot")
buyPlotEv:FireServer("plot_0_3")
```

Server:
```lua
PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
end)
```

---

### `PlotPurchased` (RemoteEvent)

**Direction:** Server → Client (broadcast to all clients)

**Server fire:** `PlotPurchased:FireAllClients(plotId, ownerUserId, ownerName)`

**Arguments:**
1. `plotId: string`
2. `ownerUserId: number`
3. `ownerName: string`

**Triggered by (server):** Successful plot purchase.

**Client behavior:**
- If someone else bought a plot, shows a local notification: `"<name> bought a plot!"`.

**Examples**

Server:
```lua
PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
```

Client:
```lua
local plotPurchEv = Events:WaitForChild("PlotPurchased")
plotPurchEv.OnClientEvent:Connect(function(pid, uid, uname)
    if uid ~= Players.LocalPlayer.UserId then
        print(uname .. " purchased " .. pid)
    end
end)
```

---

### `SellPlot` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `SellPlot:FireServer(plotId)`

**Arguments:**
1. `plotId: string`

**Triggered by:**
- Not wired in the v0.22 client UI, but available for future UI/buttons.

**Server behavior:**
- Validates ownership (must be owned by requesting player).
- Computes sell price `floor(plot.price * 0.5)`.
- Clears plot ownership and any computers on the plot.
- Removes plot from `data.Plots` and computers from `data.Computers`.
- Calls `UpdateData(player)`.
- Broadcasts `PlotSold` to all clients.
- Sends `Notification` to seller.

**Examples**

Client (hypothetical button):
```lua
local sellPlotEv = Events:WaitForChild("SellPlot")
sellPlotEv:FireServer("plot_0_3")
```

Server:
```lua
SellPlot.OnServerEvent:Connect(function(player, plotId)
    PlotSold:FireAllClients(plotId)
end)
```

---

### `PlotSold` (RemoteEvent)

**Direction:** Server → Client (broadcast to all clients)

**Server fire:** `PlotSold:FireAllClients(plotId)`

**Arguments:**
1. `plotId: string`

**Triggered by (server):** Successful plot sale.

**Client behavior:**
- Not consumed by the v0.22 client script.
- Intended for plot-ownership visuals / UI refresh.

**Examples**

Server:
```lua
PlotSold:FireAllClients(plotId)
```

Client (example hook):
```lua
local plotSoldEv = Events:WaitForChild("PlotSold")
plotSoldEv.OnClientEvent:Connect(function(plotId)
    print("Plot is now for sale:", plotId)
end)
```

---

### `PlaceComputer` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `PlaceComputer:FireServer(plotId, tier)`

**Arguments:**
1. `plotId: string` — must be owned by the player
2. `tier: number` — clamped on server to `1..#CONFIG.COMPUTER_TIERS`

**Triggered by (client):** Clicking a computer tier in the Shop panel.
- The current client implementation places on the **first owned plot** (`data.Plots[1]`).

**Server behavior:**
- Validates plot ownership.
- Clamps tier into valid range.
- Ensures house computer capacity.
- Ensures the player can afford tier cost.
- Deducts Data, adds computer record to `data.Computers` and `plot.computers`.
- Calls `UpdateData(player)`.
- Fires `ComputerPlaced` back to the same client.
- Sends `Notification`.

**Examples**

Client:
```lua
local placeCompEv = Events:WaitForChild("PlaceComputer")
placeCompEv:FireServer("plot_0_3", 2)
```

Server:
```lua
PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    ComputerPlaced:FireClient(player, plotId, tier, ct.name, ct.dps)
end)
```

---

### `ComputerPlaced` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `ComputerPlaced:FireClient(player, plotId, tier, name, dps)`

**Arguments:**
1. `plotId: string`
2. `tier: number`
3. `name: string` — tier name
4. `dps: number` — passive Data per second contributed by the computer tier

**Triggered by (server):** Successful placement of a computer.

**Client behavior:** Shows a notification: `"<name> online! +<dps>/s"`.

**Examples**

Server:
```lua
ComputerPlaced:FireClient(player, plotId, tier, ct.name, ct.dps)
```

Client:
```lua
local compPlacEv = Events:WaitForChild("ComputerPlaced")
compPlacEv.OnClientEvent:Connect(function(pid, tier, name, dps)
    print("Placed", name, "tier", tier, "on", pid, "dps", dps)
end)
```

---

### `UpgradeHouse` (RemoteEvent)

**Direction:** Client → Server

**Client call:** `UpgradeHouse:FireServer()`

**Arguments:** none

**Triggered by (client):** Clicking a house upgrade item in the Shop panel.

**Server behavior:**
- Computes next tier; rejects if already max.
- Validates affordability.
- Deducts cost, increments `HouseTier`.
- Updates `leaderstats.House` value.
- Calls `UpdateData(player)`.
- Fires `HouseUpgraded` back to the same client.
- Sends `Notification`.

**Examples**

Client:
```lua
local upgradeEv = Events:WaitForChild("UpgradeHouse")
upgradeEv:FireServer()
```

Server:
```lua
UpgradeHouse.OnServerEvent:Connect(function(player)
    HouseUpgraded:FireClient(player, nt, CONFIG.HOUSE_TIERS[nt].name)
end)
```

---

### `HouseUpgraded` (RemoteEvent)

**Direction:** Server → Client

**Server fire:** `HouseUpgraded:FireClient(player, tier, name)`

**Arguments:**
1. `tier: number` — new tier index
2. `name: string` — new tier display name

**Triggered by (server):** Successful house upgrade.

**Client behavior:** Updates HUD house label.

**Examples**

Server:
```lua
HouseUpgraded:FireClient(player, nt, CONFIG.HOUSE_TIERS[nt].name)
```

Client:
```lua
local houseUpgEv = Events:WaitForChild("HouseUpgraded")
houseUpgEv.OnClientEvent:Connect(function(tier, name)
    print("House upgraded to", tier, name)
end)
```

---

## RemoteFunction: `GetPlayerData`

### `GetPlayerData` (RemoteFunction)

**Direction:** Client → Server (synchronous request/response)

**Client call:** `local data = GetPlayerData:InvokeServer()`

**Arguments:** none

**Returns:**
- `PlayerData: table` — the server’s in-memory data table for this player, including (current fields):
  - `Data: number`
  - `TotalEarned: number`
  - `TotalSpent: number`
  - `Plots: {string}`
  - `Computers: { { tier:number, plotId:string, name:string, dps:number } }`
  - `HouseTier: number`
  - `DailyStreak: number`
  - `LastDailyReward: number` (unix time)
  - `BlocksCollected: number`
  - `LastSeen: number` (unix time)
  - plus internal `_dataVersion`

**Triggered by (client):**
- Opening Stats panel (refresh)
- Periodic refresh while Stats panel is open (every 5s)
- Shop “buy computer” flow to locate a target plot (`data.Plots[1]`)

**Server behavior:** Returns `PlayerData[player.UserId]`.

**Examples**

Server:
```lua
GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end
```

Client:
```lua
local getDataFn = Events:WaitForChild("GetPlayerData")
local ok, data = pcall(function()
    return getDataFn:InvokeServer()
end)
if ok and data then
    print("You own", #(data.Plots or {}), "plots")
end
```

---

## Notes / Caveats

- **`PlotSold` and `SellPlot` exist server-side** but are **not currently used** by `GameClient.client.lua`.
- `GetPlayerData` is created via the same helper as events (`MakeEvent`) but with class `"RemoteFunction"`.
- The server performs significant validation for `CollectOrb`; clients should treat `OrbCollected` as the authoritative confirmation.
