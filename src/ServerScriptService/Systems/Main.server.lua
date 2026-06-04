--[[
    Main.server.lua
    Entry point for all server-side systems
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Events folder
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

-- Create RemoteEvents
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

-- Client → Server
CreateEvent("PurchasePlot")
CreateEvent("SellPlot")
CreateEvent("CollectBlocks")

-- Server → Client
CreateEvent("DataUpdated")
CreateEvent("Notification")
CreateEvent("PlotPurchased")

-- RemoteFunctions
local GetPlayerData = CreateFunction("GetPlayerData")

-- === PLAYER DATA ===
local PlayerData = {}
local DataStoreService = game:GetService("DataStoreService")
local DataStore = DataStoreService:GetDataStore("DataTycoon_v1")

local DEFAULT_DATA = {
    Data = 100,
    HouseTier = 1,
    LandOwned = {},
}

local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    if success and data then
        PlayerData[player.UserId] = data
    else
        PlayerData[player.UserId] = table.clone(DEFAULT_DATA)
    end
    return PlayerData[player.UserId]
end

local function SavePlayerData(player)
    if not PlayerData[player.UserId] then return end
    pcall(function()
        DataStore:SetAsync("Player_" .. player.UserId, PlayerData[player.UserId])
    end)
end

-- === LEADERSTATS ===
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
end

-- === REMOTE FUNCTION HANDLERS ===
GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

-- === PLAYER EVENTS ===
Players.PlayerAdded:Connect(function(player)
    LoadPlayerData(player)
    SetupLeaderstats(player)
    print("DataTycoon: " .. player.Name .. " joined! Data: " .. PlayerData[player.UserId].Data)
end)

Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
end)

print("DataTycoon: Server ready!")
