--[[
    GameClient.client.lua
    Client-side controller for DataTycoon
    Handles UI, player input, and server communication
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")

-- === UI SETUP ===

-- Create main HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Data display (top-right)
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

-- Notification area (center-top)
local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotificationArea"
notifFrame.Size = UDim2.new(0, 400, 0, 50)
notifFrame.Position = UDim2.new(0.5, -200, 0, 80)
notifFrame.BackgroundTransparency = 1
notifFrame.Parent = screenGui

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotificationLabel"
notifLabel.Size = UDim2.new(1, 0, 1, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextSize = 20
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.5
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.Parent = notifFrame

-- === FUNCTIONS ===

local function UpdateDataDisplay(amount)
    dataLabel.Text = "💰 Data: " .. tostring(amount)
    dataLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
end

local function ShowNotification(message, notifType)
    notifLabel.Text = message
    if notifType == "success" then
        notifLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    elseif notifType == "error" then
        notifLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    task.delay(3, function()
        notifLabel.Text = ""
    end)
end

-- === EVENT CONNECTIONS ===

Events.DataUpdated.OnClientEvent:Connect(function(newAmount)
    UpdateDataDisplay(newAmount)
end)

Events.Notification.OnClientEvent:Connect(function(message, notifType)
    ShowNotification(message, notifType)
end)

Events.PlotPurchased.OnClientEvent:Connect(function(plotId, ownerId)
    if ownerId == player.UserId then
        ShowNotification("You purchased a plot!", "success")
    end
end)

-- === INITIAL DATA LOAD ===

-- Wait for everything to load
task.wait(3)

-- Try to get player data from server
local success, data = pcall(function()
    return Events.GetPlayerData:InvokeServer()
end)

if success and data then
    UpdateDataDisplay(data.Data)
    print("DataTycoon: Client loaded! Data: " .. data.Data)
else
    -- If server data not available, show default
    UpdateDataDisplay(100)
    print("DataTycoon: Client loaded with default data")
end

print("DataTycoon: Client ready!")
