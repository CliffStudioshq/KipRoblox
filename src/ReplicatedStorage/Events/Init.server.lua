--[[
    RemoteEvents.lua
    Creates all RemoteEvents and RemoteFunctions for client-server communication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

-- RemoteEvents (client → server, fire-and-forget)
local function CreateRemoteEvent(name)
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = Events
    return event
end

-- RemoteFunctions (client → server → client, request-response)
local function CreateRemoteFunction(name)
    local func = Instance.new("RemoteFunction")
    func.Name = name
    func.Parent = Events
    return func
end

-- === CLIENT → SERVER EVENTS ===
CreateRemoteEvent("PurchasePlot")      -- Client wants to buy a plot
CreateRemoteEvent("SellPlot")          -- Client wants to sell a plot
CreateRemoteEvent("PlaceComputer")     -- Client wants to place a computer
CreateRemoteEvent("UpgradeComputer")   -- Client wants to upgrade a computer
CreateRemoteEvent("UpgradeHouse")      -- Client wants to upgrade house
CreateRemoteEvent("CollectBlocks")     -- Client collected blocks
CreateRemoteEvent("RequestRaid")       -- Client wants to raid another player
CreateRemoteEvent("UseItem")           -- Client used an item (hack phone, etc.)

-- === SERVER → CLIENT EVENTS ===
CreateRemoteEvent("PlotPurchased")     -- Plot was bought (notify all clients)
CreateRemoteEvent("PlotSold")          -- Plot was sold
CreateRemoteEvent("ComputerPlaced")    -- Computer placed on a plot
CreateRemoteEvent("HouseUpgraded")     -- House tier changed
CreateRemoteEvent("DataUpdated")       -- Player's Data balance changed
CreateRemoteEvent("RaidComplete")      -- A raid finished
CreateRemoteEvent("Notification")      -- Show a notification to a player

-- === REMOTE FUNCTIONS (request-response) ===
CreateRemoteFunction("GetPlayerData")  -- Client requests their full data
CreateRemoteFunction("GetPlotInfo")    -- Client requests plot information
CreateRemoteFunction("GetLeaderboard") -- Client requests leaderboard data

print("DataTycoon: All remote events created")
