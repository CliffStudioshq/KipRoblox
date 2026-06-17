--[[
    Main.server.lua — DataTycoon Server
    v0.19 — Hardened rewrite
    Fixes: walkway/lamp/bench parents, naming collisions, DataStore races,
           debounce on orb collection, nil-data guard in passive loop,
           proper cleanup on PlayerRemoving.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

print("=":rep(40))
print("DataTycoon v0.19 — Server starting...")
print("=":rep(40))

-- ============================================================
-- CRITICAL: Create baseplate + spawn IMMEDIATELY so players
-- never fall through before the rest of the world builds.
-- ============================================================
do
    local base = Instance.new("Part")
    base.Name = "GrassBase"
    base.Size = Vector3.new(512, 4, 512)
    base.Position = Vector3.new(0, -2, 0)
    base.Anchored = true
    base.CanCollide = true
    base.BrickColor = BrickColor.new("Dark green")
    base.Material = Enum.Material.Grass
    base.Parent = workspace

    local spawnPad = Instance.new("Part")
    spawnPad.Name = "SpawnPlatform"
    spawnPad.Size = Vector3.new(14, 3, 14)
    spawnPad.Position = Vector3.new(0, 1.5, 0)
    spawnPad.Anchored = true
    spawnPad.BrickColor = BrickColor.new("Bright green")
    spawnPad.Material = Enum.Material.SmoothPlastic
    spawnPad.Parent = workspace

    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Size = Vector3.new(10, 1, 10)
    spawnLoc.Position = Vector3.new(0, 3.5, 0)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = false
    spawnLoc.Transparency = 1
    spawnLoc.Parent = workspace

    print("[OK] Baseplate + spawn created (early)")
end

local DataStore = DataStoreService:GetDataStore("DataTycoon_v4")

-- ============================================================
-- CREATE REMOTE EVENTS
-- ============================================================
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

local function CreateEvent(name, className)
    local event = Instance.new(className or "RemoteEvent")
    event.Name = name
    event.Parent = Events
    return event
end

-- Client → Server
local ClaimDailyReward = CreateEvent("ClaimDailyReward")
local CollectOrb     = CreateEvent("CollectOrb")
local PurchasePlot   = CreateEvent("PurchasePlot")
local SellPlot       = CreateEvent("SellPlot")
local PlaceComputer  = CreateEvent("PlaceComputer")
local UpgradeHouse   = CreateEvent("UpgradeHouse")

-- Server → Client
local DailyRewardClaimed = CreateEvent("DailyRewardClaimed")
local Notification       = CreateEvent("Notification")
local DataUpdated        = CreateEvent("DataUpdated")
local PlotPurchased      = CreateEvent("PlotPurchased")
local PlotSold           = CreateEvent("PlotSold")
local ComputerPlaced     = CreateEvent("ComputerPlaced")
local HouseUpgraded      = CreateEvent("HouseUpgraded")

-- Remote Function
local GetPlayerData = CreateEvent("GetPlayerData", "RemoteFunction")

print("[OK] RemoteEvents created")

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
        {name = "Shack",         cost = 0,     maxComputers = 1, maxPlots = 2},
        {name = "Small House",   cost = 300,   maxComputers = 2, maxPlots = 4},
        {name = "Modern House",  cost = 1500,  maxComputers = 4, maxPlots = 8},
        {name = "Tech Villa",    cost = 8000,  maxComputers = 8, maxPlots = 8},
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
}

-- ============================================================
-- PLOT SYSTEM
-- ============================================================
local Plots = {}

local function InitPlots()
    local coords = {
        {-3,-3},{-3,3},{3,-3},{3,3},
        {0,-3},{0,3},{-3,0},{3,0},
    }
    for _, c in ipairs(coords) do
        local x, z = c[1], c[2]
        local dist = math.max(math.abs(x), math.abs(z))
        local plotId = "plot_" .. x .. "_" .. z
        local price = math.floor(50 * (2 ^ dist))
        local spacing = 170
        Plots[plotId] = {
            id = plotId, owner = nil, ownerName = nil,
            x = x, z = z, dist = dist, price = price,
            center = Vector3.new(x * spacing, 0.5, z * spacing),
            computers = {},
        }
    end
    local count = 0
    for _ in pairs(Plots) do count = count + 1 end
    print("[OK] " .. count .. " plots initialized")
end

-- ============================================================
-- DATA FUNCTIONS
-- ============================================================
local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, savedData = pcall(function()
        return DataStore:GetAsync(key)
    end)

    if success and savedData then
        -- Merge saved data with defaults (handles new fields added in updates)
        for k, v in pairs(DEFAULT_DATA) do
            if savedData[k] == nil then savedData[k] = v end
        end
        PlayerData[player.UserId] = savedData
        print("[DATA] Loaded " .. player.Name .. " (Data: " .. savedData.Data .. ")")
    else
        PlayerData[player.UserId] = {}
        for k, v in pairs(DEFAULT_DATA) do
            PlayerData[player.UserId][k] = v
        end
        print("[DATA] New player " .. player.Name)
    end

    -- Create leaderstats
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = PlayerData[player.UserId].Data
    dataValue.Parent = leaderstats

    local houseValue = Instance.new("IntValue")
    houseValue.Name = "House"
    houseValue.Value = PlayerData[player.UserId].HouseTier
    houseValue.Parent = leaderstats

    print("[OK] Leaderstats for " .. player.Name .. " = " .. PlayerData[player.UserId].Data)
end

local function SavePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local key = "Player_" .. player.UserId
    local ok, err = pcall(function()
        DataStore:SetAsync(key, data)
    end)
    if not ok then
        warn("[DATA] Save failed for " .. player.Name .. ": " .. tostring(err))
    end
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

local function Notify(player, msg, notifType)
    Notification:FireClient(player, msg, notifType or "info")
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local daysSince = math.floor((now - lastClaim) / 86400)
    if daysSince == 0 then
        Notify(player, "Already claimed today!", "error")
        return
    end
    if daysSince > 1 then
        data.DailyStreak = 1
    else
        data.DailyStreak = (data.DailyStreak or 0) + 1
    end
    local idx = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[idx]
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day " .. data.DailyStreak .. ": +" .. reward .. " Data!", "success")
    print("[GAME] " .. player.Name .. " daily reward +" .. reward)
end)

