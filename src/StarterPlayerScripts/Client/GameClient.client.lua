--[[
    GameClient.client.lua — DataTycoon Client
    v0.2 — Research-driven redesign
    Key changes:
    - Better HUD with progress indicators
    - Offline income popup
    - Daily reward button
    - Notification system
    - Leaderboard UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")

-- === UI SETUP ===

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Data display (top-right)
local dataFrame = Instance.new("Frame")
dataFrame.Name = "DataDisplay"
dataFrame.Size = UDim2.new(0, 220, 0, 70)
dataFrame.Position = UDim2.new(1, -230, 0, 10)
dataFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
dataFrame.BackgroundTransparency = 0.2
dataFrame.Parent = screenGui

local dataCorner = Instance.new("UICorner")
dataCorner.CornerRadius = UDim.new(0, 10)
dataCorner.Parent = dataFrame

local dataLabel = Instance.new("TextLabel")
dataLabel.Name = "DataLabel"
dataLabel.Size = UDim2.new(1, -10, 0.6, 0)
dataLabel.Position = UDim2.new(0, 5, 0, 5)
dataLabel.BackgroundTransparency = 1
dataLabel.Text = "💰 Data: Loading..."
dataLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
dataLabel.TextSize = 28
dataLabel.Font = Enum.Font.GothamBold
dataLabel.TextXAlignment = Enum.TextXAlignment.Left
dataLabel.Parent = dataFrame

local houseLabel = Instance.new("TextLabel")
houseLabel.Name = "HouseLabel"
houseLabel.Size = UDim2.new(1, -10, 0.3, 0)
houseLabel.Position = UDim2.new(0, 5, 0.6, 0)
houseLabel.BackgroundTransparency = 1
houseLabel.Text = "🏠 Shack"
houseLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
houseLabel.TextSize = 16
houseLabel.Font = Enum.Font.Gotham
houseLabel.TextXAlignment = Enum.TextXAlignment.Left
houseLabel.Parent = dataFrame

-- Notification area (center-top)
local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotificationArea"
notifFrame.Size = UDim2.new(0, 400, 0, 60)
notifFrame.Position = UDim2.new(0.5, -200, 0, 90)
notifFrame.BackgroundTransparency = 1
notifFrame.Parent = screenGui

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotificationLabel"
notifLabel.Size = UDim2.new(1, 0, 1, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextSize = 22
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.5
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.Parent = notifFrame

-- Daily reward button (top-left)
local dailyBtn = Instance.new("TextButton")
dailyBtn.Name = "DailyRewardBtn"
dailyBtn.Size = UDim2.new(0, 150, 0, 50)
dailyBtn.Position = UDim2.new(0, 10, 0, 10)
dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
dailyBtn.Text = "🎁 Daily Reward"
dailyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dailyBtn.TextSize = 16
dailyBtn.Font = Enum.Font.GothamBold
dailyBtn.Parent = screenGui

local dailyCorner = Instance.new("UICorner")
dailyCorner.CornerRadius = UDim.new(0, 8)
dailyCorner.Parent = dailyBtn

-- Offline income popup (center)
local offlineFrame = Instance.new("Frame")
offlineFrame.Name = "OfflineIncome"
offlineFrame.Size = UDim2.new(0, 350, 0, 150)
offlineFrame.Position = UDim2.new(0.5, -175, 0.5, -75)
offlineFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
offlineFrame.BackgroundTransparency = 0.1
offlineFrame.Visible = false
offlineFrame.Parent = screenGui

local offlineCorner = Instance.new("UICorner")
offlineCorner.CornerRadius = UDim.new(0, 12)
offlineCorner.Parent = offlineFrame

local offlineTitle = Instance.new("TextLabel")
offlineTitle.Size = UDim2.new(1, 0, 0.4, 0)
offlineTitle.Position = UDim2.new(0, 0, 0.1, 0)
offlineTitle.BackgroundTransparency = 1
offlineTitle.Text = "💤 Welcome Back!"
offlineTitle.TextColor3 = Color3.fromRGB(255, 255, 100)
offlineTitle.TextSize = 24
offlineTitle.Font = Enum.Font.GothamBold
offlineTitle.Parent = offlineFrame

local offlineAmount = Instance.new("TextLabel")
offlineAmount.Size = UDim2.new(1, 0, 0.3, 0)
offlineAmount.Position = UDim2.new(0, 0, 0.5, 0)
offlineAmount.BackgroundTransparency = 1
offlineAmount.Text = "+0 Data"
offlineAmount.TextColor3 = Color3.fromRGB(0, 255, 100)
offlineAmount.TextSize = 32
offlineAmount.Font = Enum.Font.GothamBold
offlineAmount.Parent = offlineFrame

local offlineClose = Instance.new("TextButton")
offlineClose.Size = UDim2.new(0, 100, 0, 30)
offlineClose.Position = UDim2.new(0.5, -50, 1, -35)
offlineClose.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
offlineClose.Text = "Collect!"
offlineClose.TextColor3 = Color3.fromRGB(255, 255, 255)
offlineClose.TextSize = 16
offlineClose.Font = Enum.Font.GothamBold
offlineClose.Parent = offlineFrame

-- === FUNCTIONS ===

local function UpdateDataDisplay(amount)
    dataLabel.Text = "💰 Data: " .. tostring(amount)
    
    -- Flash effect
    dataLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    task.delay(0.2, function()
        dataLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    end)
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
    
    -- Animate in
    notifLabel.TextTransparency = 1
    local tween = TweenService:Create(notifLabel, TweenInfo.new(0.3), {TextTransparency = 0})
    tween:Play()
    
    task.delay(2.5, function()
        local tweenOut = TweenService:Create(notifLabel, TweenInfo.new(0.5), {TextTransparency = 1})
        tweenOut:Play()
    end)
end

-- === EVENT CONNECTIONS ===

Events.DataUpdated.OnClientEvent:Connect(function(newAmount)
    UpdateDataDisplay(newAmount)
end)

Events.Notification.OnClientEvent:Connect(function(message, notifType)
    ShowNotification(message, notifType)
end)

Events.OfflineIncome.OnClientEvent:Connect(function(amount, timeAway)
    offlineAmount.Text = "+" .. amount .. " Data"
    offlineTitle.Text = "💤 You were away for " .. math.floor(timeAway / 60) .. " minutes!"
    offlineFrame.Visible = true
end)

offlineClose.MouseButton1Click:Connect(function()
    offlineFrame.Visible = false
end)

dailyBtn.MouseButton1Click:Connect(function()
    Events.ClaimDailyReward:FireServer()
end)

Events.DailyRewardClaimed.OnClientEvent:Connect(function(reward, streak)
    ShowNotification("Day " .. streak .. " reward: +" .. reward .. " Data!", "success")
    dailyBtn.Text = "✅ Claimed!"
    dailyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    task.delay(2, function()
        dailyBtn.Text = "🎁 Daily Reward"
        dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    end)
end)

-- === INITIAL DATA LOAD ===

task.wait(2)

local success, data = pcall(function()
    return Events.GetPlayerData:InvokeServer()
end)

if success and data then
    UpdateDataDisplay(data.Data)
    local houseTier = data.HouseTier or 1
    local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
    houseLabel.Text = "🏠 " .. (houseNames[houseTier] or "Shack")
    print("DataTycoon: Client loaded! Data: " .. data.Data)
else
    warn("DataTycoon: Failed to load player data")
    UpdateDataDisplay(0)
end

print("DataTycoon: Client ready!")
