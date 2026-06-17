--[[
    Main.server.lua — DataTycoon v0.21
    Fixes:
      - DataStore wrapped in pcall (was crashing entire script before Events created)
      - Leaderstats folder parented LAST (fixes partial replication / ERR on client)
      - GetPlayers() backfill after PlayerAdded (fixes Studio race condition)
      - Retry logic on DataStore load
      - Autosave every 60s
      - UpdateAsync instead of SetAsync
]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

print("=":rep(50))
print("DataTycoon v0.21 — Server starting...")
print("=":rep(50))

-- ============================================================
-- DATASTORE — wrapped in pcall so a failure doesn't kill the
-- entire script before Events gets created
-- ============================================================
local DataStore = nil
local dsOk, dsErr = pcall(function()
    DataStore = DataStoreService:GetDataStore("DataTycoon_v4")
end)
if not dsOk then
    warn("[DATA] DataStore unavailable: " .. tostring(dsErr))
    warn("[DATA] Game will run but progress won't save. Enable API Services in Game Settings.")
end

-- ============================================================
-- CREATE REMOTE EVENTS (must happen early so client can find them)
-- ============================================================
local Events = Instance.new("Folder")
Events.Name = "Events"

local function MakeEvent(name, cls)
    local e = Instance.new(cls or "RemoteEvent")
    e.Name = name
    e.Parent = Events
    return e
end

-- Client → Server
local ClaimDailyReward = MakeEvent("ClaimDailyReward")
local CollectOrb       = MakeEvent("CollectOrb")
local PurchasePlot     = MakeEvent("PurchasePlot")
local SellPlot         = MakeEvent("SellPlot")
local PlaceComputer    = MakeEvent("PlaceComputer")
local UpgradeHouse     = MakeEvent("UpgradeHouse")

-- Server → Client
local DailyRewardClaimed = MakeEvent("DailyRewardClaimed")
local Notification       = MakeEvent("Notification")
local DataUpdated        = MakeEvent("DataUpdated")
local PlotPurchased      = MakeEvent("PlotPurchased")
local PlotSold           = MakeEvent("PlotSold")
local ComputerPlaced     = MakeEvent("ComputerPlaced")
local HouseUpgraded      = MakeEvent("HouseUpgraded")

-- Remote Function (client→server only — safe direction)
local GetPlayerData = MakeEvent("GetPlayerData", "RemoteFunction")

-- Parent AFTER all children exist so client never finds an incomplete folder
Events.Parent = ReplicatedStorage
print("[OK] RemoteEvents created and replicated")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    STARTING_DATA  = 50,
    ORB_REWARD     = 5,
    PASSIVE_INCOME = 1,  -- base data/sec

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

    DAILY_REWARDS = {50, 75, 100, 150, 200, 300, 500},
}

-- ============================================================
-- PLAYER DATA
-- ============================================================
local PlayerData = {}

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    TotalSpent = 0,
    Plots = {},
    Computers = {},
    HouseTier = 1,
    LastLogin = 0,
    DailyStreak = 0,
    LastDailyReward = 0,
    BlocksCollected = 0,
    LastSeen = 0,
}

-- Deep copy defaults
local function defaultData()
    local d = {}
    for k, v in pairs(DEFAULT_DATA) do
        if type(v) == "table" then
            d[k] = {}
        else
            d[k] = v
        end
    end
    return d
end

-- Retry wrapper for DataStore
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
    for attempt = 1, 3 do
        local ok, err = pcall(function()
            DataStore:UpdateAsync(key, function() return value end)
        end)
        if ok then return true end
        warn("[DATA] UpdateAsync attempt "..attempt.." failed: "..tostring(err))
        task.wait(1.5 ^ attempt)
    end
    return false
end

-- ============================================================
-- PLOT SYSTEM
-- ============================================================
local Plots = {}

