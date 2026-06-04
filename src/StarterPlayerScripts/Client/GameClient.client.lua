--[[
    GameClient.client.lua — DataTycoon Client
    v0.6 — Full game UI: blocks, land, computers, house upgrades
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("DataTycoon: Client starting...")

-- === CREATE UI ===

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

-- Collect blocks button (top-left, below daily)
local collectBtn = Instance.new("TextButton")
collectBtn.Name = "CollectBtn"
collectBtn.Size = UDim2.new(0, 150, 0, 40)
collectBtn.Position = UDim2.new(0, 10, 0, 70)
collectBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
collectBtn.Text = "⛏️ Collect Blocks"
collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collectBtn.TextSize = 14
collectBtn.Font = Enum.Font.GothamBold
collectBtn.Parent = screenGui

local collectCorner = Instance.new("UICorner")
collectCorner.CornerRadius = UDim.new(0, 8)
collectCorner.Parent = collectBtn

-- Stats button (top-left, below collect)
local statsBtn = Instance.new("TextButton")
statsBtn.Name = "StatsBtn"
statsBtn.Size = UDim2.new(0, 150, 0, 40)
statsBtn.Position = UDim2.new(0, 10, 0, 120)
statsBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
statsBtn.Text = "📊 Stats"
statsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
statsBtn.TextSize = 14
statsBtn.Font = Enum.Font.GothamBold
statsBtn.Parent = screenGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsBtn

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
notifLabel.TextTransparency = 1
notifLabel.Parent = screenGui

-- Stats panel (center, hidden by default)
local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsPanel"
statsFrame.Size = UDim2.new(0, 300, 0, 350)
statsFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
statsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
statsFrame.BackgroundTransparency = 0.1
statsFrame.Visible = false
statsFrame.Parent = screenGui

local statsFrameCorner = Instance.new("UICorner")
statsFrameCorner.CornerRadius = UDim.new(0, 12)
statsFrameCorner.Parent = statsFrame

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, 0, 0, 40)
statsTitle.Position = UDim2.new(0, 0, 0, 5)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "📊 Your Stats"
statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
statsTitle.TextSize = 24
statsTitle.Font = Enum.Font.GothamBold
statsTitle.Parent = statsFrame

local statsClose = Instance.new("TextButton")
statsClose.Size = UDim2.new(0, 30, 0, 30)
statsClose.Position = UDim2.new(1, -35, 0, 5)
statsClose.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
statsClose.Text = "X"
statsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
statsClose.TextSize = 16
statsClose.Font = Enum.Font.GothamBold
statsClose.Parent = statsFrame

local statsCloseCorner = Instance.new("UICorner")
statsCloseCorner.CornerRadius = UDim.new(0, 6)
statsCloseCorner.Parent = statsClose

-- Stats text
local statsText = Instance.new("TextLabel")
statsText.Name = "StatsText"
statsText.Size = UDim2.new(1, -20, 1, -50)
statsText.Position = UDim2.new(0, 10, 0, 45)
statsText.BackgroundTransparency = 1
statsText.Text = "Loading..."
statsText.TextColor3 = Color3.fromRGB(200, 200, 200)
statsText.TextSize = 16
statsText.Font = Enum.Font.Gotham
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.TextWrapped = true
statsText.Parent = statsFrame

-- House upgrade button (inside stats panel)
local upgradeHouseBtn = Instance.new("TextButton")
upgradeHouseBtn.Name = "UpgradeHouseBtn"
upgradeHouseBtn.Size = UDim2.new(0.8, 0, 0, 35)
upgradeHouseBtn.Position = UDim2.new(0.1, 0, 1, -40)
upgradeHouseBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
upgradeHouseBtn.Text = "🏠 Upgrade House"
upgradeHouseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeHouseBtn.TextSize = 14
upgradeHouseBtn.Font = Enum.Font.GothamBold
upgradeHouseBtn.Parent = statsFrame

local upgradeCorner = Instance.new("UICorner")
upgradeCorner.CornerRadius = UDim.new(0, 8)
upgradeCorner.Parent = upgradeHouseBtn

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
    
    for i = 0, 1, 0.1 do
        if notifLabel and notifLabel.Parent then
            notifLabel.TextTransparency = 1 - i
        end
        task.wait(0.03)
    end
    
    task.delay(2, function()
        for i = 0, 1, 0.1 do
            if notifLabel and notifLabel.Parent then
                notifLabel.TextTransparency = i
            end
            task.wait(0.03)
        end
    end)
end

local function UpdateStatsPanel()
    local success, data = pcall(function()
        local Events = ReplicatedStorage:FindFirstChild("Events")
        if Events then
            local getFn = Events:FindFirstChild("GetPlayerData")
            if getFn then
                return getFn:InvokeServer()
            end
        end
        return nil
    end)
    
    if success and data then
        local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        local houseName = houseNames[data.HouseTier] or "Shack"
        local plotCount = data.Plots and #data.Plots or 0
        local computerCount = data.Computers and #data.Computers or 0
        local blocksCollected = data.BlocksCollected or 0
        
        local totalDPS = 1  -- Base passive
        if data.Computers then
            local dpsValues = {2, 8, 30, 120}
            for _, comp in ipairs(data.Computers) do
                totalDPS = totalDPS + (dpsValues[comp.tier] or 0)
            end
        end
        
        statsText.Text = string.format(
            "🏠 House: %s (Tier %d)\n\n"..
            "📦 Plots Owned: %d\n"..
            "💻 Computers: %d\n"..
            "⛏️ Blocks Collected: %d\n\n"..
            "💰 Current Data: %d\n"..
            "📈 Total Earned: %d\n"..
            "💸 Total Spent: %d\n"..
            "⚡ Data/sec: %d",
            houseName, data.HouseTier,
            plotCount,
            computerCount,
            blocksCollected,
            data.Data,
            data.TotalEarned or 0,
            data.TotalSpent or 0,
            totalDPS
        )
        
        -- Update upgrade button
        local nextTier = data.HouseTier + 1
        local houseCosts = {0, 200, 1000, 5000, 25000}
        local houseMaxComputers = {1, 2, 4, 8, 16}
        if nextTier <= 5 then
            upgradeHouseBtn.Text = "🏠 Upgrade: " .. houseNames[nextTier] .. " (" .. houseCosts[nextTier] .. " Data)"
            upgradeHouseBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
        else
            upgradeHouseBtn.Text = "✅ Max House Level!"
            upgradeHouseBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    else
        statsText.Text = "Could not load stats.\nTry again later."
    end
end

-- === LEADERSTATS ===

print("DataTycoon: Waiting for leaderstats...")

local leaderstats = nil
for i = 1, 30 do
    leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then break end
    task.wait(1)
end

if not leaderstats then
    warn("DataTycoon: No leaderstats!")
    dataLabel.Text = "💰 Data: Error"
else
    print("DataTycoon: leaderstats found!")
    
    local dataValue = leaderstats:FindFirstChild("Data")
    if dataValue then
        UpdateDataDisplay(dataValue.Value)
        dataValue.Changed:Connect(function(newValue)
            UpdateDataDisplay(newValue)
        end)
    end
    
    local houseValue = leaderstats:FindFirstChild("House")
    if houseValue then
        local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        houseLabel.Text = "🏠 " .. (houseNames[houseValue.Value] or "Shack")
        houseValue.Changed:Connect(function(newTier)
            houseLabel.Text = "🏠 " .. (houseNames[newTier] or "Shack")
        end)
    end
end

-- === EVENT CONNECTIONS ===

task.spawn(function()
    print("DataTycoon: Waiting for Events...")
    
    local Events = ReplicatedStorage:WaitForChild("Events", 20)
    if not Events then
        warn("DataTycoon: No Events folder!")
        return
    end
    
    print("DataTycoon: Events found!")
    
    -- Daily reward
    local claimEvent = Events:WaitForChild("ClaimDailyReward", 15)
    local claimedEvent = Events:WaitForChild("DailyRewardClaimed", 15)
    local notifEvent = Events:WaitForChild("Notification", 15)
    local collectEvent = Events:WaitForChild("CollectBlocks", 15)
    local purchasePlotEvent = Events:WaitForChild("PurchasePlot", 15)
    local plotPurchasedEvent = Events:WaitForChild("PlotPurchased", 15)
    local computerPlacedEvent = Events:WaitForChild("ComputerPlaced", 15)
    local houseUpgradedEvent = Events:WaitForChild("HouseUpgraded", 15)
    local upgradeHouseEvent = Events:WaitForChild("UpgradeHouse", 15)
    
    -- Daily reward
    if claimEvent and claimedEvent then
        dailyBtn.MouseButton1Click:Connect(function()
            print("DataTycoon: Claiming daily reward...")
            claimEvent:FireServer()
        end)
        
        claimedEvent.OnClientEvent:Connect(function(reward, streak)
            ShowNotification("Day " .. streak .. ": +" .. reward .. " Data!", Color3.fromRGB(100, 255, 100))
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            task.delay(2, function()
                if dailyBtn and dailyBtn.Parent then
                    dailyBtn.Text = "🎁 Daily Reward"
                    dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                end
            end)
        end)
        print("DataTycoon: Daily reward connected!")
    end
    
    -- Collect blocks
    if collectEvent then
        collectBtn.MouseButton1Click:Connect(function()
            print("DataTycoon: Collecting blocks...")
            collectEvent:FireServer(1)
        end)
        print("DataTycoon: Collect blocks connected!")
    end
    
    -- Notifications
    if notifEvent then
        notifEvent.OnClientEvent:Connect(function(message, notifType)
            local color = Color3.fromRGB(255, 255, 255)
            if notifType == "success" then color = Color3.fromRGB(100, 255, 100)
            elseif notifType == "error" then color = Color3.fromRGB(255, 100, 100)
            end
            ShowNotification(message, color)
        end)
    end
    
    -- Plot purchased (other players)
    if plotPurchasedEvent then
        plotPurchasedEvent.OnClientEvent:Connect(function(plotId, ownerId, ownerName)
            if ownerId ~= player.UserId then
                ShowNotification(ownerName .. " bought a plot!", Color3.fromRGB(255, 200, 100))
            end
        end)
    end
    
    -- Computer placed
    if computerPlacedEvent then
        computerPlacedEvent.OnClientEvent:Connect(function(plotId, tier, name)
            ShowNotification(name .. " placed!", Color3.fromRGB(100, 200, 255))
        end)
    end
    
    -- House upgraded
    if houseUpgradedEvent then
        houseUpgradedEvent.OnClientEvent:Connect(function(tier, name)
            ShowNotification("Upgraded to " .. name .. "!", Color3.fromRGB(200, 100, 255))
        end)
    end
    
    -- House upgrade button
    if upgradeHouseEvent then
        upgradeHouseBtn.MouseButton1Click:Connect(function()
            print("DataTycoon: Upgrading house...")
            upgradeHouseEvent:FireServer()
        end)
        print("DataTycoon: House upgrade connected!")
    end
    
    -- Stats panel
    statsBtn.MouseButton1Click:Connect(function()
        statsFrame.Visible = true
        UpdateStatsPanel()
    end)
    
    statsClose.MouseButton1Click:Connect(function()
        statsFrame.Visible = false
    end)
    
    -- Collectible blocks (ProximityPrompt)
    local collectBlockEvent = Events:FindFirstChild("CollectBlock")
    if collectBlockEvent then
        local function SetupBlockPrompt(block)
            if not block:IsA("BasePart") then return end
            local prompt = block:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function()
                    print("DataTycoon: Block collected!")
                    collectBlockEvent:FireServer()
                end)
            end
        end
        
        local blockFolder = workspace:WaitForChild("CollectibleBlocks", 10)
        if blockFolder then
            for _, block in ipairs(blockFolder:GetChildren()) do
                SetupBlockPrompt(block)
            end
            blockFolder.ChildAdded:Connect(function(child)
                task.wait(0.2)
                SetupBlockPrompt(child)
            end)
            print("DataTycoon: Block collection connected!")
        end
    end
    
    -- Purchase plot on click (E key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.E then
            if purchasePlotEvent then
                print("DataTycoon: Trying to buy plot_0_0...")
                purchasePlotEvent:FireServer("plot_0_0")
            end
        end
    end)
    
    print("DataTycoon: All events connected!")
end)

print("DataTycoon: Client ready!")
