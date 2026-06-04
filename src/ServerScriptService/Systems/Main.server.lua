--[[
    Main.server.lua
    Server entry point for DataTycoon
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents folder
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

-- Create all remote events
local function CreateEvent(name)
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = Events
    return event
end

local function CreateFunction(name)
    local func = Instance.new("RemoteFunction")
    func.Name = name
    func.Parent = Events
    return func
end

-- Create events
local dataUpdated = CreateEvent("DataUpdated")
local notification = CreateEvent("Notification")
local purchasePlot = CreateEvent("PurchasePlot")
local sellPlot = CreateEvent("SellPlot")
local collectBlocks = CreateEvent("CollectBlocks")

local getPlayerData = CreateFunction("GetPlayerData")
local getPlotInfo = CreateFunction("GetPlotInfo")
local getLeaderboard = CreateFunction("GetLeaderboard")

-- Player data storage
local PlayerData = {}

local DEFAULT_DATA = {
    Data = 100,
    LandOwned = {},
    Computers = {},
    HouseTier = 1,
    TotalEarned = 0,
    TotalSpent = 0,
}

-- Load player data
local function LoadPlayerData(player)
    PlayerData[player.UserId] = table.clone(DEFAULT_DATA)
    
    -- Create leaderstats
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = DEFAULT_DATA.Data
    dataValue.Parent = leaderstats
    
    local houseValue = Instance.new("IntValue")
    houseValue.Name = "House"
    houseValue.Value = DEFAULT_DATA.HouseTier
    houseValue.Parent = leaderstats
    
    -- Notify client
    dataUpdated:FireClient(player, DEFAULT_DATA.Data)
    print("DataTycoon: " .. player.Name .. " loaded with " .. DEFAULT_DATA.Data .. " Data")
end

-- Save player data (simplified - no DataStore for now)
local function SavePlayerData(player)
    PlayerData[player.UserId] = nil
end

-- Add Data
local function AddData(player, amount)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    data.Data = data.Data + amount
    data.TotalEarned = data.TotalEarned + amount
    
    -- Update leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    
    -- Notify client
    dataUpdated:FireClient(player, data.Data)
end

-- Remove Data
local function RemoveData(player, amount)
    local data = PlayerData[player.UserId]
    if not data then return false end
    
    if data.Data < amount then
        return false
    end
    
    data.Data = data.Data - amount
    data.TotalSpent = data.TotalSpent + amount
    
    -- Update leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    
    -- Notify client
    dataUpdated:FireClient(player, data.Data)
    return true
end

-- Get player data (for RemoteFunction)
getPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId] or DEFAULT_DATA
end

-- Get plot info (simplified)
getPlotInfo.OnServerInvoke = function(player, plotId)
    return { id = plotId, owner = nil, price = 50 }
end

-- Get leaderboard
getLeaderboard.OnServerInvoke = function(player)
    local leaderboard = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local data = PlayerData[p.UserId]
        if data then
            table.insert(leaderboard, {
                Name = p.Name,
                Data = data.Data,
                HouseTier = data.HouseTier,
            })
        end
    end
    table.sort(leaderboard, function(a, b) return a.Data > b.Data end)
    return leaderboard
end

-- Handle collect blocks
collectBlocks.OnServerEvent:Connect(function(player, blockCount)
    local reward = blockCount or 1
    AddData(player, reward)
    notification:FireClient(player, "Collected " .. reward .. " Data!", "success")
end)

-- Handle purchase plot
purchasePlot.OnServerEvent:Connect(function(player, plotId)
    local success = RemoveData(player, 50)
    if success then
        notification:FireClient(player, "Plot purchased!", "success")
    else
        notification:FireClient(player, "Not enough Data!", "error")
    end
end)

-- Handle sell plot
sellPlot.OnServerEvent:Connect(function(player, plotId)
    AddData(player, 25)
    notification:FireClient(player, "Plot sold for 25 Data!", "success")
end)

-- Player connections
Players.PlayerAdded:Connect(function(player)
    LoadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
end)

-- Save all on shutdown
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        SavePlayerData(player)
    end
end)

print("DataTycoon: Server ready!")