local function InitPlots()
    local coords = {{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
    for _, c in ipairs(coords) do
        local x, z   = c[1], c[2]
        local dist   = math.max(math.abs(x), math.abs(z))
        local plotId = "plot_"..x.."_"..z
        local price  = math.floor(50 * (2 ^ dist))
        Plots[plotId] = {
            id = plotId, owner = nil, ownerName = nil,
            x = x, z = z, dist = dist, price = price,
            center = Vector3.new(x * 170, 0.5, z * 170),
            computers = {},
        }
    end
    local n = 0; for _ in pairs(Plots) do n = n + 1 end
    print("[OK] "..n.." plots initialized")
end

-- ============================================================
-- DATA FUNCTIONS
-- ============================================================
local function LoadPlayerData(player)
    local key     = "Player_"..player.UserId
    local saved   = dsGet(key)
    local data

    if saved then
        -- Merge: add any new fields that didn't exist in older saves
        for k, v in pairs(DEFAULT_DATA) do
            if saved[k] == nil then
                saved[k] = type(v) == "table" and {} or v
            end
        end
        data = saved
        print("[DATA] Loaded "..player.Name.." (Data: "..data.Data..")")
    else
        data = defaultData()
        print("[DATA] New player "..player.Name)
    end

    -- Offline income: award up to 30min of passive income
    local now = os.time()
    if data.LastSeen and data.LastSeen > 0 then
        local elapsed   = math.min(now - data.LastSeen, 1800) -- cap at 30min
        local offlineDPS = CONFIG.PASSIVE_INCOME
        for _, comp in ipairs(data.Computers or {}) do
            local ct = CONFIG.COMPUTER_TIERS[comp.tier]
            if ct then offlineDPS = offlineDPS + ct.dps end
        end
        local bonus = math.floor(elapsed * offlineDPS)
        if bonus > 0 then
            data.Data        = data.Data + bonus
            data.TotalEarned = data.TotalEarned + bonus
            print("[DATA] "..player.Name.." offline bonus: +"..bonus.." Data")
        end
    end
    data.LastSeen = now

    PlayerData[player.UserId] = data

    -- Build leaderstats — add all children BEFORE parenting to player
    -- so client never sees a partial folder
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"

    local dv = Instance.new("IntValue")
    dv.Name  = "Data"
    dv.Value = data.Data
    dv.Parent = ls

    local hv = Instance.new("IntValue")
    hv.Name  = "House"
    hv.Value = data.HouseTier
    hv.Parent = ls

    -- Parent folder last — atomic replication
    ls.Parent = player
    print("[OK] Leaderstats set for "..player.Name.." = "..data.Data)
end

local function SavePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    data.LastSeen = os.time()
    local key = "Player_"..player.UserId
    local ok  = dsSet(key, data)
    if ok then
        print("[DATA] Saved "..player.Name)
    else
        warn("[DATA] Save FAILED for "..player.Name)
    end
end

local function UpdateData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    -- Update leaderstats value (drives the leaderboard display)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local dv = ls:FindFirstChild("Data")
        if dv then dv.Value = data.Data end
    end
    -- Fire to client so the HUD updates immediately
    DataUpdated:FireClient(player, data.Data)
end

local function Notify(player, msg, t)
    Notification:FireClient(player, msg, t or "info")
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local now      = os.time()
    local daysSince = math.floor((now - (data.LastDailyReward or 0)) / 86400)
    if daysSince == 0 then Notify(player, "Already claimed today!", "error"); return end
    if daysSince > 1 then data.DailyStreak = 1
    else data.DailyStreak = (data.DailyStreak or 0) + 1 end
    local idx    = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[idx]
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day "..data.DailyStreak..": +"..reward.." Data!", "success")
end)

local orbCooldowns = {}
CollectOrb.OnServerEvent:Connect(function(player)
    local now = tick()
    if orbCooldowns[player.UserId] and (now - orbCooldowns[player.UserId]) < 0.3 then return end
    orbCooldowns[player.UserId] = now
    local data = PlayerData[player.UserId]
    if not data then return end
    data.Data = data.Data + CONFIG.ORB_REWARD
    data.TotalEarned = data.TotalEarned + CONFIG.ORB_REWARD
    data.BlocksCollected = (data.BlocksCollected or 0) + 1
    UpdateData(player)
    Notify(player, "+"..CONFIG.ORB_REWARD.." Data!", "success")
end)

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot then Notify(player, "Plot not found!", "error"); return end
    if plot.owner then Notify(player, "Already owned!", "error"); return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Plots >= ht.maxPlots then Notify(player, "Upgrade house for more plots!", "error"); return end
    if data.Data < plot.price then Notify(player, "Need "..plot.price.." Data!", "error"); return end
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId; plot.ownerName = player.Name
    table.insert(data.Plots, plotId)
    UpdateData(player)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
    Notify(player, "Plot purchased! (-"..plot.price..")", "success")
    print("[GAME] "..player.Name.." bought "..plotId)
end)

