--[[
    Main.server.lua — DataTycoon Server
    v0.6 — Full game systems: blocks, land, computers, house upgrades
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStore = DataStoreService:GetDataStore("DataTycoon_v3")

-- === CREATE REMOTE EVENTS ===
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
local CollectBlocks = CreateEvent("CollectBlocks")
local PurchasePlot = CreateEvent("PurchasePlot")
local SellPlot = CreateEvent("SellPlot")
local PlaceComputer = CreateEvent("PlaceComputer")
local UpgradeHouse = CreateEvent("UpgradeHouse")

-- Server → Client
local DailyRewardClaimed = CreateEvent("DailyRewardClaimed")
local Notification = CreateEvent("Notification")
local DataUpdated = CreateEvent("DataUpdated")
local PlotPurchased = CreateEvent("PlotPurchased")
local PlotSold = CreateEvent("PlotSold")
local ComputerPlaced = CreateEvent("ComputerPlaced")
local HouseUpgraded = CreateEvent("HouseUpgraded")

-- Remote Functions
local GetPlayerData = CreateEvent("GetPlayerData", "RemoteFunction")
local GetPlotInfo = CreateEvent("GetPlotInfo", "RemoteFunction")

print("DataTycoon: RemoteEvents created!")

-- === CONFIGURATION ===
local CONFIG = {
    STARTING_DATA = 50,
    BLOCK_REWARD = 5,
    PASSIVE_INCOME = 1,  -- Data per second
    
    BASE_PLOT_PRICE = 50,
    PLOT_PRICE_MULTIPLIER = 2.0,
    MAX_PLOTS = 6,
    PLOT_SIZE = 90,
    PLOT_SPACING = 130,  -- 90 plot + 40 gap
    PLOT_RANGE = 3,
    PLOT_MIN_DIST = 3,  -- Only outermost ring = 16 plots
    
    COMPUTER_TIERS = {
        {name = "Budget Rig",    cost = 100,   dps = 2,   slots = 1},
        {name = "Gaming PC",     cost = 500,   dps = 8,   slots = 2},
        {name = "Server Rack",   cost = 2500,  dps = 30,  slots = 4},
        {name = "Supercomputer", cost = 10000, dps = 120, slots = 8},
    },
    
    HOUSE_TIERS = {
        {name = "Shack",         cost = 0,     maxComputers = 1,  maxPlots = 2},
        {name = "Small House",   cost = 300,   maxComputers = 2,  maxPlots = 5},
        {name = "Modern House",  cost = 1500,  maxComputers = 4,  maxPlots = 10},
        {name = "Tech Villa",    cost = 8000,  maxComputers = 8,  maxPlots = 16},
        {name = "Mega Compound", cost = 30000, maxComputers = 16, maxPlots = 16},
    },
    
    DAILY_REWARDS = {50, 75, 100, 150, 200, 300, 500},
}

-- === PLAYER DATA ===
local PlayerData = {}

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    TotalSpent = 0,
    Plots = {},         -- {plotId, ...}
    Computers = {},     -- {tier = 1, plotId = "plot_0_0", ...}
    HouseTier = 1,
    LastLogin = 0,
    DailyStreak = 0,
    LastDailyReward = 0,
    BlocksCollected = 0,
}

-- === PLOT SYSTEM ===
local Plots = {}

local function InitPlots()
    for x = -CONFIG.PLOT_RANGE, CONFIG.PLOT_RANGE do
        for z = -CONFIG.PLOT_RANGE, CONFIG.PLOT_RANGE do
            local dist = math.max(math.abs(x), math.abs(z))
            -- Only outermost ring for privacy
            if dist >= CONFIG.PLOT_MIN_DIST then
                local plotId = "plot_" .. x .. "_" .. z
                local price = math.floor(CONFIG.BASE_PLOT_PRICE * (CONFIG.PLOT_PRICE_MULTIPLIER ^ dist))
                Plots[plotId] = {
                    id = plotId,
                    owner = nil,
                    ownerName = nil,
                    x = x,
                    z = z,
                    dist = dist,
                    price = price,
                    center = Vector3.new(x * CONFIG.PLOT_SPACING, 0.5, z * CONFIG.PLOT_SPACING),
                    computers = {},
                }
            end
        end
    end
    local count = 0
    for _ in pairs(Plots) do count = count + 1 end
    print("DataTycoon: " .. count .. " plots (outer ring, " .. CONFIG.PLOT_SPACING .. " spacing)")
end

-- === DATA FUNCTIONS ===

local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, savedData = pcall(function()
        return DataStore:GetAsync(key)
    end)
    
    if success and savedData then
        for k, v in pairs(DEFAULT_DATA) do
            if savedData[k] == nil then
                savedData[k] = v
            end
        end
        PlayerData[player.UserId] = savedData
        print("DataTycoon: Loaded data for " .. player.Name .. " (Data: " .. savedData.Data .. ")")
    else
        PlayerData[player.UserId] = {}
        for k, v in pairs(DEFAULT_DATA) do
            PlayerData[player.UserId][k] = v
        end
        print("DataTycoon: New player " .. player.Name)
    end
    
    -- Restore plot ownership
    for _, plot in pairs(Plots) do
        for _, ownedId in ipairs(PlayerData[player.UserId].Plots or {}) do
            if plot.id == ownedId then
                plot.owner = player.UserId
                plot.ownerName = player.Name
            end
        end
    end
    
    -- Offline income
    local now = os.time()
    local lastLogin = PlayerData[player.UserId].LastLogin or now
    local timeAway = math.max(0, now - lastLogin)
    
    if timeAway > 60 then
        local totalDPS = 0
        for _, computer in ipairs(PlayerData[player.UserId].Computers or {}) do
            local tier = CONFIG.COMPUTER_TIERS[computer.tier]
            if tier then
                totalDPS = totalDPS + tier.dps
            end
        end
        totalDPS = totalDPS + CONFIG.PASSIVE_INCOME
        
        local offlineEarnings = math.floor(totalDPS * timeAway * 0.5)
        if offlineEarnings > 0 then
            PlayerData[player.UserId].Data = PlayerData[player.UserId].Data + offlineEarnings
            PlayerData[player.UserId].TotalEarned = PlayerData[player.UserId].TotalEarned + offlineEarnings
            print("DataTycoon: " .. player.Name .. " earned " .. offlineEarnings .. " offline")
        end
    end
    
    PlayerData[player.UserId].LastLogin = now
    
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
    
    print("DataTycoon: Leaderstats for " .. player.Name .. " (Data: " .. PlayerData[player.UserId].Data .. ")")
end

local function SavePlayerData(player)
    if not PlayerData[player.UserId] then return end
    local key = "Player_" .. player.UserId
    local success = pcall(function()
        DataStore:SetAsync(key, PlayerData[player.UserId])
    end)
    if success then
        print("DataTycoon: Saved " .. player.Name)
    else
        warn("DataTycoon: Save failed for " .. player.Name)
    end
end

local function UpdateData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    DataUpdated:FireClient(player, data.Data)
end

local function Notify(player, message, notifType)
    Notification:FireClient(player, message, notifType or "info")
end

-- === EVENT HANDLERS ===

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local daysSinceLast = math.floor((now - lastClaim) / 86400)
    
    if daysSinceLast == 0 then
        Notify(player, "Already claimed today!", "error")
        return
    end
    
    if daysSinceLast > 1 then
        data.DailyStreak = 1
    else
        data.DailyStreak = (data.DailyStreak or 0) + 1
    end
    
    local rewardIndex = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[rewardIndex]
    
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day " .. data.DailyStreak .. ": +" .. reward .. " Data!", "success")
    print("DataTycoon: " .. player.Name .. " daily reward " .. reward)
end)

