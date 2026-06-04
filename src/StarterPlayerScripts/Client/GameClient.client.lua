--[[
    GameClient.client.lua — DataTycoon Client
    v0.4 — SIMPLIFIED: Go back to what worked in v0.1
    - Primary data source: leaderstats (server updates it directly)
    - UI created immediately, no waiting for RemoteEvents
    - Daily reward: simple FireServer/OnClientEvent
    - No InvokeServer, no complex retry logic
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("DataTycoon: Client starting...")

-- === CREATE UI IMMEDIATELY ===

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

-- Notification label (center-top)
local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotificationLabel"
notifLabel.Size = UDim2.new(0, 400, 0, 60)
notifLabel.Position = UDim2.new(0.5, -200, 0, 90)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextSize = 22
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.5
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.Parent = screenGui

-- === FUNCTIONS ===

local function UpdateDataDisplay(amount)
    dataLabel.Text = "💰 Data: " .. tostring(amount)
    dataLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    task.delay(0.2, function()
        if dataLabel and dataLabel.Parent then
            dataLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        end
    end)
end

local function ShowNotification(message, color)
    notifLabel.Text = message
    notifLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    notifLabel.TextTransparency = 1
    
    -- Simple fade in
    for i = 0, 1, 0.1 do
        if notifLabel and notifLabel.Parent then
            notifLabel.TextTransparency = 1 - i
        end
        task.wait(0.03)
    end
    
    task.delay(2, function()
        -- Simple fade out
        for i = 0, 1, 0.1 do
            if notifLabel and notifLabel.Parent then
                notifLabel.TextTransparency = i
            end
            task.wait(0.03)
        end
    end)
end

-- === READ DATA FROM LEADERSTATS ===

-- Wait for server to create leaderstats
print("DataTycoon: Waiting for leaderstats...")

local leaderstats = nil
for i = 1, 30 do  -- Wait up to 30 seconds
    leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then break end
    task.wait(1)
end

if not leaderstats then
    warn("DataTycoon: No leaderstats found after 30 seconds!")
    dataLabel.Text = "💰 Data: Error"
else
    print("DataTycoon: leaderstats found!")
    
    local dataValue = leaderstats:FindFirstChild("Data")
    if dataValue then
        UpdateDataDisplay(dataValue.Value)
        print("DataTycoon: Data = " .. dataValue.Value)
        
        -- Update whenever server changes it
        dataValue.Changed:Connect(function(newValue)
            UpdateDataDisplay(newValue)
        end)
    else
        warn("DataTycoon: No Data value in leaderstats!")
    end
    
    local houseValue = leaderstats:FindFirstChild("House")
    if houseValue then
        local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        houseLabel.Text = "🏠 " .. (houseNames[houseValue.Value] or "Shack")
        
        houseValue.Connect(function(newTier)
            houseLabel.Text = "🏠 " .. (houseNames[newTier] or "Shack")
        end)
    end
end

-- === DAILY REWARD (wait for RemoteEvent) ===

task.spawn(function()
    print("DataTycoon: Waiting for daily reward events...")
    
    local Events = ReplicatedStorage:WaitForChild("Events", 15)
    if not Events then
        warn("DataTycoon: No Events folder found!")
        return
    end
    
    local claimEvent = Events:WaitForChild("ClaimDailyReward", 10)
    local claimedEvent = Events:WaitForChild("DailyRewardClaimed", 10)
    local notifEvent = Events:WaitForChild("Notification", 10)
    
    if not claimEvent then
        warn("DataTycoon: ClaimDailyReward event not found!")
        return
    end
    
    print("DataTycoon: Daily reward events ready!")
    
    dailyBtn.MouseButton1Click:Connect(function()
        print("DataTycoon: Claiming daily reward...")
        claimEvent:FireServer()
    end)
    
    if claimedEvent then
        claimedEvent.OnClientEvent:Connect(function(reward, streak)
            ShowNotification("Day " .. streak .. " reward: +" .. reward .. " Data!", Color3.fromRGB(100, 255, 100))
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            task.delay(2, function()
                if dailyBtn and dailyBtn.Parent then
                    dailyBtn.Text = "🎁 Daily Reward"
                    dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                end
            end)
        end)
    end
    
    if notifEvent then
        notifEvent.OnClientEvent:Connect(function(message, notifType)
            local color = Color3.fromRGB(255, 255, 255)
            if notifType == "success" then
                color = Color3.fromRGB(100, 255, 100)
            elseif notifType == "error" then
                color = Color3.fromRGB(255, 100, 100)
            end
            ShowNotification(message, color)
        end)
    end
end)

print("DataTycoon: Client ready!")
