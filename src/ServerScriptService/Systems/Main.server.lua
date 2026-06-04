--[[
    Main.server.lua
    Simplified server script - all in one file for reliability
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Create RemoteEvents
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = game.ReplicatedStorage

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

-- Create all events
local PurchasePlot = CreateEvent("PurchasePlot")
local SellPlot = CreateEvent("SellPlot")
local CollectBlocks = CreateEvent("CollectBlocks")
local PlotPurchased = CreateEvent("PlotPurchased")
local PlotSold = CreateEvent("PlotSold")
local DataUpdated = CreateEvent("DataUpdated")
local Notification = CreateEvent("Notification")

local GetPlayerData = CreateFunction("GetPlayerData")

-- Simple DataStore
local DataStore = DataStoreService:GetDataStore("DataTycoon_v1")
local PlayerData = {}

local DEFAULT_DATA = {
    Data = 100,
    LandOwned = {},
    HouseTier = 1,
}

-- Load player data
local function LoadData(player)
    local key = "Player_" .. player.UserId
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    
    if success and data then
        PlayerData[player.UserId] = data
    else
        PlayerData[player.UserId] = {
            Data = DEFAULT_DATA.Data,
            LandOwned = DEFAULT_DATA.LandOwned,
            HouseTier = DEFAULT_DATA.HouseTier,
        }
    end
    
    -- Create leaderstats
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = PlayerData[player.UserId].Data
    dataValue.Parent = leaderstats
    
    print("DataTycoon: " .. player.Name .. " loaded with " .. PlayerData[player.UserId].Data .. " Data")
end

-- Save player data
local function SaveData(player)
    if not PlayerData[player.UserId] then return end
    local key = "Player_" .. player.UserId
    pcall(function()
        DataStore:SetAsync(key, PlayerData[player.UserId])
    end)
end

-- Add Data
local function AddData(player, amount)
    local data = PlayerData[player.UserId]
    if not data then return end
    data.Data = data.Data + amount
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
end

-- Remote function: GetPlayerData
GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

-- Remote event: CollectBlocks
CollectBlocks.OnServerEvent:Connect(function(player, blockCount)
    local reward = blockCount or 1
    AddData(player, reward)
    Notification:FireClient(player, "Collected " .. reward .. " Data!", "success")
end)

-- Player added
Players.PlayerAdded:Connect(function(player)
    LoadData(player)
    print("DataTycoon: " .. player.Name .. " joined!")
end)

-- Player removing
Players.PlayerRemoving:Connect(function(player)
    SaveData(player)
    PlayerData[player.UserId] = nil
end)

-- Server shutdown
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        SaveData(player)
    end
end)

print("DataTycoon: Server ready!")
