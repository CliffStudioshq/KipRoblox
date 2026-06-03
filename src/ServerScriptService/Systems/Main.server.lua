--[[
    Main.server.lua
    Entry point for all server-side systems
    Initializes all game systems and handles remote event connections
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for modules to load
local Events = ReplicatedStorage:WaitForChild("Events")
local DataCurrency = require(ReplicatedStorage.Modules.DataCurrency)
local LandSystem = require(ReplicatedStorage.Modules.LandSystem)

-- Initialize systems
print("DataTycoon: Initializing server systems...")
LandSystem:Initialize()
print("DataTycoon: All systems initialized!")

-- === REMOTE FUNCTION HANDLERS ===

-- GetPlayerData
local GetPlayerData = Events:WaitForChild("GetPlayerData")
GetPlayerData.OnServerInvoke = function(player)
    return DataCurrency:GetPlayerData(player)
end

-- GetPlotInfo
local GetPlotInfo = Events:WaitForChild("GetPlotInfo")
GetPlotInfo.OnServerInvoke = function(player, plotId)
    return LandSystem:GetPlotInfo(plotId)
end

-- GetLeaderboard
local GetLeaderboard = Events:WaitForChild("GetLeaderboard")
GetLeaderboard.OnServerInvoke = function(player)
    local leaderboard = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local data = DataCurrency:GetPlayerData(p)
        if data then
            table.insert(leaderboard, {
                Name = p.Name,
                Data = data.Data,
                HouseTier = data.HouseTier,
            })
        end
    end
    -- Sort by Data (richest first)
    table.sort(leaderboard, function(a, b) return a.Data > b.Data end)
    return leaderboard
end

-- === REMOTE EVENT HANDLERS ===

-- PurchasePlot
local PurchasePlot = Events:WaitForChild("PurchasePlot")
PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    local success, message = LandSystem:PurchasePlot(player, plotId)
    
    -- Notify the player
    local notification = Events:WaitForChild("Notification")
    notification:FireClient(player, message, success and "success" or "error")
    
    if success then
        -- Update all clients about the plot
        local plotPurchased = Events:WaitForChild("PlotPurchased")
        plotPurchased:FireAllClients(plotId, player.UserId)
    end
end)

-- SellPlot
local SellPlot = Events:WaitForChild("SellPlot")
SellPlot.OnServerEvent:Connect(function(player, plotId)
    local success, message = LandSystem:SellPlot(player, plotId)
    
    local notification = Events:WaitForChild("Notification")
    notification:FireClient(player, message, success and "success" or "error")
    
    if success then
        local plotSold = Events:WaitForChild("PlotSold")
        plotSold:FireAllClients(plotId)
    end
end)

-- CollectBlocks (mini-game reward)
local CollectBlocks = Events:WaitForChild("CollectBlocks")
CollectBlocks.OnServerEvent:Connect(function(player, blockCount)
    -- Award 1 Data per block collected
    local reward = blockCount or 1
    DataCurrency:AddData(player, reward)
    
    local notification = Events:WaitForChild("Notification")
    notification:FireClient(player, "Collected " .. reward .. " Data!", "success")
end)

-- === PLAYER SETUP ===
Players.PlayerAdded:Connect(function(player)
    print("DataTycoon: " .. player.Name .. " joined the game!")
    
    -- Load their data
    local data = DataCurrency:LoadPlayerData(player)
    
    -- Send initial data to client
    task.wait(2) -- Wait for client to load
    local dataUpdated = Events:WaitForChild("DataUpdated")
    dataUpdated:FireClient(player, data.Data)
end)

Players.PlayerRemoving:Connect(function(player)
    print("DataTycoon: " .. player.Name .. " left. Saving data...")
    DataCurrency:SavePlayerData(player)
end)

print("DataTycoon: Server ready!")
