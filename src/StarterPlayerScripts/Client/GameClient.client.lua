--[[
    GameClient.client.lua — DataTycoon Client
    v0.9 — Reliable GUI, fixed data tracking, clean layout
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("DataTycoon: Client starting...")

-- === COLOR PALETTE ===
local C = {
    BG_DARK      = Color3.fromRGB(12, 12, 22),
    BG_CARD      = Color3.fromRGB(20, 20, 38),
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
local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
    return c
end

local function Stroke(p, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or C.BORDER
    s.Thickness = thick or 1
    s.Parent = p
    return s
end

-- === SCREEN GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true  -- Ignore safe area, we handle it manually
screenGui.Parent = playerGui

-- ============================================================
-- DATA BAR (top-center, floating pill)
-- ============================================================

local dataBar = Instance.new("Frame")
dataBar.Name = "DataBar"
dataBar.Size = UDim2.new(0, 400, 0, 48)
dataBar.Position = UDim2.new(0.5, -200, 0, 16)
dataBar.BackgroundColor3 = C.BG_DARK
dataBar.BackgroundTransparency = 0.08
dataBar.Parent = screenGui
Corner(dataBar, 24)
Stroke(dataBar, C.BORDER, 1)

local dataBarLayout = Instance.new("UIListLayout")
dataBarLayout.FillDirection = Enum.FillDirection.Horizontal
dataBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dataBarLayout.Padding = UDim.new(0, 0)
dataBarLayout.Parent = dataBar

local dataBarPadding = Instance.new("UIPadding")
dataBarPadding.PaddingLeft = UDim.new(0, 20)
dataBarPadding.PaddingRight = UDim.new(0, 20)
dataBarPadding.Parent = dataBar

-- Data amount
local dataLabel = Instance.new("TextLabel")
dataLabel.Name = "DataLabel"
dataLabel.Size = UDim2.new(0, 140, 1, 0)
dataLabel.BackgroundTransparency = 1
dataLabel.Text = "💰  Loading..."
dataLabel.TextColor3 = C.ACCENT_GREEN
dataLabel.TextSize = 20
dataLabel.Font = Enum.Font.GothamBold
dataLabel.TextXAlignment = Enum.TextXAlignment.Left
dataLabel.Parent = dataBar

-- Separator
local sep = Instance.new("Frame")
sep.Size = UDim2.new(0, 1, 0, 24)
sep.BackgroundColor3 = C.BORDER
sep.BackgroundTransparency = 0.4
sep.Parent = dataBar

-- House
local houseLabel = Instance.new("TextLabel")
houseLabel.Name = "HouseLabel"
houseLabel.Size = UDim2.new(0, 100, 1, 0)
houseLabel.BackgroundTransparency = 1
houseLabel.Text = "🏠 Shack"
houseLabel.TextColor3 = C.TEXT_DIM
houseLabel.TextSize = 16
houseLabel.Font = Enum.Font.GothamBold
houseLabel.TextXAlignment = Enum.TextXAlignment.Left
houseLabel.Parent = dataBar

-- Separator
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(0, 1, 0, 24)
sep2.BackgroundColor3 = C.BORDER
sep2.BackgroundTransparency = 0.4
sep2.Parent = dataBar

-- DPS
local dpsLabel = Instance.new("TextLabel")
dpsLabel.Name = "DpsLabel"
dpsLabel.Size = UDim2.new(0, 80, 1, 0)
dpsLabel.BackgroundTransparency = 1
dpsLabel.Text = "⚡ 1/s"
dpsLabel.TextColor3 = C.ACCENT_CYAN
dpsLabel.TextSize = 15
dpsLabel.Font = Enum.Font.GothamBold
dpsLabel.TextXAlignment = Enum.TextXAlignment.Left
dpsLabel.Parent = dataBar

-- ============================================================
-- LEFT SIDEBAR (action buttons)
-- ============================================================

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 170, 0, 0)
sidebar.Position = UDim2.new(0, 16, 0, 80)
sidebar.BackgroundColor3 = C.BG_CARD
sidebar.BackgroundTransparency = 0.08
sidebar.AutomaticSize = Enum.AutomaticSize.Y
sidebar.Parent = screenGui
Corner(sidebar, 14)
Stroke(sidebar, C.BORDER, 1)

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 8)
sidebarLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 12)
sidebarPad.PaddingBottom = UDim.new(0, 12)
sidebarPad.PaddingLeft = UDim.new(0, 12)
sidebarPad.PaddingRight = UDim.new(0, 12)
sidebarPad.Parent = sidebar

local function MakeSidebarButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = sidebar
    Corner(btn, 10)
    return btn
end

local dailyBtn  = MakeSidebarButton("🎁  Daily Reward", C.ACCENT_ORANGE)
local collectBtn = MakeSidebarButton("⛏️  Collect Block", C.ACCENT_BLUE)
local buyPlotBtn = MakeSidebarButton("📦  Buy Plot [E]", C.ACCENT_GREEN)
local placeCompBtn = MakeSidebarButton("💻  Place Computer", C.ACCENT_PURPLE)
local statsBtn  = MakeSidebarButton("📊  Stats", Color3.fromRGB(60, 60, 90))

-- ============================================================
-- NOTIFICATION (center-top)
-- ============================================================

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "NotificationLabel"
notifLabel.Size = UDim2.new(0, 400, 0, 40)
notifLabel.Position = UDim2.new(0.5, -200, 0, 76)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = C.TEXT_WHITE
notifLabel.TextSize = 18
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.6
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.TextTransparency = 1
notifLabel.Parent = screenGui

-- ============================================================
-- STATS PANEL (hidden)
-- ============================================================

local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsPanel"
statsFrame.Size = UDim2.new(0, 320, 0, 400)
statsFrame.Position = UDim2.new(0.5, -160, 0.5, -200)
statsFrame.BackgroundColor3 = C.BG_DARK
statsFrame.BackgroundTransparency = 0.05
statsFrame.Visible = false
statsFrame.Parent = screenGui
Corner(statsFrame, 16)
Stroke(statsFrame, C.BORDER, 1)

-- Title
local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, -50, 0, 44)
statsTitle.Position = UDim2.new(0, 16, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "📊  Your Stats"
statsTitle.TextColor3 = C.TEXT_WHITE
statsTitle.TextSize = 20
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Parent = statsFrame

-- Close button
local statsClose = Instance.new("TextButton")
statsClose.Size = UDim2.new(0, 30, 0, 30)
statsClose.Position = UDim2.new(1, -38, 0, 7)
statsClose.BackgroundColor3 = C.ACCENT_RED
statsClose.Text = "✕"
statsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
statsClose.TextSize = 14
statsClose.Font = Enum.Font.GothamBold
statsClose.Parent = statsFrame
Corner(statsClose, 8)

-- Content scroll
local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Size = UDim2.new(1, -24, 1, -100)
statsScroll.Position = UDim2.new(0, 12, 0, 48)
statsScroll.BackgroundTransparency = 1
statsScroll.ScrollBarThickness = 4
statsScroll.ScrollBarImageColor3 = C.BORDER
statsScroll.CanvasSize = UDim2.new(0, 0, 0, 320)
statsScroll.Parent = statsFrame

local statsList = Instance.new("UIListLayout")
statsList.Padding = UDim2.new(0, 0, 0, 6)
statsList.Parent = statsScroll

local function AddStatRow(icon, label, value, valColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = C.BG_CARD
    row.BackgroundTransparency = 0.3
    row.Parent = statsScroll
    Corner(row, 8)
    
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 28, 1, 0)
    ic.Position = UDim2.new(0, 8, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text = icon
    ic.TextSize = 16
    ic.Font = Enum.Font.GothamBold
    ic.TextColor3 = C.TEXT_WHITE
    ic.Parent = row
    
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(0.55, -30, 1, 0)
    nl.Position = UDim2.new(0, 36, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text = label
    nl.TextColor3 = C.TEXT_DIM
    nl.TextSize = 14
    nl.Font = Enum.Font.Gotham
    nl.TextXAlignment = Enum.TextXAlignment.Left
    nl.Parent = row
    
    local vl = Instance.new("TextLabel")
    vl.Name = "Value"
    vl.Size = UDim2.new(0.45, -8, 1, 0)
    vl.Position = UDim2.new(0.55, 0, 0, 0)
    vl.BackgroundTransparency = 1
    vl.Text = value
    vl.TextColor3 = valColor or C.TEXT_WHITE
    vl.TextSize = 15
    vl.Font = Enum.Font.GothamBold
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = row
    
    return vl
end

local sHouse  = AddStatRow("🏠", "House", "Shack", C.ACCENT_ORANGE)
local sPlots  = AddStatRow("📦", "Plots Owned", "0", C.ACCENT_GREEN)
local sComps  = AddStatRow("💻", "Computers", "0", C.ACCENT_BLUE)
local sBlocks = AddStatRow("⛏️", "Blocks Collected", "0", C.ACCENT_CYAN)
local sData   = AddStatRow("💰", "Current Data", "0", C.ACCENT_GREEN)
local sEarned = AddStatRow("📈", "Total Earned", "0", C.TEXT_DIM)
local sSpent  = AddStatRow("💸", "Total Spent", "0", C.TEXT_DIM)
local sDps    = AddStatRow("⚡", "Data / Second", "1/s", C.ACCENT_CYAN)

-- Upgrade button
local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size = UDim2.new(1, -24, 0, 42)
upgradeBtn.Position = UDim2.new(0, 12, 1, -50)
upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
upgradeBtn.Text = "🏠  Upgrade House"
upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeBtn.TextSize = 15
upgradeBtn.Font = Enum.Font.GothamBold
upgradeBtn.Parent = statsFrame
Corner(upgradeBtn, 10)

-- ============================================================
-- FUNCTIONS
-- ============================================================

local currentData = 0

local function UpdateDataDisplay(amount)
    currentData = amount
    dataLabel.Text = "💰  " .. tostring(amount)
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
        for i = 0, 1, 0.1 do
            if notifLabel and notifLabel.Parent then
                notifLabel.TextTransparency = 1 - i
            end
            task.wait(0.025)
        end
        task.delay(1.5, function()
            for i = 0, 1, 0.08 do
                if notifLabel and notifLabel.Parent then
                    notifLabel.TextTransparency = i
                end
                task.wait(0.025)
            end
        end)
    end)
end

local function RefreshStats()
    local ok, data = pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("Events")
        if ev then
            local fn = ev:FindFirstChild("GetPlayerData")
            if fn then return fn:InvokeServer() end
        end
        return nil
    end)
    if ok and data then
        local names = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        local n = names[data.HouseTier] or "Shack"
        sHouse.Text = n .. " (T" .. data.HouseTier .. ")"
        sPlots.Text = tostring(data.Plots and #data.Plots or 0)
        sComps.Text = tostring(data.Computers and #data.Computers or 0)
        sBlocks.Text = tostring(data.BlocksCollected or 0)
        sData.Text = tostring(data.Data)
        sEarned.Text = tostring(data.TotalEarned or 0)
        sSpent.Text = tostring(data.TotalSpent or 0)
        local dps = 1
        if data.Computers then
            local dv = {2, 8, 30, 120}
            for _, c in ipairs(data.Computers) do dps = dps + (dv[c.tier] or 0) end
        end
        sDps.Text = tostring(dps) .. "/s"
        dpsLabel.Text = "⚡ " .. dps .. "/s"
        local nt = data.HouseTier + 1
        if nt <= 5 then
            upgradeBtn.Text = "🏠  " .. names[nt] .. "  —  " .. ({0,200,1000,5000,25000})[nt] .. " Data"
            upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
        else
            upgradeBtn.Text = "✅  Max Level"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        end
    end
end

-- ============================================================
-- DATA TRACKING — Multiple fallback methods
-- ============================================================

print("DataTycoon: Setting up data tracking...")

-- Method 1: leaderstats (primary)
task.spawn(function()
    local ls = nil
    for i = 1, 30 do
        ls = player:FindFirstChild("leaderstats")
        if ls then break end
        task.wait(0.5)
    end
    if not ls then
        warn("DataTycoon: No leaderstats after 15s!")
        return
    end
    print("DataTycoon: leaderstats found")
    
    local dv = ls:FindFirstChild("Data")
    if dv then
        UpdateDataDisplay(dv.Value)
        print("DataTycoon: Initial data = " .. dv.Value)
        dv.Changed:Connect(function(v)
            UpdateDataDisplay(v)
        end)
        print("DataTycoon: Connected to Data.Changed")
    else
        warn("DataTycoon: No Data in leaderstats")
    end
    
    local hv = ls:FindFirstChild("House")
    if hv then
        local names = {"Shack", "Small House", "Modern House", "Tech Villa", "Mega Compound"}
        houseLabel.Text = "🏠 " .. (names[hv.Value] or "Shack")
        hv.Changed:Connect(function(v)
            houseLabel.Text = "🏠 " .. (names[v] or "Shack")
        end)
    end
end)

-- Method 2: RemoteEvent DataUpdated (backup)
task.spawn(function()
    local ev = ReplicatedStorage:WaitForChild("Events", 15)
    if ev then
        local du = ev:WaitForChild("DataUpdated", 10)
        if du then
            du.OnClientEvent:Connect(function(amount)
                UpdateDataDisplay(amount)
            end)
            print("DataTycoon: Connected to DataUpdated event")
        end
    end
end)

-- Method 3: Poll leaderstats every 2s (last resort)
task.spawn(function()
    task.wait(5)
    while true do
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local dv = ls:FindFirstChild("Data")
            if dv and dv.Value ~= currentData then
                UpdateDataDisplay(dv.Value)
            end
        end
        task.wait(2)
    end
end)

-- ============================================================
-- EVENT CONNECTIONS
-- ============================================================

task.spawn(function()
    print("DataTycoon: Waiting for Events...")
    local Events = ReplicatedStorage:WaitForChild("Events", 20)
    if not Events then warn("DataTycoon: No Events!"); return end
    print("DataTycoon: Events found")
    
    local claimEv     = Events:WaitForChild("ClaimDailyReward", 15)
    local claimedEv   = Events:WaitForChild("DailyRewardClaimed", 15)
    local notifEv     = Events:WaitForChild("Notification", 15)
    local collectEv   = Events:WaitForChild("CollectBlocks", 15)
    local buyPlotEv   = Events:WaitForChild("PurchasePlot", 15)
    local plotPurchEv = Events:WaitForChild("PlotPurchased", 15)
    local compPlacEv  = Events:WaitForChild("ComputerPlaced", 15)
    local houseUpgEv  = Events:WaitForChild("HouseUpgraded", 15)
    local upgradeEv   = Events:WaitForChild("UpgradeHouse", 15)
    local placeCompEv = Events:WaitForChild("PlaceComputer", 15)
    local collectBlkEv = Events:FindFirstChild("CollectBlock")
    
    -- Daily reward
    if claimEv and claimedEv then
        dailyBtn.MouseButton1Click:Connect(function() claimEv:FireServer() end)
        claimedEv.OnClientEvent:Connect(function(reward, streak)
            ShowNotification("Day " .. streak .. ": +" .. reward .. " Data!", Color3.fromRGB(100, 255, 150))
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            task.delay(2, function()
                if dailyBtn and dailyBtn.Parent then
                    dailyBtn.Text = "🎁  Daily Reward"
                    dailyBtn.BackgroundColor3 = C.ACCENT_ORANGE
                end
            end)
        end)
        print("DataTycoon: Daily reward OK")
    end
    
    -- Collect blocks
    if collectEv then
        collectBtn.MouseButton1Click:Connect(function() collectEv:FireServer(1) end)
        print("DataTycoon: Collect blocks OK")
    end
    
    -- Buy plot
    if buyPlotEv then
        local function Buy() buyPlotEv:FireServer("plot_3_3") end
        buyPlotBtn.MouseButton1Click:Connect(Buy)
        UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and input.KeyCode == Enum.KeyCode.E then Buy() end
        end)
        print("DataTycoon: Buy plot OK")
    end
    
    -- Place computer
    if placeCompEv then
        placeCompBtn.MouseButton1Click:Connect(function() placeCompEv:FireServer("plot_3_3", 1) end)
        print("DataTycoon: Place computer OK")
    end
    
    -- Notifications
    if notifEv then
        notifEv.OnClientEvent:Connect(function(msg, t)
            local col = C.TEXT_WHITE
            if t == "success" then col = Color3.fromRGB(100, 255, 150)
            elseif t == "error" then col = Color3.fromRGB(255, 100, 100) end
            ShowNotification(msg, col)
        end)
    end
    
    -- Plot purchased
    if plotPurchEv then
        plotPurchEv.OnClientEvent:Connect(function(pid, oid, oname)
            if oid ~= player.UserId then ShowNotification(oname .. " bought a plot!", Color3.fromRGB(255, 200, 100)) end
        end)
    end
    
    -- Computer placed
    if compPlacEv then
        compPlacEv.OnClientEvent:Connect(function(pid, tier, name)
            ShowNotification(name .. " placed!", C.ACCENT_BLUE)
        end)
    end
    
    -- House upgraded
    if houseUpgEv then
        houseUpgEv.OnClientEvent:Connect(function(tier, name)
            ShowNotification("Upgraded to " .. name .. "!", C.ACCENT_PURPLE)
        end)
    end
    
    -- Upgrade button
    if upgradeEv then
        upgradeBtn.MouseButton1Click:Connect(function() upgradeEv:FireServer() end)
        print("DataTycoon: House upgrade OK")
    end
    
    -- Stats panel
    statsBtn.MouseButton1Click:Connect(function()
        statsFrame.Visible = not statsFrame.Visible
        if statsFrame.Visible then RefreshStats() end
    end)
    statsClose.MouseButton1Click:Connect(function() statsFrame.Visible = false end)
    
    -- Collectible blocks
    if collectBlkEv then
        local function SetupBlock(block)
            if not block:IsA("BasePart") then return end
            local prompt = block:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function() collectBlkEv:FireServer() end)
            end
        end
        local folder = workspace:WaitForChild("CollectibleBlocks", 10)
        if folder then
            for _, b in ipairs(folder:GetChildren()) do SetupBlock(b) end
            folder.ChildAdded:Connect(function(c) task.wait(0.2); SetupBlock(c) end)
            print("DataTycoon: Block collection OK")
        end
    end
    
    print("DataTycoon: All events connected!")
end)

print("DataTycoon: Client ready!")
