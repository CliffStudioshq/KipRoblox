--[[
    Main.server.lua — DataTycoon v0.22
    Key changes from v0.21:
      - Early static baseplate Part (safety net before terrain loads)
      - OrbCollected RemoteEvent so client can animate orb disappear/respawn
      - All previous fixes retained
]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

-- Bridge builder lives in WorldBuilder.server.lua (global functions)

local DATASTORE_VERSION = 5

print(("="):rep(50))
print("DataTycoon v0.22 — Server starting...")
print(("="):rep(50))

-- ============================================================
-- EARLY BASEPLATE — exists before any yields so players never fall
-- ============================================================
do
    local base = Instance.new("Part")
    base.Name        = "EarlyBase"
    base.Size        = Vector3.new(600, 4, 600)
    base.Position    = Vector3.new(0, -2, 0)
    base.Anchored    = true
    base.CanCollide  = true
    base.Transparency = 1   -- invisible; terrain paints over it visually
    base.Parent      = workspace

    local sp = Instance.new("SpawnLocation")
    sp.Size        = Vector3.new(10, 1, 10)
    sp.Position    = Vector3.new(0, 3, 0)
    sp.Anchored    = true
    sp.CanCollide  = false
    sp.Transparency = 1
    sp.Neutral     = true
    sp.Parent      = workspace
end

-- ============================================================
-- DATASTORE — pcall so failure never kills Events creation
-- ============================================================
local DataStore = nil
local dsOk, dsErr = pcall(function()
    DataStore = DataStoreService:GetDataStore("DataTycoon_v" .. DATASTORE_VERSION)
end)
if not dsOk then
    warn("[DATA] DataStore unavailable: " .. tostring(dsErr))
    warn("[DATA] Enable API Services in Game Settings > Security")
end

-- ============================================================
-- REMOTE EVENTS
-- Build ALL children before parenting to ReplicatedStorage
-- so the entire folder replicates atomically (no partial state)
-- ============================================================
local Events = Instance.new("Folder")
Events.Name = "Events"   -- parent set LAST, below

local function MakeEvent(name, cls)
    local e = Instance.new(cls or "RemoteEvent")
    e.Name   = name
    e.Parent = Events
    return e
end

local ClaimDailyReward  = MakeEvent("ClaimDailyReward")
local CollectOrb        = MakeEvent("CollectOrb")
local PurchasePlot      = MakeEvent("PurchasePlot")
local SellPlot          = MakeEvent("SellPlot")
local PlaceComputer     = MakeEvent("PlaceComputer")
local UpgradeHouse      = MakeEvent("UpgradeHouse")
local DailyRewardClaimed = MakeEvent("DailyRewardClaimed")
local Notification      = MakeEvent("Notification")
local DataUpdated       = MakeEvent("DataUpdated")
local PlotPurchased     = MakeEvent("PlotPurchased")
local PlotSold          = MakeEvent("PlotSold")
local BridgeBuilt       = MakeEvent("BridgeBuilt")
local BridgeRemoved     = MakeEvent("BridgeRemoved")
local ComputerPlaced    = MakeEvent("ComputerPlaced")
local HouseUpgraded     = MakeEvent("HouseUpgraded")
local OrbCollected      = MakeEvent("OrbCollected")   -- fires orb position back so client can animate
local OrbStateChanged   = MakeEvent("OrbStateChanged") -- server authoritative orb availability
local GetPlayerData     = MakeEvent("GetPlayerData", "RemoteFunction")

-- NOW parent — entire subtree replicates as one atomic snapshot
Events.Parent = ReplicatedStorage
print("[OK] RemoteEvents replicated")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    STARTING_DATA  = 50,
    ORB_REWARD     = 5,
    PASSIVE_INCOME = 1,

    COMPUTER_TIERS = {
        {name = "Budget Rig",    cost = 100,   dps = 2},
        {name = "Gaming PC",     cost = 500,   dps = 8},
        {name = "Server Rack",   cost = 2500,  dps = 30},
        {name = "Supercomputer", cost = 10000, dps = 120},
    },

    HOUSE_TIERS = {
        {name = "Shack",         cost = 0,     maxComputers = 1,  maxPlots = 2},
        {name = "Small House",   cost = 300,   maxComputers = 2,  maxPlots = 4},
        {name = "Modern House",  cost = 1500,  maxComputers = 4,  maxPlots = 8},
        {name = "Tech Villa",    cost = 8000,  maxComputers = 8,  maxPlots = 8},
        {name = "Mega Compound", cost = 30000, maxComputers = 16, maxPlots = 8},
    },

    DAILY_REWARDS  = {50, 75, 100, 150, 200, 300, 500},
    ORB_RESPAWN    = 30,  -- seconds before orb visually respawns on client
}

