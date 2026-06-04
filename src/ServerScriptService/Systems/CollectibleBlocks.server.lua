--[[
    CollectibleBlocks.server.lua
    Handles data orb collection — reads/writes leaderstats directly
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = ReplicatedStorage:WaitForChild("Events", 15)
if not Events then warn("DataTycoon: No Events!"); return end

local Notification = Events:WaitForChild("Notification", 10)
local DataUpdated = Events:FindFirstChild("DataUpdated")

-- Create RemoteEvent for orb collection
local CollectOrb = Events:FindFirstChild("CollectOrb")
if not CollectOrb then
    CollectOrb = Instance.new("RemoteEvent")
    CollectOrb.Name = "CollectOrb"
    CollectOrb.Parent = Events
end

print("DataTycoon: CollectOrb ready")

local cooldowns = {}

CollectOrb.OnServerEvent:Connect(function(player)
    -- Cooldown check
    if cooldowns[player.UserId] then return end
    cooldowns[player.UserId] = true
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then cooldowns[player.UserId] = nil; return end
    
    local dataValue = leaderstats:FindFirstChild("Data")
    if not dataValue then cooldowns[player.UserId] = nil; return end
    
    local reward = 5
    dataValue.Value = dataValue.Value + reward
    
    if DataUpdated then
        DataUpdated:FireClient(player, dataValue.Value)
    end
    
    if Notification then
        Notification:FireClient(player, "+" .. reward .. " Data!", "success")
    end
    
    print("DataTycoon: " .. player.Name .. " collected orb (+" .. reward .. ")")
    
    task.delay(1.5, function()
        cooldowns[player.UserId] = nil
    end)
end)

print("DataTycoon: Orb collection ready!")
