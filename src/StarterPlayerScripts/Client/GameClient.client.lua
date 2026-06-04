--[[
    GameClient.client.lua — DataTycoon Client
    v0.7 — Polished UI overhaul: spacious, modern, clean
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("DataTycoon: Client starting...")

-- === COLOR PALETTE ===
local C = {
    BG_DARK      = Color3.fromRGB(16, 16, 28),
    BG_CARD      = Color3.fromRGB(24, 24, 42),
    BG_HOVER     = Color3.fromRGB(35, 35, 55),
    ACCENT_GREEN = Color3.fromRGB(0, 220, 120),
    ACCENT_BLUE  = Color3.fromRGB(60, 140, 255),
    ACCENT_PURPLE= Color3.fromRGB(140, 80, 255),
    ACCENT_ORANGE= Color3.fromRGB(255, 140, 40),
    ACCENT_RED   = Color3.fromRGB(255, 70, 70),
    ACCENT_CYAN  = Color3.fromRGB(0, 200, 220),
    TEXT_WHITE   = Color3.fromRGB(240, 240, 255),
    TEXT_DIM     = Color3.fromRGB(160, 160, 190),
    TEXT_MUTED   = Color3.fromRGB(100, 100, 130),
    BORDER       = Color3.fromRGB(40, 40, 65),
}

-- === HELPERS ===

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.BORDER
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function Padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 8)
    p.PaddingBottom = UDim.new(0, b or 8)
    p.PaddingLeft = UDim.new(0, l or 12)
    p.PaddingRight = UDim.new(0, r or 12)
    p.Parent = parent
    return p
end

-- === MAIN CONTAINER ===

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.SafeInset = Enum.SafeInset.Top  -- Respect Roblox safe area
screenGui.Parent = playerGui

-- ============================================================
-- TOP BAR (floating card, not edge-to-edge)
-- ============================================================

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(0, 520, 0, 52)
topBar.Position = UDim2.new(0.5, -260, 0, 12)  -- Centered, with top margin
topBar.BackgroundColor3 = C.BG_DARK
topBar.BackgroundTransparency = 0.1
topBar.Parent = screenGui
Corner(topBar, 14)
Stroke(topBar, C.BORDER, 1)

local topBarLayout = Instance.new("UIListLayout")
topBarLayout.FillDirection = Enum.FillDirection.Horizontal
topBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topBarLayout.Padding = UDim.new(0, 16)
topBarLayout.Parent = topBar
Padding(topBar, 0, 0, 20, 20)

-- Data display (inside top bar, left side)
local dataIcon = Instance.new("TextLabel")
dataIcon.Size = UDim2.new(0, 30, 1, 0)
dataIcon.BackgroundTransparency = 1
dataIcon.Text = "💰"
dataIcon.TextSize = 22
dataIcon.Font = Enum.Font.GothamBold
dataIcon.TextColor3 = C.TEXT_WHITE
dataIcon.Parent = topBar

local dataLabel = Instance.new("TextLabel")
dataLabel.Name = "DataLabel"
dataLabel.Size = UDim2.new(0, 160, 1, 0)
dataLabel.BackgroundTransparency = 1
dataLabel.Text = "Loading..."
dataLabel.TextColor3 = C.ACCENT_GREEN
dataLabel.TextSize = 22
dataLabel.Font = Enum.Font.GothamBold
dataLabel.TextXAlignment = Enum.TextXAlignment.Left
dataLabel.Parent = topBar

-- Separator
local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(0, 1, 0, 28)
sep1.BackgroundColor3 = C.BORDER
sep1.BackgroundTransparency = 0.5
sep1.Parent = topBar

-- House display
local houseIcon = Instance.new("TextLabel")
houseIcon.Size = UDim2.new(0, 28, 1, 0)
houseIcon.BackgroundTransparency = 1
houseIcon.Text = "🏠"
houseIcon.TextSize = 20
houseIcon.Font = Enum.Font.GothamBold
houseIcon.TextColor3 = C.TEXT_WHITE
houseIcon.Parent = topBar

local houseLabel = Instance.new("TextLabel")
houseLabel.Name = "HouseLabel"
houseLabel.Size = UDim2.new(0, 130, 1, 0)
houseLabel.BackgroundTransparency = 1
houseLabel.Text = "Shack"
houseLabel.TextColor3 = C.TEXT_DIM
houseLabel.TextSize = 18
houseLabel.Font = Enum.Font.Gotham
houseLabel.TextXAlignment = Enum.TextXAlignment.Left
houseLabel.Parent = topBar

-- Separator
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(0, 1, 0, 28)
sep2.BackgroundColor3 = C.BORDER
sep2.BackgroundTransparency = 0.5
sep2.Parent = topBar

-- DPS display
local dpsLabel = Instance.new("TextLabel")
dpsLabel.Name = "DpsLabel"
dpsLabel.Size = UDim2.new(0, 100, 1, 0)
dpsLabel.BackgroundTransparency = 1
dpsLabel.Text = "⚡ 1/s"
dpsLabel.TextColor3 = C.ACCENT_CYAN
dpsLabel.TextSize = 16
dpsLabel.Font = Enum.Font.GothamBold
dpsLabel.TextXAlignment = Enum.TextXAlignment.Left
dpsLabel.Parent = topBar

-- Push remaining buttons to the right
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 1, 0)  -- Takes remaining space
spacer.BackgroundTransparency = 1
spacer.Parent = topBar