-- ============================================================
-- ORB REGISTRY / STATE (server authoritative)
-- ============================================================
local OrbRegistry = {}  -- orbId -> BasePart (OrbRing)
local OrbState = {}     -- orbId -> {available = bool, cooldownUntil = timestamp}

local function RegisterOrbs()
    local dataOrbsFolder = workspace:FindFirstChild("DataOrbs")
    if not dataOrbsFolder then
        warn("[ORB] workspace.DataOrbs missing; orb registry not initialized")
        return
    end

    local n = 0
    for _, inst in ipairs(dataOrbsFolder:GetChildren()) do
        if inst:IsA("BasePart") and inst.Name:match("^OrbRing_") then
            local orbId = inst.Name
            OrbRegistry[orbId] = inst
            OrbState[orbId] = {available = true, cooldownUntil = 0}
            n = n + 1
        end
    end
    print("[ORB] Registered " .. n .. " orbs")
end

task.spawn(function()
    -- allow WorldBuilder to create DataOrbs
    task.wait(1)
    RegisterOrbs()
end)

-- ============================================================
-- PLAYER DATA
-- ============================================================
local PlayerData = {}

-- Offline income cooldowns: UserId -> last award timestamp
local OfflineIncomeCooldowns = {}
local OFFLINE_INCOME_MIN_TIME = 60      -- minimum seconds offline to qualify
local OFFLINE_INCOME_COOLDOWN  = 300     -- 5 minutes between awards

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    TotalSpent  = 0,
    Plots       = {},
    Computers   = {},
    HouseTier   = 1,
    DailyStreak = 0,
    LastDailyReward = 0,
    BlocksCollected = 0,
    LastSeen    = 0,
}

local function defaultData()
    local d = {}
    for k, v in pairs(DEFAULT_DATA) do
        d[k] = type(v) == "table" and {} or v
    end
    return d
end

local function dsGet(key)
    if not DataStore then return nil end
    for attempt = 1, 3 do
        local ok, result = pcall(function() return DataStore:GetAsync(key) end)
        if ok then return result end
        warn("[DATA] GetAsync attempt "..attempt.." failed: "..tostring(result))
        task.wait(1.5 ^ attempt)
    end
    return nil
end

local function dsSet(key, value)
    if not DataStore then return false end
    local ok, err = pcall(function()
        DataStore:UpdateAsync(key, function() return value end)
    end)
    if not ok then warn("[DATA] Save failed: "..tostring(err)) end
    return ok
end

-- ============================================================
-- PLOTS
-- ============================================================
local Plots = {}

