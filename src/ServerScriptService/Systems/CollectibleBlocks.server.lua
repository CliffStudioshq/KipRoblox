--[[
    CollectibleBlocks.server.lua
    Server-side: Creates RemoteEvent and handles block collection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Main.server.lua to create Events folder
local Events = ReplicatedStorage:WaitForChild("Events", 15)
if not Events then
    warn("DataTycoon: No Events folder!")
    return
end

local Notification = Events:WaitForChild("Notification", 10)

-- Create RemoteEvent for block collection
local CollectBlockEvent = Events:FindFirstChild("CollectBlock")
if not CollectBlockEvent then
    CollectBlockEvent = Instance.new("RemoteEvent")
    CollectBlockEvent.Name = "CollectBlock"
    CollectBlockEvent.Parent = Events
end

print("DataTycoon: CollectBlock event ready")

-- Handle collection from client
CollectBlockEvent.OnServerEvent:Connect(function(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end
    
    local dataValue = leaderstats:FindFirstChild("Data")
    if not dataValue then return end
    
    local BLOCK_REWARD = 5
    dataValue.Value = dataValue.Value + BLOCK_REWARD
    
    if Notification then
        Notification:FireClient(player, "+" .. BLOCK_REWARD .. " Data!", "success")
    end
    
    print("DataTycoon: " .. player.Name .. " collected block (+" .. BLOCK_REWARD .. ")")
end)

print("DataTycoon: Block collection handler ready!")