-- Stats button (top bar, right side)
local statsBtn = Instance.new("TextButton")
statsBtn.Name = "StatsBtn"
statsBtn.Size = UDim2.new(0, 100, 0, 36)
statsBtn.BackgroundColor3 = C.BG_CARD
statsBtn.Text = "📊 Stats"
statsBtn.TextColor3 = C.TEXT_WHITE
statsBtn.TextSize = 15
statsBtn.Font = Enum.Font.GothamBold
statsBtn.Parent = topBar
Corner(statsBtn, 8)
Stroke(statsBtn, C.BORDER, 1)

-- Daily reward button (top bar, right side)
local dailyBtn = Instance.new("TextButton")
dailyBtn.Name = "DailyRewardBtn"
dailyBtn.Size = UDim2.new(0, 140, 0, 36)
dailyBtn.BackgroundColor3 = C.ACCENT_ORANGE
dailyBtn.Text = "🎁 Daily Reward"
dailyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dailyBtn.TextSize = 15
dailyBtn.Font = Enum.Font.GothamBold
dailyBtn.Parent = topBar
Corner(dailyBtn, 8)

-- ============================================================
-- LEFT SIDEBAR (action buttons)
-- ============================================================

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 190, 0, 200)
sidebar.Position = UDim2.new(0, 16, 0, 80)
sidebar.BackgroundColor3 = C.BG_CARD
sidebar.BackgroundTransparency = 0.1
sidebar.Parent = screenGui
Corner(sidebar, 14)
Stroke(sidebar, C.BORDER, 1)

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.FillDirection = Enum.FillDirection.Vertical
sidebarLayout.Padding = UDim.new(0, 8)
sidebarLayout.Parent = sidebar
Padding(sidebar, 12, 12, 12, 12)

-- Collect blocks button
local collectBtn = Instance.new("TextButton")
collectBtn.Name = "CollectBtn"
collectBtn.Size = UDim2.new(1, 0, 0, 44)
collectBtn.BackgroundColor3 = C.ACCENT_BLUE
collectBtn.Text = "⛏️  Collect Blocks"
collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collectBtn.TextSize = 15
collectBtn.Font = Enum.Font.GothamBold
collectBtn.Parent = sidebar
Corner(collectBtn, 8)

-- Buy plot button
local buyPlotBtn = Instance.new("TextButton")
buyPlotBtn.Name = "BuyPlotBtn"
buyPlotBtn.Size = UDim2.new(1, 0, 0, 44)
buyPlotBtn.BackgroundColor3 = C.ACCENT_GREEN
buyPlotBtn.Text = "📦  Buy Plot [E]"
buyPlotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyPlotBtn.TextSize = 15
buyPlotBtn.Font = Enum.Font.GothamBold
buyPlotBtn.Parent = sidebar
Corner(buyPlotBtn, 8)

-- Place computer button
local placeCompBtn = Instance.new("TextButton")
placeCompBtn.Name = "PlaceCompBtn"
placeCompBtn.Size = UDim2.new(1, 0, 0, 44)
placeCompBtn.BackgroundColor3 = C.ACCENT_PURPLE
placeCompBtn.Text = "💻  Place Computer"
placeCompBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
placeCompBtn.TextSize = 15
placeCompBtn.Font = Enum.Font.GothamBold
placeCompBtn.Parent = sidebar
Corner(placeCompBtn, 8)

