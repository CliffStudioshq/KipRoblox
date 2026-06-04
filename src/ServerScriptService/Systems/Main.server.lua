--[[
    Main.server.lua — DataTycoon Server
    v0.2 — Research-driven redesign
    Key changes:
    - Faster early progression (first upgrade in <30 seconds)
    - Visual feedback on every action
    - Offline income system
    - Daily rewards
    - Better leaderstats
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Services
local DataStore = DataStoreService:GetDataStore("DataTycoon_v2")

-- Create RemoteEvents folder
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

-- Create all events
local function CreateEvent(name, className)
    local event = Instance.new(className or "RemoteEvent")
    event.Name = name
    event.Parent = Events
    return event
end

-- Client → Server
local PurchasePlot = CreateEvent("PurchasePlot")
local SellPlot = CreateEvent("SellPlot")
local PlaceComputer = CreateEvent("PlaceComputer")
local UpgradeComputer = CreateEvent("UpgradeComputer")
local UpgradeHouse = CreateEvent("UpgradeHouse")
local CollectBlocks = CreateEvent("CollectBlocks")
local RequestRaid = CreateEvent("RequestRaid")
local ClaimDailyReward = CreateEvent("ClaimDailyReward")

-- Server → Client
local PlotPurchased = CreateEvent("PlotPurchased")
local PlotSold = CreateEvent("PlotSold")
local DataUpdated = CreateEvent("DataUpdated")
local Notification = CreateEvent("Notification")
local ComputerPlaced = CreateEvent("ComputerPlaced")
local HouseUpgraded = CreateEvent("HouseUpgraded")
local DailyRewardClaimed = CreateEvent("DailyRewardClaimed")
local OfflineIncome = CreateEvent("OfflineIncome")

-- Remote Functions
local GetPlayerData = CreateEvent("GetPlayerData", "RemoteFunction")
local GetPlotInfo = CreateEvent("GetPlotInfo", "RemoteFunction")
local GetLeaderboard = CreateEvent("GetLeaderboard", "RemoteFunction")

-- === CONFIGURATION ===
local CONFIG = {
    STARTING_DATA = 50,
    BLOCK_REWARD = 5,           -- Data per block collected
    BASE_PLOT_PRICE = 25,
    PLOT_PRICE_MULTIPLIER = 1.3,
    MAX_PLOTS = 16,
    PLOT_SIZE = 32,
    
    -- Computer tiers: {name, cost, dataPerSecond, slots}
    COMPUTER_TIERS = {
        {name = "Budget Rig",    cost = 100,  dps = 1,   slots = 1},
        {name = "Gaming PC",     cost = 500,  dps = 5,   slots = 2},
        {name = "Server Rack",   cost = 2500, dps = 25,  slots = 4},
        {name = "Supercomputer", cost = 10000,dps = 100, slots = 8},
    },
    
    -- House tiers: {name, cost, maxComputers}
    HOUSE_TIERS = {
        {name = "Shack",         cost = 0,    maxComputers = 1},
        {name = "Small House",   cost = 200,  maxComputers = 2},
        {name = "Modern House",  cost = 1000, maxComputers = 4},
        {name = "Tech Villa",    cost = 5000, maxComputers = 8},
        {name = "Mega Compound", cost = 25000,maxComputers = 16},
    },
    
    -- Daily rewards (day 1-7, then repeats with bonus)
    DAILY_REWARDS = {50, 75, 100, 150, 200, 300, 500},
}

-- === PLAYER DATA ===
local PlayerData = {}

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    TotalSpent = 0,
    LandOwned = {},
    Computers = {},
    HouseTier = 1,
    LastLogin = 0,
    DailyStreak = 0,
    LastDailyReward = 0,
    PlayTime = 0,
}

-- === DATA FUNCTIONS ===

local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    
    if success and data then
        -- Merge with defaults
        for k, v in pairs(DEFAULT_DATA) do
            if data[k] == nil then
                data[k] = v
            end
        end
        PlayerData[player.UserId] = data
    else
        PlayerData[player.UserId] = {}
        for k, v in pairs(DEFAULT_DATA) do
            PlayerData[player.UserId][k] = v
        end
    end
    
    -- Calculate offline income
    local now = os.time()
    local lastLogin = PlayerData[player.UserId].LastLogin or now
    local timeAway = math.max(0, now - lastLogin)
    local totalDPS = 0
    for _, computer in ipairs(PlayerData[player.UserId].Computers or {}) do
        local tier = CONFIG.COMPUTER_TIERS[computer.tier]
        if tier then
            totalDPS = totalDPS + tier.dps
        end
    end
    
    if timeAway > 60 and totalDPS > 0 then  -- Only if away for >1 minute
        local offlineEarnings = math.floor(totalDPS * timeAway * 0.5)  -- 50% efficiency offline
        if offlineEarnings > 0 then
            PlayerData[player.UserId].Data = PlayerData[player.UserId].Data + offlineEarnings
            PlayerData[player.UserId].TotalEarned = PlayerData[player.UserId].TotalEarned + offlineEarnings
            -- Notify client about offline income
            task.delay(3, function()
                if player and player.Parent then
                    OfflineIncome:FireClient(player, offlineEarnings, timeAway)
                end
            end)
        end
    end
    
    PlayerData[player.UserId].LastLogin = now
    
    SetupLeaderstats(player)
    return PlayerData[player.UserId]
end

local function SavePlayerData(player)
    if not PlayerData[player.UserId] then return end
    local key = "Player_" .. player.UserId
    pcall(function()
        DataStore:SetAsync(key, PlayerData[player.UserId])
    end)
end

local function SetupLeaderstats(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = data.Data
    dataValue.Parent = leaderstats
    
    local houseValue = Instance.new("IntValue")
    houseValue.Name = "House"
    houseValue.Value = data.HouseTier
    houseValue.Parent = leaderstats
end

local function UpdateDataDisplay(player, amount)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = amount
        end
    end
    DataUpdated:FireClient(player, amount)
end

-- === PLOT SYSTEM ===
local Plots = {}
local PlotGrid = {}

local function InitPlots()
    for x = -4, 4 do
        PlotGrid[x] = {}
        for z = -4, 4 do
            local plotId = "plot_" .. x .. "_" .. z
            local distance = math.sqrt(x * x + z * z)
            local price = math.floor(CONFIG.BASE_PLOT_PRICE * (CONFIG.PLOT_PRICE_MULTIPLIER ^ distance))
            Plots[plotId] = {
                id = plotId,
                owner = nil,
                position = {x = x, z = z},
                price = price,
                center = Vector3.new(x * CONFIG.PLOT_SIZE, 0, z * CONFIG.PLOT_SIZE),
            }
            PlotGrid[x][z] = plotId
        end
    end
end

-- === COMPUTER MINING SYSTEM ===
local function StartMiningSystem()
    while true do
        task.wait(1)  -- Every second
        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerData[player.UserId]
            if data and data.Computers then
                local totalDPS = 0
                for _, computer in ipairs(data.Computers) do
                    local tier = CONFIG.COMPUTER_TIERS[computer.tier]
                    if tier then
                        totalDPS = totalDPS + tier.dps
                    end
                end
                if totalDPS > 0 then
                    data.Data = data.Data + totalDPS
                    data.TotalEarned = data.TotalEarned + totalDPS
                    UpdateDataDisplay(player, data.Data)
                end
            end
        end
    end
end

-- === EVENT HANDLERS ===

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot then return end
    if plot.owner ~= nil then
        Notification:FireClient(player, "Plot already owned!", "error")
        return
    end
    
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local playerPlots = 0
    for _, p in pairs(Plots) do
        if p.owner == player.UserId then
            playerPlots = playerPlots + 1
        end
    end
    
    if playerPlots >= CONFIG.MAX_PLOTS then
        Notification:FireClient(player, "Max plots reached!", "error")
        return
    end
    
    if data.Data < plot.price then
        Notification:FireClient(player, "Need " .. plot.price .. " Data!", "error")
        return
    end
    
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId
    
    UpdateDataDisplay(player, data.Data)
    PlotPurchased:FireAllClients(plotId, player.UserId)
    Notification:FireClient(player, "Plot purchased! (-" .. plot.price .. " Data)", "success")
end)

CollectBlocks.OnServerEvent:Connect(function(player, blockCount)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local reward = (blockCount or 1) * CONFIG.BLOCK_REWARD
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    UpdateDataDisplay(player, data.Data)
    
    Notification:FireClient(player, "+" .. reward .. " Data!", "success")
end)

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local daysSinceLast = math.floor((now - lastClaim) / 86400)
    
    if daysSinceLast == 0 then
        Notification:FireClient(player, "Already claimed today!", "error")
        return
    end
    
    if daysSinceLast > 1 then
        data.DailyStreak = 1  -- Reset streak
    else
        data.DailyStreak = (data.DailyStreak or 0) + 1
    end
    
    local rewardIndex = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[rewardIndex]
    
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    
    UpdateDataDisplay(player, data.Data)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notification:FireClient(player, "Day " .. data.DailyStreak .. " reward: +" .. reward .. " Data!", "success")
end)

-- === REMOTE FUNCTION HANDLERS ===

GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

GetPlotInfo.OnServerInvoke = function(player, plotId)
    return Plots[plotId]
end

GetLeaderboard.OnServerInvoke = function(player)
    local leaderboard = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local data = PlayerData[p.UserId]
        if data then
            table.insert(leaderboard, {
                Name = p.Name,
                Data = data.Data,
                HouseTier = data.HouseTier,
                PlayTime = data.PlayTime or 0,
            })
        end
    end
    table.sort(leaderboard, function(a, b) return a.Data > b.Data end)
    return leaderboard
end

-- === PLAYER CONNECTIONS ===

Players.PlayerAdded:Connect(function(player)
    LoadPlayerData(player)
    print("DataTycoon: " .. player.Name .. " joined!")
end)

Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        SavePlayerData(player)
    end
end)

-- === INITIALIZATION ===
InitPlots()
task.spawn(StartMiningSystem)

print("DataTycoon v0.2 server ready!")