SellPlot.OnServerEvent:Connect(function(player, plotId)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error"); return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local sellPrice = math.floor(plot.price * 0.5)
    data.Data = data.Data + sellPrice; data.TotalEarned = data.TotalEarned + sellPrice
    plot.owner = nil; plot.ownerName = nil
    for i = #data.Plots, 1, -1 do
        if data.Plots[i] == plotId then table.remove(data.Plots, i); break end
    end
    for i = #data.Computers, 1, -1 do
        if data.Computers[i].plotId == plotId then table.remove(data.Computers, i) end
    end
    plot.computers = {}
    UpdateData(player)
    PlotSold:FireAllClients(plotId)
    Notify(player, "Sold for "..sellPrice.." Data!", "success")
end)

PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    if type(plotId) ~= "string" then return end
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error"); return end
    local data = PlayerData[player.UserId]
    if not data then return end
    tier = (type(tier) == "number" and tier) or 1
    local ct = CONFIG.COMPUTER_TIERS[tier]
    if not ct then Notify(player, "Invalid tier!", "error"); return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Computers >= ht.maxComputers then Notify(player, "Upgrade house!", "error"); return end
    if data.Data < ct.cost then Notify(player, "Need "..ct.cost.." Data!", "error"); return end
    data.Data = data.Data - ct.cost; data.TotalSpent = data.TotalSpent + ct.cost
    local comp = {tier=tier, plotId=plotId, name=ct.name, dps=ct.dps}
    table.insert(data.Computers, comp); table.insert(plot.computers, comp)
    UpdateData(player)
    ComputerPlaced:FireClient(player, plotId, tier, ct.name)
    Notify(player, ct.name.." placed! (+"..ct.dps.."/s)", "success")
    print("[GAME] "..player.Name.." placed "..ct.name)
end)

UpgradeHouse.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local nextTier = data.HouseTier + 1
    if nextTier > #CONFIG.HOUSE_TIERS then Notify(player, "Max level!", "error"); return end
    local cost = CONFIG.HOUSE_TIERS[nextTier].cost
    if data.Data < cost then Notify(player, "Need "..cost.." Data!", "error"); return end
    data.Data = data.Data - cost; data.TotalSpent = data.TotalSpent + cost
    data.HouseTier = nextTier
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local hv = ls:FindFirstChild("House")
        if hv then hv.Value = nextTier end
    end
    UpdateData(player)
    HouseUpgraded:FireClient(player, nextTier, CONFIG.HOUSE_TIERS[nextTier].name)
    Notify(player, "Upgraded to "..CONFIG.HOUSE_TIERS[nextTier].name.."!", "success")
end)

-- Safe: client invoking server is fine, never InvokeClient
GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

print("[OK] Event handlers connected")

-- ============================================================
-- PASSIVE INCOME LOOP (server-side, in-memory only)
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
-- AUTOSAVE every 60 seconds
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

-- CRITICAL: backfill players already in game (Studio race condition fix)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
    print("[LEAVE] "..player.Name)
    task.spawn(SavePlayerData, player)
    task.delay(3, function()
        PlayerData[player.UserId]   = nil
        orbCooldowns[player.UserId] = nil
    end)
end)

game:BindToClose(function()
    print("[DATA] Server closing — saving all players...")
    for _, p in ipairs(Players:GetPlayers()) do
        SavePlayerData(p)
    end
    print("[DATA] All players saved")
end)

-- ============================================================
-- INIT
-- ============================================================
InitPlots()
print("=":rep(50))
print("DataTycoon v0.21 — SERVER READY")
print("=":rep(50))