local function InitPlots()
    local coords = {{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
    for _, c in ipairs(coords) do
        local x, z  = c[1], c[2]
        local plotId = "plot_"..x.."_"..z
        Plots[plotId] = {
            id        = plotId,
            owner     = nil,
            ownerName = nil,
            x = x, z = z,
            dist      = math.max(math.abs(x), math.abs(z)),
            price     = math.floor(50 * (2 ^ math.max(math.abs(x), math.abs(z)))),
            center    = Vector3.new(x*170, 0.5, z*170),
            computers = {},
        }
    end
    local n=0; for _ in pairs(Plots) do n=n+1 end
    print("[OK] "..n.." plots initialized")
end

-- ============================================================
-- LOAD / SAVE
-- ============================================================
local function LoadPlayerData(player)
    local key   = "Player_"..player.UserId
    local saved = dsGet(key)
    local data

    if saved then
        -- ========================================================
        -- DATA MIGRATIONS
        -- ========================================================
        local oldVersion = saved._dataVersion or saved.DataVersion
        if oldVersion == nil then oldVersion = 1 end

        if oldVersion < DATASTORE_VERSION then
            local v = oldVersion

            -- v1 -> v2: Cash -> Data
            if v < 2 then
                if saved.Cash ~= nil and saved.Data == nil then
                    saved.Data = saved.Cash
                end
                saved.Cash = nil
                v = 2
            end

            -- v2 -> v3: PlotCount -> ensure Plots table exists
            if v < 3 then
                if saved.PlotCount ~= nil then
                    saved.Plots = saved.Plots or {}
                end
                v = 3
            end

            -- v3 -> v4: LastLogin -> LastSeen
            if v < 4 then
                if saved.LastLogin ~= nil and saved.LastSeen == nil then
                    saved.LastSeen = saved.LastLogin
                end
                saved.LastLogin = nil
                v = 4
            end

            -- v4 -> v5: defaults ensured by merge below
            if v < 5 then
                v = 5
            end

            saved._dataVersion = DATASTORE_VERSION
            print("[DATA] Migrated "..player.Name.." from v"..tostring(oldVersion).." to v"..tostring(DATASTORE_VERSION))
        end

        -- Ensure any new default fields exist
        for k, v in pairs(DEFAULT_DATA) do
            if saved[k] == nil then saved[k] = type(v)=="table" and {} or v end
        end
        data = saved
        print("[DATA] Loaded "..player.Name.." Data="..data.Data)
    else
        data = defaultData()
        print("[DATA] New player: "..player.Name)
    end

    -- Offline income (capped at 2 hours)
    local now = os.time()
    if data.LastSeen and data.LastSeen > 0 then
        local elapsed = math.min(now - data.LastSeen, 7200)

        if elapsed < OFFLINE_INCOME_MIN_TIME then
            print(string.format("[DATA] Offline bonus skipped for %s: only %ds offline (<%ds)", player.Name, elapsed, OFFLINE_INCOME_MIN_TIME))
        else
            local lastAward = OfflineIncomeCooldowns[player.UserId]
            if lastAward and (now - lastAward) < OFFLINE_INCOME_COOLDOWN then
                print(string.format("[DATA] Offline bonus skipped for %s: cooldown %ds remaining", player.Name, OFFLINE_INCOME_COOLDOWN - (now - lastAward)))
            else
                local offDPS  = CONFIG.PASSIVE_INCOME
                for _, comp in ipairs(data.Computers or {}) do
                    local ct = CONFIG.COMPUTER_TIERS[comp.tier]
                    if ct then offDPS = offDPS + ct.dps end
                end

                local bonus = math.floor(elapsed * offDPS * 0.5)
                if bonus > 0 then
                    data.Data        = data.Data + bonus
                    data.TotalEarned = data.TotalEarned + bonus
                    OfflineIncomeCooldowns[player.UserId] = now

                    -- Notify after client connects (give it 4s to set up)
                    task.delay(4, function()
                        if player.Parent then
                            Notification:FireClient(player,
                                "Welcome back! +"..bonus.." Data offline 💤", "success")
                        end
                    end)
                    print("[DATA] Offline bonus for "..player.Name..": +"..bonus)
                end
            end
        end
    end
    data.LastSeen = now
    PlayerData[player.UserId] = data

    -- Build leaderstats — ALL children added before parenting (atomic replication)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"

    local dv = Instance.new("IntValue")
    dv.Name = "Data"; dv.Value = data.Data; dv.Parent = ls

    local hv = Instance.new("IntValue")
    hv.Name = "House"; hv.Value = data.HouseTier; hv.Parent = ls

    ls.Parent = player   -- atomic: client gets complete folder in one replication
    print("[OK] leaderstats created for "..player.Name)
end

local function SavePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    data.LastSeen = os.time()
    data._dataVersion = DATASTORE_VERSION
    dsSet("Player_"..player.UserId, data)
end

-- Some saved data fields may be missing or nil; using # on nil will error.
local function safeLen(t)
    return (type(t) == "table") and #t or 0
end

local function UpdateData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local dv = ls:FindFirstChild("Data")
        if dv then dv.Value = data.Data end
    end
    DataUpdated:FireClient(player, data.Data)
end

local function Notify(player, msg, t)
    Notification:FireClient(player, msg, t or "info")
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]; if not data then return end
    local now   = os.time()
    local since = math.floor((now - (data.LastDailyReward or 0)) / 86400)
    if since == 0 then Notify(player, "Already claimed today!", "error"); return end
    if since > 1 then data.DailyStreak = 1
    else data.DailyStreak = (data.DailyStreak or 0) + 1 end
    local idx    = ((data.DailyStreak-1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[idx]
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day "..data.DailyStreak..": +"..reward.." Data! 🎉", "success")
end)

local orbCooldowns = {}
CollectOrb.OnServerEvent:Connect(function(player, orbId)
    -- Server-side validation (anti-cheat): ensure orb is real and near the player
    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if type(orbId) ~= "string" then return end

    -- (1) Verify orb exists in workspace.DataOrbs and is a known OrbRing_* instance
    local dataOrbsFolder = workspace:FindFirstChild("DataOrbs")
    if not dataOrbsFolder then
        warn("[ANTI-CHEAT] DataOrbs folder missing; denying orb collection for " .. player.Name)
        return
    end

    local orbPart = OrbRegistry[orbId]
    if not (orbPart and orbPart.Parent == dataOrbsFolder) then
        -- Attempt lazy re-register (WorldBuilder might have rebuilt)
        RegisterOrbs()
        orbPart = OrbRegistry[orbId]
    end

    if not (orbPart and orbPart.Parent == dataOrbsFolder) then
        warn(string.format("[ANTI-CHEAT] %s attempted orb collection for invalid orbId=%s", player.Name, tostring(orbId)))
        return
    end

    local state = OrbState[orbId]
    if not state then
        state = {available = true, cooldownUntil = 0}
        OrbState[orbId] = state
    end

    local nowT = os.clock()
    if (not state.available) and nowT < (state.cooldownUntil or 0) then
        return
    end

    local orbPos = orbPart.Position
    local distance = (hrp.Position - orbPos).Magnitude
    if distance > 50 then
        warn("[ANTI-CHEAT] " .. player.Name .. " attempted orb collection at distance " .. distance)
        return
    end

    local now = tick()
    if orbCooldowns[player.UserId] and (now - orbCooldowns[player.UserId]) < 0.4 then return end
    orbCooldowns[player.UserId] = now

    -- Mark orb unavailable
    state.available = false
    state.cooldownUntil = nowT + CONFIG.ORB_RESPAWN
    OrbStateChanged:FireAllClients(orbId, false)

    print("[ORB] " .. player.Name .. " collected " .. orbId)

    local data = PlayerData[player.UserId]; if not data then return end
    data.Data = data.Data + CONFIG.ORB_REWARD
    data.TotalEarned = data.TotalEarned + CONFIG.ORB_REWARD
    data.BlocksCollected = (data.BlocksCollected or 0) + 1
    UpdateData(player)

    -- keep existing client feedback event
    OrbCollected:FireClient(player, orbPos, CONFIG.ORB_RESPAWN)

    task.delay(CONFIG.ORB_RESPAWN, function()
        local st = OrbState[orbId]
        if not st then return end
        st.available = true
        st.cooldownUntil = 0
        OrbStateChanged:FireAllClients(orbId, true)
        print("[ORB] Orb " .. orbId .. " now available")
    end)
end)

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot then Notify(player, "Plot not found!", "error"); return end
    if plot.owner then Notify(player, "Plot is owned!", "error"); return end
    local data = PlayerData[player.UserId]; if not data then return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if safeLen(data.Plots) >= ht.maxPlots then Notify(player, "Upgrade house for more plots!", "error"); return end
    if data.Data < plot.price then Notify(player, "Need "..plot.price.." Data!", "error"); return end
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId; plot.ownerName = player.Name
    table.insert(data.Plots, plotId)
    UpdateData(player)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
    if typeof(BuildBridge) == "function" then
        BuildBridge(plotId, player.Name, player.UserId)
    else
        warn("[BRIDGE] BuildBridge function missing (WorldBuilder not loaded?)")
    end
    BridgeBuilt:FireAllClients(plotId, player.Name, player.UserId)
    Notify(player, "Plot "..plotId.." purchased!", "success")
    print("[GAME] "..player.Name.." bought "..plotId)
end)

SellPlot.OnServerEvent:Connect(function(player, plotId)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error"); return end
    local data = PlayerData[player.UserId]; if not data then return end

    if typeof(RemoveBridge) == "function" then
        RemoveBridge(plotId)
    else
        warn("[BRIDGE] RemoveBridge function missing (WorldBuilder not loaded?)")
    end
    BridgeRemoved:FireAllClients(plotId)

    local sp = math.floor(plot.price * 0.5)
    data.Data = data.Data + sp; data.TotalEarned = data.TotalEarned + sp
    plot.owner = nil; plot.ownerName = nil
    for i=#data.Plots,1,-1 do if data.Plots[i]==plotId then table.remove(data.Plots,i); break end end
    for i=#data.Computers,1,-1 do if data.Computers[i].plotId==plotId then table.remove(data.Computers,i) end end
    plot.computers = {}
    UpdateData(player)
    PlotSold:FireAllClients(plotId)
    Notify(player, "Sold for "..sp.." Data!", "success")
end)

PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error"); return end
    local data = PlayerData[player.UserId]; if not data then return end
    tier = math.clamp(math.floor(tonumber(tier) or 1), 1, #CONFIG.COMPUTER_TIERS)
    local ct = CONFIG.COMPUTER_TIERS[tier]
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if safeLen(data.Computers) >= ht.maxComputers then Notify(player, "Upgrade house first!", "error"); return end
    if data.Data < ct.cost then Notify(player, "Need "..ct.cost.." Data!", "error"); return end
    data.Data = data.Data - ct.cost; data.TotalSpent = data.TotalSpent + ct.cost
    local comp = {tier=tier, plotId=plotId, name=ct.name, dps=ct.dps}
    table.insert(data.Computers, comp); table.insert(plot.computers, comp)
    UpdateData(player)
    ComputerPlaced:FireClient(player, plotId, tier, ct.name, ct.dps)
    Notify(player, ct.name.." placed! (+"..ct.dps.."/s)", "success")
    print("[GAME] "..player.Name.." placed "..ct.name)
end)

UpgradeHouse.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]; if not data then return end
    local nt = data.HouseTier + 1
    if nt > #CONFIG.HOUSE_TIERS then Notify(player, "Already max!", "error"); return end
    local cost = CONFIG.HOUSE_TIERS[nt].cost
    if data.Data < cost then Notify(player, "Need "..cost.." Data!", "error"); return end
    data.Data = data.Data - cost; data.TotalSpent = data.TotalSpent + cost
    data.HouseTier = nt
    local ls = player:FindFirstChild("leaderstats")
    if ls then local hv=ls:FindFirstChild("House"); if hv then hv.Value=nt end end
    UpdateData(player)
    HouseUpgraded:FireClient(player, nt, CONFIG.HOUSE_TIERS[nt].name)
    Notify(player, "Upgraded to "..CONFIG.HOUSE_TIERS[nt].name.."! 🏠", "success")
