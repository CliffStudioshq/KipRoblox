--[[
    GameClient.client.lua
    Simplified client script
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for Events folder
local Events = ReplicatedStorage:WaitForChild("Events", 10)
if not Events then
    warn("DataTycoon: Events folder not found!")
    return
end

-- Wait for player data to load
task.wait(2)

-- Create HUD
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Data display
local dataFrame = Instance.new("Frame")
dataFrame.Name = "DataDisplay"
dataFrame.Size = UDim2.new(0, 200, 0, 60)
dataFrame.Position = UDim2.new(1, -210, 0, 10)
dataFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
dataFrame.BackgroundTransparency = 0.3
dataFrame.Parent = screenGui

local dataCorner = Instance.new("UICorner")
dataCorner.CornerRadius = UDim.new(0, 8)
dataCorner.Parent = dataFrame

local dataLabel = Instance.new("TextLabel")
dataLabel.Name = "DataLabel"
dataLabel.Size = UDim2.new(1, 0, 1, 0)
dataLabel.BackgroundTransparency = 1
dataLabel.Text = "💰 Data: Loading..."
dataLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
dataLabel.TextSize = 24
dataLabel.Font = Enum.Font.GothamBold
dataLabel.Parent = dataFrame

-- Get data from server
local success, data = pcall(function()
    return Events.GetPlayerData:InvokeServer()
end)

if success and data then
    dataLabel.Text = "💰 Data: " .. tostring(data.Data)
    print("DataTycoon: Client loaded! Data: " .. data.Data)
else
    -- Fallback: try to read from leaderstats
    task.wait(1)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataLabel.Text = "💰 Data: " .. tostring(dataValue.Value)
        end
    end
    print("DataTycoon: Client loaded (fallback)")
end