CollectBlocks.OnServerEvent:Connect(function(player, blockCount)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local reward = (blockCount or 1) * CONFIG.BLOCK_REWARD
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.BlocksCollected = (data.BlocksCollected or 0) + (blockCount or 1)
    UpdateData(player)
    
    Notify(player, "+" .. reward .. " Data!", "success")
end)

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot then
        Notify(player, "Plot not found!", "error")
        return
    end
    
    if plot.owner ~= nil then
        Notify(player, "Plot already owned by " .. (plot.ownerName or "someone") .. "!", "error")
        return
    end
    
    local data = PlayerData[player.UserId]
    if not data then return end
    
    -- Check house tier plot limit
    local houseTier = CONFIG.HOUSE_TIERS[data.HouseTier]
    local plotCount = #data.Plots
    if plotCount >= houseTier.maxPlots then
        Notify(player, "Upgrade your house to buy more plots! (Max: " .. houseTier.maxPlots .. ")", "error")
        return
    end
    
    if plotCount >= CONFIG.MAX_PLOTS then
        Notify(player, "Max plots reached!", "error")
        return
    end
    
    if data.Data < plot.price then
        Notify(player, "Need " .. plot.price .. " Data! (You have " .. data.Data .. ")", "error")
        return
    end
    
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId
    plot.ownerName = player.Name
    table.insert(data.Plots, plotId)
    
    UpdateData(player)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
    Notify(player, "Plot purchased! (-" .. plot.price .. " Data)", "success")
    print("DataTycoon: " .. player.Name .. " bought " .. plotId .. " for " .. plot.price)
end)

SellPlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then
        Notify(player, "You don't own this plot!", "error")
        return
    end
    
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local sellPrice = math.floor(plot.price * 0.5)
    data.Data = data.Data + sellPrice
    data.TotalEarned = data.TotalEarned + sellPrice
    plot.owner = nil
    plot.ownerName = nil
    
    -- Remove from player's plots
    for i, id in ipairs(data.Plots) do
        if id == plotId then
            table.remove(data.Plots, i)
            break
        end
    end
    
    -- Remove computers on this plot
    local removedComps = {}
    for i = #data.Computers, 1, -1 do
        if data.Computers[i].plotId == plotId then
            table.insert(removedComps, data.Computers[i])
            table.remove(data.Computers, i)
        end
    end
    plot.computers = {}
    
    UpdateData(player)
    PlotSold:FireAllClients(plotId)
    Notify(player, "Plot sold for " .. sellPrice .. " Data!", "success")
    print("DataTycoon: " .. player.Name .. " sold " .. plotId .. " for " .. sellPrice)
end)

PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then
        Notify(player, "You don't own this plot!", "error")
        return
    end
    
    local data = PlayerData[player.UserId]
    if not data then return end
    
    tier = tier or 1
    local computerTier = CONFIG.COMPUTER_TIERS[tier]
    if not computerTier then
        Notify(player, "Invalid computer tier!", "error")
        return
    end
    
    -- Check house tier computer limit
    local houseTier = CONFIG.HOUSE_TIERS[data.HouseTier]
    local computerCount = #data.Computers
    if computerCount >= houseTier.maxComputers then
        Notify(player, "Upgrade your house for more computers! (Max: " .. houseTier.maxComputers .. ")", "error")
        return
    end
    
    if data.Data < computerTier.cost then
        Notify(player, "Need " .. computerTier.cost .. " Data! (You have " .. data.Data .. ")", "error")
        return
    end
    
    data.Data = data.Data - computerTier.cost
    data.TotalSpent = data.TotalSpent + computerTier.cost
    
    local computer = {
        tier = tier,
        plotId = plotId,
        name = computerTier.name,
        dps = computerTier.dps,
    }
    table.insert(data.Computers, computer)
    table.insert(plot.computers, computer)
    
    UpdateData(player)
    ComputerPlaced:FireClient(player, plotId, tier, computerTier.name)
    Notify(player, computerTier.name .. " placed! (+" .. computerTier.dps .. " Data/sec)", "success")
    print("DataTycoon: " .. player.Name .. " placed " .. computerTier.name .. " on " .. plotId)
end)

UpgradeHouse.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local nextTier = data.HouseTier + 1
    if nextTier > #CONFIG.HOUSE_TIERS then
        Notify(player, "Max house level reached!", "error")
        return
    end
    
    local upgradeCost = CONFIG.HOUSE_TIERS[nextTier].cost
    if data.Data < upgradeCost then
        Notify(player, "Need " .. upgradeCost .. " Data! (You have " .. data.Data .. ")", "error")
        return
    end
    
    data.Data = data.Data - upgradeCost
    data.TotalSpent = data.TotalSpent + upgradeCost
    data.HouseTier = nextTier
    
    -- Update leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local houseValue = leaderstats:FindFirstChild("House")
        if houseValue then
            houseValue.Value = nextTier
        end
    end
    
    UpdateData(player)
    HouseUpgraded:FireClient(player, nextTier, CONFIG.HOUSE_TIERS[nextTier].name)
    Notify(player, "House upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name .. "!", "success")
    print("DataTycoon: " .. player.Name .. " upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name)
end)

-- === REMOTE FUNCTIONS ===

GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

GetPlotInfo.OnServerInvoke = function(player, plotId)
    local plot = Plots[plotId]
    if not plot then return nil end
    return {
        id = plot.id,
        owner = plot.owner,
        ownerName = plot.ownerName,
        price = plot.price,
        x = plot.x,
        z = plot.z,
        computerCount = #plot.computers,
    }
end

-- === PASSIVE MINING ===
task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                local totalDPS = CONFIG.PASSIVE_INCOME
                for _, computer in ipairs(data.Computers) do
                    local tier = CONFIG.COMPUTER_TIERS[computer.tier]
                    if tier then
                        totalDPS = totalDPS + tier.dps
                    end
                end
                data.Data = data.Data + totalDPS
                data.TotalEarned = data.TotalEarned + totalDPS
                UpdateData(p)
            end
        end
    end
end)

-- === PLAYER CONNECTIONS ===

Players.PlayerAdded:Connect(function(player)
    LoadPlayerData(player)
    print("DataTycoon: " .. player.Name .. " joined!")
end)

Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
    print("DataTycoon: " .. player.Name .. " left")
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        SavePlayerData(player)
    end
end)

-- === INIT ===
InitPlots()
print("DataTycoon v0.6 server ready!")