end)

GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

print("[OK] All event handlers connected")

-- ============================================================
-- PASSIVE INCOME (every 1s, in-memory only)
-- ============================================================
task.spawn(function()
    print("[OK] Passive income loop running")
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                local dps = CONFIG.PASSIVE_INCOME
                for _, comp in ipairs(data.Computers or {}) do
                    local ct = CONFIG.COMPUTER_TIERS[comp.tier]
                    if ct then dps = dps + ct.dps end
                end
                data.Data        = data.Data + dps
                data.TotalEarned = data.TotalEarned + dps
                UpdateData(p)
            end
        end
    end
end)

-- ============================================================
-- AUTOSAVE every 60s
-- ============================================================
task.spawn(function()
    while true do
        task.wait(60)
        for _, p in ipairs(Players:GetPlayers()) do
            task.spawn(SavePlayerData, p)
        end
        print("[DATA] Autosave complete")
    end
end)

-- ============================================================
-- PLAYER CONNECTIONS
-- ============================================================
local function onPlayerAdded(player)
    print("[JOIN] "..player.Name)
    task.spawn(LoadPlayerData, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Backfill: handles Studio local test where player joins before script connects
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
    print("[LEAVE] "..player.Name)
    task.spawn(SavePlayerData, player)
    task.delay(5, function()
        PlayerData[player.UserId]   = nil
        orbCooldowns[player.UserId] = nil
    end)
end)

game:BindToClose(function()
    print("[DATA] Closing — saving all players...")
    for _, p in ipairs(Players:GetPlayers()) do SavePlayerData(p) end
    print("[DATA] All saved.")
end)

InitPlots()
print(("="):rep(50))
print("DataTycoon v0.22 — SERVER READY")
print(("="):rep(50))