-- ============================================================
-- NOTIFICATION AREA (center-top, below top bar)
-- ============================================================

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotificationLabel"
notifLabel.Size = UDim2.new(0, 420, 0, 48)
notifLabel.Position = UDim2.new(0.5, -210, 0, 76)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = C.TEXT_WHITE
notifLabel.TextSize = 20
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.6
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.TextTransparency = 1
notifLabel.Parent = screenGui

-- ============================================================
-- STATS PANEL (center, hidden by default)
-- ============================================================

local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsPanel"
statsFrame.Size = UDim2.new(0, 340, 0, 420)
statsFrame.Position = UDim2.new(0.5, -170, 0.5, -210)
statsFrame.BackgroundColor3 = C.BG_DARK
statsFrame.BackgroundTransparency = 0.05
statsFrame.Visible = false
statsFrame.Parent = screenGui
Corner(statsFrame, 16)
Stroke(statsFrame, C.BORDER, 1)

-- Title bar
local statsTitleBar = Instance.new("Frame")
statsTitleBar.Size = UDim2.new(1, 0, 0, 48)
statsTitleBar.BackgroundColor3 = C.BG_CARD
statsTitleBar.Parent = statsFrame
Corner(statsTitleBar, 16)

-- Fix bottom corners of title bar
local statsTitleFix = Instance.new("Frame")
statsTitleFix.Size = UDim2.new(1, 0, 0, 16)
statsTitleFix.Position = UDim2.new(0, 0, 1, -16)
statsTitleFix.BackgroundColor3 = C.BG_CARD
statsTitleFix.BorderSizePixel = 0
statsTitleFix.Parent = statsTitleBar

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, -50, 1, 0)
statsTitle.Position = UDim2.new(0, 16, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "📊  Your Stats"
statsTitle.TextColor3 = C.TEXT_WHITE
statsTitle.TextSize = 20
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Parent = statsTitleBar

local statsClose = Instance.new("TextButton")
statsClose.Size = UDim2.new(0, 32, 0, 32)
statsClose.Position = UDim2.new(1, -40, 0.5, -16)
statsClose.BackgroundColor3 = C.ACCENT_RED
statsClose.Text = "✕"
statsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
statsClose.TextSize = 16
statsClose.Font = Enum.Font.GothamBold
statsClose.Parent = statsFrame
Corner(statsClose, 8)

-- Stats content
local statsContent = Instance.new("ScrollingFrame")
statsContent.Size = UDim2.new(1, -24, 1, -110)
statsContent.Position = UDim2.new(0, 12, 0, 56)
statsContent.BackgroundTransparency = 1
statsContent.ScrollBarThickness = 4
statsContent.ScrollBarImageColor3 = C.BORDER
statsContent.CanvasSize = UDim2.new(0, 0, 0, 300)
statsContent.Parent = statsFrame

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 6)
statsLayout.Parent = statsContent
Padding(statsContent, 0, 0, 0, 0)

-- We'll populate these dynamically
local statsEntries = {}

