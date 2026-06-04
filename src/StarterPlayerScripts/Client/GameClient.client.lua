--[[
    GameClient.client.lua — DataTycoon Client
    v0.3 — Bug fixes: Data loading retry, Daily reward ready check
    Fixes:
    - Data display: retry InvokeServer up to 5x, fallback to leaderstats
    - Daily reward: wait for all RemoteEvents before enabling button
    - Added debug prints so we can see what's happening
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for server to create all RemoteEvents
print("DataTycoon: Waiting for RemoteEvents...")
local Events = ReplicatedStorage:WaitForChild("Events", 15)
if not Events then
    warn("DataTycoon: FAILED to find Events folder!")
    return
end

-- Wait for specific events we need
local dataUpdated = Events:WaitForChild("DataUpdated", 10)
local getPlayerData = Events:WaitForChild("GetPlayerData", 10)
local claimDailyReward = Events:WaitForChild("ClaimDailyReward", 10)
local dailyRewardClaimed = Events:WaitForChild("DailyRewardClaimed", 10)
local notification = Events:WaitForChild("Notification", 10)
local offlineIncome = Events:WaitForChild("OfflineIncome", 10)

if not (dataUpdated and getPlayerData and claimDailyReward and dailyRewardClaimed) then
    warn("DataTycoon: Some RemoteEvents missing!")
    warn("  DataUpdated:", dataUpdated ~= nil)
    warn("  GetPlayerData:", getPlayerData ~= nil)
    warn("  ClaimDailyReward:", claimDailyReward ~= nil)
    warn("  DailyRewardClaimed:", dailyRewardClaimed ~= nil)
end

print("DataTycoon: All RemoteEvents found!")

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
dailyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
dailyBtn.Text = "🎁 Loading..."
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
        if dataLabel and dataLabel.Parent then
            dataLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        end
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
        if notifLabel and notifLabel.Parent then
            local tweenOut = TweenService:Create(notifLabel, TweenInfo.new(0.5), {TextTransparency = 1})
            tweenOut:Play()
        end
    end)
end

-- === INITIAL DATA LOAD (with retries) ===

print("DataTycoon: Starting data load...")

local loadedData = false

-- Try InvokeServer up to 5 times
for attempt = 1, 5 do
    local success, data = pcall(function()
        return getPlayerData:InvokeServer()
    end)
    
    print("DataTycoon: Data load attempt " .. attempt .. " - success:", success, "data:", data ~= nil)
    
    if success and data then
        UpdateDataDisplay(data.Data)
        local houseTier = data.HouseTier or 1
        local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        houseLabel.Text = "🏠 " .. (houseNames[houseTier] or "Shack")
        print("DataTycoon: Client loaded! Data: " .. data.Data .. " House: " .. houseTier)
        loadedData = true
        break
    end
    
    if attempt < 5 then
        task.wait(1)  -- Wait 1 second between retries
    end
end

-- Fallback: read from leaderstats if InvokeServer failed
if not loadedData then
    print("DataTycoon: InvokeServer failed, trying leaderstats fallback...")
    task.wait(1)
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            UpdateDataDisplay(dataValue.Value)
            print("DataTycoon: Got data from leaderstats: " .. dataValue.Value)
            loadedData = true
        end
    end
end

-- Last resort: show 0
if not loadedData then
    warn("DataTycoon: Could not load data from any source!")
    UpdateDataDisplay(0)
end

-- === ENABLE DAILY REWARD BUTTON ===

dailyBtn.Text = "🎁 Daily Reward"
dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
print("DataTycoon: Daily reward button enabled!")

-- === EVENT CONNECTIONS ===

dataUpdated.OnClientEvent:Connect(function(newAmount)
    UpdateDataDisplay(newAmount)
end)

if notification then
    notification.OnClientEvent:Connect(function(message, notifType)
        ShowNotification(message, notifType)
    end)
end

if offlineIncome then
    offlineIncome.OnClientEvent:Connect(function(amount, timeAway)
        offlineAmount.Text = "+" .. amount .. " Data"
        offlineTitle.Text = "💤 You were away for " .. math.floor(timeAway / 60) .. " minutes!"
        offlineFrame.Visible = true
    end)
end

offlineClose.MouseButton1Click:Connect(function()
    offlineFrame.Visible = false
end)

dailyBtn.MouseButton1Click:Connect(function()
    print("DataTycoon: Daily reward clicked!")
    if claimDailyReward then
        claimDailyReward:FireServer()
        print("DataTycoon: Fired ClaimDailyReward")
    else
        warn("DataTycoon: ClaimDailyReward event not found!")
    end
end)

if dailyRewardClaimed then
    dailyRewardClaimed.OnClientEvent:Connect(function(reward, streak)
        ShowNotification("Day " .. streak .. " reward: +" .. reward .. " Data!", "success")
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

-- Also update from leaderstats changes as a backup
task.spawn(function()
    task.wait(3)  -- Give initial load a head start
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Changed:Connect(function(newValue)
                UpdateDataDisplay(newValue)
            end)
            print("DataTycoon: Connected to leaderstats Data.Changed")
        end
    end
end)

print("DataTycoon: Client ready!")