-- Orb collection with server-side debounce
local orbCooldowns = {}

CollectOrb.OnServerEvent:Connect(function(player)
    -- Debounce: prevent spam (0.3s cooldown per player)
    local now = tick()
    if orbCooldowns[player.UserId] and (now - orbCooldowns[player.UserId]) < 0.3 then
        return
    end
    orbCooldowns[player.UserId] = now

    local data = PlayerData[player.UserId]
    if not data then return end
    data.Data = data.Data + CONFIG.ORB_REWARD
    data.TotalEarned = data.TotalEarned + CONFIG.ORB_REWARD
    data.BlocksCollected = (data.BlocksCollected or 0) + 1
    UpdateData(player)
    Notify(player, "+" .. CONFIG.ORB_REWARD .. " Data!", "success")
    print("[GAME] " .. player.Name .. " orb +" .. CONFIG.ORB_REWARD .. " (total: " .. data.Data .. ")")
end)

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot then Notify(player, "Plot not found!", "error") return end
    if plot.owner then Notify(player, "Already owned!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Plots >= ht.maxPlots then Notify(player, "Upgrade house for more plots!", "error") return end
    if data.Data < plot.price then Notify(player, "Need " .. plot.price .. " Data!", "error") return end
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId
    plot.ownerName = player.Name
    table.insert(data.Plots, plotId)
    UpdateData(player)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
    Notify(player, "Plot purchased! (-" .. plot.price .. ")", "success")
    print("[GAME] " .. player.Name .. " bought " .. plotId)
end)

SellPlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local sellPrice = math.floor(plot.price * 0.5)
    data.Data = data.Data + sellPrice
    data.TotalEarned = data.TotalEarned + sellPrice
    plot.owner = nil; plot.ownerName = nil
    for i = #data.Plots, 1, -1 do
        if data.Plots[i] == plotId then table.remove(data.Plots, i) break end
    end
    for i = #data.Computers, 1, -1 do
        if data.Computers[i].plotId == plotId then table.remove(data.Computers, i) end
    end
    plot.computers = {}
    UpdateData(player)
    PlotSold:FireAllClients(plotId)
    Notify(player, "Sold for " .. sellPrice .. " Data!", "success")
end)

PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    tier = tier or 1
    local ct = CONFIG.COMPUTER_TIERS[tier]
    if not ct then Notify(player, "Invalid tier!", "error") return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Computers >= ht.maxComputers then Notify(player, "Upgrade house!", "error") return end
    if data.Data < ct.cost then Notify(player, "Need " .. ct.cost .. " Data!", "error") return end
    data.Data = data.Data - ct.cost
    data.TotalSpent = data.TotalSpent + ct.cost
    local comp = {tier = tier, plotId = plotId, name = ct.name, dps = ct.dps}
    table.insert(data.Computers, comp)
    table.insert(plot.computers, comp)
    UpdateData(player)
    ComputerPlaced:FireClient(player, plotId, tier, ct.name)
    Notify(player, ct.name .. " placed! (+" .. ct.dps .. "/s)", "success")
    print("[GAME] " .. player.Name .. " placed " .. ct.name)
end)

UpgradeHouse.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local nextTier = data.HouseTier + 1
    if nextTier > #CONFIG.HOUSE_TIERS then Notify(player, "Max level!", "error") return end
    local cost = CONFIG.HOUSE_TIERS[nextTier].cost
    if data.Data < cost then Notify(player, "Need " .. cost .. " Data!", "error") return end
    data.Data = data.Data - cost
    data.TotalSpent = data.TotalSpent + cost
    data.HouseTier = nextTier
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local hv = ls:FindFirstChild("House")
        if hv then hv.Value = nextTier end
    end
    UpdateData(player)
    HouseUpgraded:FireClient(player, nextTier, CONFIG.HOUSE_TIERS[nextTier].name)
    Notify(player, "Upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name .. "!", "success")
    print("[GAME] " .. player.Name .. " upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name)
end)

GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

print("[OK] Event handlers connected")

-- ============================================================
-- PASSIVE INCOME (1 Data/sec base + computers)
-- ============================================================
task.spawn(function()
    print("[OK] Passive income loop started")
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                local totalDPS = CONFIG.PASSIVE_INCOME
                if data.Computers then
                    for _, comp in ipairs(data.Computers) do
                        local tier = CONFIG.COMPUTER_TIERS[comp.tier]
                        if tier then totalDPS = totalDPS + tier.dps end
                    end
                end
                data.Data = data.Data + totalDPS
                data.TotalEarned = data.TotalEarned + totalDPS
                UpdateData(p)
            end
        end
    end
end)

-- ============================================================
-- PLAYER CONNECTIONS
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    print("[JOIN] " .. player.Name)
    LoadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    print("[LEAVE] " .. player.Name)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
    orbCooldowns[player.UserId] = nil
end)

game:BindToClose(function()
    for _, p in ipairs(Players:GetPlayers()) do SavePlayerData(p) end
end)

-- World is built by WorldBuilder.server.lua (separate script, own budget)

-- === INIT ===
InitPlots()