local function CreateStatRow(label, value, icon, color)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = C.BG_CARD
    row.BackgroundTransparency = 0.3
    row.Parent = statsContent
    Corner(row, 8)
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 30, 1, 0)
    iconLabel.Position = UDim2.new(0, 8, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon or ""
    iconLabel.TextSize = 18
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextColor3 = C.TEXT_WHITE
    iconLabel.Parent = row
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.55, -30, 1, 0)
    nameLabel.Position = UDim2.new(0, 38, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.TextColor3 = C.TEXT_DIM
    nameLabel.TextSize = 15
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Size = UDim2.new(0.45, -8, 1, 0)
    valueLabel.Position = UDim2.new(0.55, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = value or "0"
    valueLabel.TextColor3 = color or C.TEXT_WHITE
    valueLabel.TextSize = 16
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row
    
    return valueLabel
end

-- Create stat rows
local statHouseVal  = CreateStatRow("House Tier", "Shack", "🏠", C.ACCENT_ORANGE)
local statPlotsVal  = CreateStatRow("Plots Owned", "0", "📦", C.ACCENT_GREEN)
local statCompVal   = CreateStatRow("Computers", "0", "💻", C.ACCENT_BLUE)
local statBlocksVal = CreateStatRow("Blocks Collected", "0", "⛏️", C.ACCENT_CYAN)
local statDataVal   = CreateStatRow("Current Data", "0", "💰", C.ACCENT_GREEN)
local statEarnedVal = CreateStatRow("Total Earned", "0", "📈", C.TEXT_DIM)
local statSpentVal  = CreateStatRow("Total Spent", "0", "💸", C.TEXT_DIM)
local statDpsVal    = CreateStatRow("Data / Second", "1", "⚡", C.ACCENT_CYAN)

-- Upgrade house button (bottom of stats panel)
local upgradeHouseBtn = Instance.new("TextButton")
upgradeHouseBtn.Name = "UpgradeHouseBtn"
upgradeHouseBtn.Size = UDim2.new(1, -24, 0, 44)
upgradeHouseBtn.Position = UDim2.new(0, 12, 1, -52)
upgradeHouseBtn.BackgroundColor3 = C.ACCENT_PURPLE
upgradeHouseBtn.Text = "🏠  Upgrade House"
upgradeHouseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeHouseBtn.TextSize = 16
upgradeHouseBtn.Font = Enum.Font.GothamBold
upgradeHouseBtn.Parent = statsFrame
Corner(upgradeHouseBtn, 10)

-- ============================================================
-- FUNCTIONS
-- ============================================================

local function UpdateDataDisplay(amount)
    dataLabel.Text = tostring(amount)
    dataLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    task.delay(0.15, function()
        if dataLabel and dataLabel.Parent then
            dataLabel.TextColor3 = C.ACCENT_GREEN
        end
    end)
end

local function ShowNotification(message, color)
    notifLabel.Text = message
    notifLabel.TextColor3 = color or C.TEXT_WHITE
    notifLabel.TextTransparency = 1
    
    task.spawn(function()
        for i = 0, 1, 0.12 do
            if notifLabel and notifLabel.Parent then
                notifLabel.TextTransparency = 1 - i
            end
            task.wait(0.025)
        end
        task.delay(1.8, function()
            for i = 0, 1, 0.08 do
                if notifLabel and notifLabel.Parent then
                    notifLabel.TextTransparency = i
                end
                task.wait(0.025)
            end
        end)
    end)
end

local function UpdateStatsPanel()
    local success, data = pcall(function()
        local Ev = ReplicatedStorage:FindFirstChild("Events")
        if Ev then
            local fn = Ev:FindFirstChild("GetPlayerData")
            if fn then return fn:InvokeServer() end
        end
        return nil
    end)
    
    if success and data then
        local houseNames = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        local houseName = houseNames[data.HouseTier] or "Shack"
        local plotCount = data.Plots and #data.Plots or 0
        local compCount = data.Computers and #data.Computers or 0
        local blocks = data.BlocksCollected or 0
        
        local totalDPS = 1
        if data.Computers then
            local dpsVals = {2, 8, 30, 120}
            for _, c in ipairs(data.Computers) do
                totalDPS = totalDPS + (dpsVals[c.tier] or 0)
            end
        end
        
        statHouseVal.Text = houseName .. " (T" .. data.HouseTier .. ")"
        statPlotsVal.Text = tostring(plotCount)
        statCompVal.Text = tostring(compCount)
        statBlocksVal.Text = tostring(blocks)
        statDataVal.Text = tostring(data.Data)
        statEarnedVal.Text = tostring(data.TotalEarned or 0)
        statSpentVal.Text = tostring(data.TotalSpent or 0)
        statDpsVal.Text = tostring(totalDPS) .. "/s"
        
        -- Update DPS in top bar too
        dpsLabel.Text = "⚡ " .. totalDPS .. "/s"
        
        -- Upgrade button
        local nextTier = data.HouseTier + 1
        local houseCosts = {0, 200, 1000, 5000, 25000}
        if nextTier <= 5 then
            upgradeHouseBtn.Text = "🏠  " .. houseNames[nextTier] .. "  —  " .. houseCosts[nextTier] .. " Data"
            upgradeHouseBtn.BackgroundColor3 = C.ACCENT_PURPLE
        else
            upgradeHouseBtn.Text = "✅  Max Level Reached"
            upgradeHouseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        end
    else
        statDataVal.Text = "Error"
    end
end

-- ============================================================
-- LEADERSTATS
-- ============================================================

print("DataTycoon: Waiting for leaderstats...")

local leaderstats = nil
for i = 1, 30 do
    leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then break end
    task.wait(1)
end

if not leaderstats then
    warn("DataTycoon: No leaderstats!")
    dataLabel.Text = "Error"
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
        houseLabel.Text = houseNames[houseValue.Value] or "Shack"
        houseValue.Changed:Connect(function(newTier)
            houseLabel.Text = houseNames[newTier] or "Shack"
        end)
    end
end

-- ============================================================
-- EVENT CONNECTIONS
-- ============================================================

task.spawn(function()
    print("DataTycoon: Waiting for Events...")
    
    local Events = ReplicatedStorage:WaitForChild("Events", 20)
    if not Events then
        warn("DataTycoon: No Events folder!")
        return
    end
    
    print("DataTycoon: Events found!")
    
    local claimEvent = Events:WaitForChild("ClaimDailyReward", 15)
    local claimedEvent = Events:WaitForChild("DailyRewardClaimed", 15)
    local notifEvent = Events:WaitForChild("Notification", 15)
    local collectEvent = Events:WaitForChild("CollectBlocks", 15)
    local purchasePlotEvent = Events:WaitForChild("PurchasePlot", 15)
    local plotPurchasedEvent = Events:WaitForChild("PlotPurchased", 15)
    local computerPlacedEvent = Events:WaitForChild("ComputerPlaced", 15)
    local houseUpgradedEvent = Events:WaitForChild("HouseUpgraded", 15)
    local upgradeHouseEvent = Events:WaitForChild("UpgradeHouse", 15)
    local placeComputerEvent = Events:WaitForChild("PlaceComputer", 15)
    local collectBlockEvent = Events:FindFirstChild("CollectBlock")
    
    -- Daily reward
    if claimEvent and claimedEvent then
        dailyBtn.MouseButton1Click:Connect(function()
            claimEvent:FireServer()
        end)
        claimedEvent.OnClientEvent:Connect(function(reward, streak)
            ShowNotification("Day " .. streak .. ": +" .. reward .. " Data!", Color3.fromRGB(100, 255, 150))
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            task.delay(2, function()
                if dailyBtn and dailyBtn.Parent then
                    dailyBtn.Text = "🎁 Daily Reward"
                    dailyBtn.BackgroundColor3 = C.ACCENT_ORANGE
                end
            end)
        end)
        print("DataTycoon: Daily reward connected")
    end
    
    -- Collect blocks button
    if collectEvent then
        collectBtn.MouseButton1Click:Connect(function()
            collectEvent:FireServer(1)
        end)
        print("DataTycoon: Collect blocks connected")
    end
    
    -- Buy plot button + E key
    if purchasePlotEvent then
        local function BuyPlot()
            purchasePlotEvent:FireServer("plot_0_0")
        end
        buyPlotBtn.MouseButton1Click:Connect(BuyPlot)
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.E then
                BuyPlot()
            end
        end)
        print("DataTycoon: Buy plot connected")
    end
    
    -- Place computer button
    if placeComputerEvent then
        placeCompBtn.MouseButton1Click:Connect(function()
            placeComputerEvent:FireServer("plot_0_0", 1)
        end)
        print("DataTycoon: Place computer connected")
    end
    
    -- Notifications
    if notifEvent then
        notifEvent.OnClientEvent:Connect(function(message, notifType)
            local color = C.TEXT_WHITE
            if notifType == "success" then color = Color3.fromRGB(100, 255, 150)
            elseif notifType == "error" then color = Color3.fromRGB(255, 100, 100)
            end
            ShowNotification(message, color)
        end)
    end
    
    -- Plot purchased
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
            ShowNotification(name .. " placed!", C.ACCENT_BLUE)
        end)
    end
    
    -- House upgraded
    if houseUpgradedEvent then
        houseUpgradedEvent.OnClientEvent:Connect(function(tier, name)
            ShowNotification("Upgraded to " .. name .. "!", C.ACCENT_PURPLE)
        end)
    end
    
    -- House upgrade button
    if upgradeHouseEvent then
        upgradeHouseBtn.MouseButton1Click:Connect(function()
            upgradeHouseEvent:FireServer()
        end)
        print("DataTycoon: House upgrade connected")
    end
    
    -- Stats panel
    statsBtn.MouseButton1Click:Connect(function()
        statsFrame.Visible = not statsFrame.Visible
        if statsFrame.Visible then
            UpdateStatsPanel()
        end
    end)
    statsClose.MouseButton1Click:Connect(function()
        statsFrame.Visible = false
    end)
    
    -- Collectible blocks (ProximityPrompt)
    if collectBlockEvent then
        local function SetupBlockPrompt(block)
            if not block:IsA("BasePart") then return end
            local prompt = block:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function()
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
            print("DataTycoon: Block collection connected")
        end
    end
    
    print("DataTycoon: All events connected!")
end)

print("DataTycoon: Client ready!")
