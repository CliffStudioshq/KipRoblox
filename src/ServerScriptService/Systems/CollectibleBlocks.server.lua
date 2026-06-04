--[[
    CollectibleBlocks.server.lua
    v0.17 — Simple touch-based orb collection
    Listens for CollectOrb event from client, awards +5 Data
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for Events folder (created by Main.server.lua)
local Events = ReplicatedStorage:WaitForChild("Events", 15)
if not Events then
    warn("CollectibleBlocks: No Events folder found!")
    return
end

-- Get or create the CollectOrb RemoteEvent
local CollectOrb = Events:FindFirstChild("CollectOrb")
if not CollectOrb then
    CollectOrb = Instance.new("RemoteEvent")
    CollectOrb.Name = "CollectOrb"
    CollectOrb.Parent = Events
end

local Notification = Events:FindFirstChild("Notification")
local DataUpdated = Events:FindFirstChild("DataUpdated")

-- Cooldown per player (prevents spam)
local cooldowns = {}

CollectOrb.OnServerEvent:Connect(function(player)
    -- Cooldown check (1 second between collections)
    if cooldowns[player.UserId] then return end
    cooldowns[player.UserId] = true

    -- Get leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        cooldowns[player.UserId] = nil
        return
    end

    local dataValue = leaderstats:FindFirstChild("Data")
    if not dataValue then
        cooldowns[player.UserId] = nil
        return
    end

    -- Award data
    local reward = 5
    dataValue.Value = dataValue.Value + reward

    -- Notify client
    if DataUpdated then
        DataUpdated:FireClient(player, dataValue.Value)
    end

    if Notification then
        Notification:FireClient(player, "+" .. reward .. " Data!", "success")
    end

    print("CollectibleBlocks: " .. player.Name .. " collected orb (+" .. reward .. ")")

    -- Clear cooldown after 1 second
    task.delay(1, function()
        cooldowns[player.UserId] = nil
    end)
end)

print("CollectibleBlocks: Orb collection ready!")
