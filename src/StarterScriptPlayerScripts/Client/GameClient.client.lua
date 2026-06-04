--[[
    GameClient.client.lua — DataTycoon Client
    v0.10 — Fixed data tracking, cleaner GUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("DataTycoon: Client starting...")

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

local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
    return c
end

-- === SCREEN GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- === DATA BAR (top-center floating pill) ===
local dataBar = Instance.new("Frame")
dataBar.Size = UDim2.new(0, 380, 0, 44)
dataBar.Position = UDim2.new(0.5, -190, 0, 12)
dataBar.BackgroundColor3 = C.BG_DARK
dataBar.BackgroundTransparency = 0.08
dataBar.Parent = screenGui
Corner(dataBar, 22)
local dataBarStroke = Instance.new("UIStroke")
dataBarStroke.Color = C.BORDER
dataBarStroke.Thickness = 1
dataBarStroke.Parent = dataBar

local dataBarLayout = Instance.new("UIListLayout")
dataBarLayout.FillDirection = Enum.FillDirection.Horizontal
dataBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dataBarLayout.Padding = UDim.new(0, 0)
dataBarLayout.Parent = dataBar
local dataBarPad = Instance.new("UIPadding")
dataBarPad.PaddingLeft = UDim.new(0, 16)
dataBarPad.PaddingRight = UDim.new(0, 16)
dataBarPad.Parent = dataBar

local dataLabel = Instance.new("TextLabel")
dataLabel.Size = UDim2.new(0, 130, 1, 0)
dataLabel.BackgroundTransparency = 1
dataLabel.Text = "💰  --"
dataLabel.TextColor3 = C.ACCENT_GREEN
dataLabel.TextSize = 18
dataLabel.Font = Enum.Font.GothamBold
dataLabel.TextXAlignment = Enum.TextXAlignment.Left
dataLabel.Parent = dataBar

local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(0, 1, 0, 22)
sep1.BackgroundColor3 = C.BORDER
sep1.BackgroundTransparency = 0.4
sep1.Parent = dataBar

local houseLabel = Instance.new("TextLabel")
houseLabel.Size = UDim2.new(0, 90, 1, 0)
houseLabel.BackgroundTransparency = 1
houseLabel.Text = "🏠 Shack"
houseLabel.TextColor3 = C.TEXT_DIM
houseLabel.TextSize = 15
houseLabel.Font = Enum.Font.GothamBold
houseLabel.TextXAlignment = Enum.TextXAlignment.Left
houseLabel.Parent = dataBar

local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(0, 1, 0, 22)
sep2.BackgroundColor3 = C.BORDER
sep2.BackgroundTransparency = 0.4
sep2.Parent = dataBar

local dpsLabel = Instance.new("TextLabel")
dpsLabel.Size = UDim2.new(0, 70, 1, 0)
dpsLabel.BackgroundTransparency = 1
dpsLabel.Text = "⚡ 1/s"
dpsLabel.TextColor3 = C.ACCENT_CYAN
dpsLabel.TextSize = 14
dpsLabel.Font = Enum.Font.GothamBold
dpsLabel.TextXAlignment = Enum.TextXAlignment.Left
dpsLabel.Parent = dataBar

-- === LEFT SIDEBAR ===
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 165, 0, 0)
sidebar.Position = UDim2.new(0, 12, 0, 72)
sidebar.BackgroundColor3 = C.BG_CARD
sidebar.BackgroundTransparency = 0.08
sidebar.AutomaticSize = Enum.AutomaticSize.Y
sidebar.Parent = screenGui
Corner(sidebar, 12)
local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0, 6)
sbLayout.Parent = sidebar
local sbPad = Instance.new("UIPadding")
sbPad.PaddingTop = UDim.new(0, 10)
sbPad.PaddingBottom = UDim.new(0, 10)
sbPad.PaddingLeft = UDim.new(0, 10)
sbPad.PaddingRight = UDim.new(0, 10)
sbPad.Parent = sidebar

local function MakeBtn(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = sidebar
    Corner(btn, 8)
    return btn
end

local dailyBtn  = MakeBtn("🎁  Daily Reward", C.ACCENT_ORANGE)
local collectBtn = MakeBtn("⛏️  Collect Data", C.ACCENT_BLUE)
local buyPlotBtn = MakeBtn("📦  Buy Plot [E]", C.ACCENT_GREEN)
local placeCompBtn = MakeBtn("💻  Place Computer", C.ACCENT_PURPLE)
local statsBtn  = MakeBtn("📊  Stats", Color3.fromRGB(55, 55, 80))

-- === NOTIFICATION ===
local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(0, 380, 0, 36)
notifLabel.Position = UDim2.new(0.5, -190, 0, 70)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = C.TEXT_WHITE
notifLabel.TextSize = 16
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeTransparency = 0.6
notifLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
notifLabel.TextTransparency = 1
notifLabel.Parent = screenGui

-- === STATS PANEL ===
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 300, 0, 380)
statsFrame.Position = UDim2.new(0.5, -150, 0.5, -190)
statsFrame.BackgroundColor3 = C.BG_DARK
statsFrame.BackgroundTransparency = 0.05
statsFrame.Visible = false
statsFrame.Parent = screenGui
Corner(statsFrame, 14)

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, -44, 0, 40)
statsTitle.Position = UDim2.new(0, 14, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "📊  Your Stats"
statsTitle.TextColor3 = C.TEXT_WHITE
statsTitle.TextSize = 18
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Parent = statsFrame

local statsClose = Instance.new("TextButton")
statsClose.Size = UDim2.new(0, 26, 0, 26)
statsClose.Position = UDim2.new(1, -32, 0, 7)
statsClose.BackgroundColor3 = C.ACCENT_RED
statsClose.Text = "✕"
statsClose.TextColor3 = Color3.fromRGB(255,255,255)
statsClose.TextSize = 13
statsClose.Font = Enum.Font.GothamBold
statsClose.Parent = statsFrame
Corner(statsClose, 6)

local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Size = UDim2.new(1, -20, 1, -90)
statsScroll.Position = UDim2.new(0, 10, 0, 44)
statsScroll.BackgroundTransparency = 1
statsScroll.ScrollBarThickness = 3
statsScroll.CanvasSize = UDim2.new(0, 0, 0, 300)
statsScroll.Parent = statsFrame

local statsList = Instance.new("UIListLayout")
statsList.Padding = UDim2.new(0, 0, 0, 5)
statsList.Parent = statsScroll

local function AddRow(icon, label, value, valColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.BG_CARD
    row.BackgroundTransparency = 0.3
    row.Parent = statsScroll
    Corner(row, 6)
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 24, 1, 0) ic.Position = UDim2.new(0, 6, 0, 0)
    ic.BackgroundTransparency = 1 ic.Text = icon ic.TextSize = 14
    ic.Font = Enum.Font.GothamBold ic.TextColor3 = C.TEXT_WHITE ic.Parent = row
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(0.55, -26, 1, 0) nl.Position = UDim2.new(0, 30, 0, 0)
    nl.BackgroundTransparency = 1 nl.Text = label nl.TextColor3 = C.TEXT_DIM
    nl.TextSize = 13 nl.Font = Enum.Font.Gotham nl.TextXAlignment = Enum.TextXAlignment.Left nl.Parent = row
    local vl = Instance.new("TextLabel")
    vl.Name = "Value"
    vl.Size = UDim2.new(0.45, -6, 1, 0) vl.Position = UDim2.new(0.55, 0, 0, 0)
    vl.BackgroundTransparency = 1 vl.Text = value vl.TextColor3 = valColor or C.TEXT_WHITE
    vl.TextSize = 14 vl.Font = Enum.Font.GothamBold vl.TextXAlignment = Enum.TextXAlignment.Right vl.Parent = row
    return vl
end

local sHouse  = AddRow("🏠", "House", "Shack", C.ACCENT_ORANGE)
local sPlots  = AddRow("📦", "Plots Owned", "0", C.ACCENT_GREEN)
local sComps  = AddRow("💻", "Computers", "0", C.ACCENT_BLUE)
local sBlocks = AddRow("⛏️", "Data Collected", "0", C.ACCENT_CYAN)
local sData   = AddRow("💰", "Current Data", "0", C.ACCENT_GREEN)
local sEarned = AddRow("📈", "Total Earned", "0", C.TEXT_DIM)
local sSpent  = AddRow("💸", "Total Spent", "0", C.TEXT_DIM)
local sDps    = AddRow("⚡", "Data / Second", "1/s", C.ACCENT_CYAN)

local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size = UDim2.new(1, -20, 0, 38)
upgradeBtn.Position = UDim2.new(0, 10, 1, -44)
upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
upgradeBtn.Text = "🏠  Upgrade House"
upgradeBtn.TextColor3 = Color3.fromRGB(255,255,255)
upgradeBtn.TextSize = 14
upgradeBtn.Font = Enum.Font.GothamBold
upgradeBtn.Parent = statsFrame
Corner(upgradeBtn, 8)

-- === FUNCTIONS ===
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
            if notifLabel and notifLabel.Parent then notifLabel.TextTransparency = 1 - i end
            task.wait(0.025)
        end
        task.delay(1.5, function()
            for i = 0, 1, 0.08 do
                if notifLabel and notifLabel.Parent then notifLabel.TextTransparency = i end
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
        local names = {"Shack","Small House","Modern House","Tech Villa","Mega Compound"}
        sHouse.Text = (names[data.HouseTier] or "Shack") .. " (T" .. data.HouseTier .. ")"
        sPlots.Text = tostring(data.Plots and #data.Plots or 0)
        sComps.Text = tostring(data.Computers and #data.Computers or 0)
        sBlocks.Text = tostring(data.BlocksCollected or 0)
        sData.Text = tostring(data.Data)
        sEarned.Text = tostring(data.TotalEarned or 0)
        sSpent.Text = tostring(data.TotalSpent or 0)
        local dps = 1
        if data.Computers then
            local dv = {2,8,30,120}
            for _,c in ipairs(data.Computers) do dps = dps + (dv[c.tier] or 0) end
        end
        sDps.Text = dps .. "/s"
        dpsLabel.Text = "⚡ " .. dps .. "/s"
        local nt = data.HouseTier + 1
        if nt <= 5 then
            upgradeBtn.Text = "🏠  " .. names[nt] .. "  —  " .. ({0,200,1000,5000,25000})[nt] .. " Data"
            upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
        else
            upgradeBtn.Text = "✅  Max Level"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
        end
    end
end

-- === DATA TRACKING (aggressive) ===
print("DataTycoon: Setting up data tracking...")

-- Method 1: leaderstats Changed event
task.spawn(function()
    local ls = nil
    for i = 1, 40 do
        ls = player:FindFirstChild("leaderstats")
        if ls then break end
        task.wait(0.5)
    end
    if not ls then
        warn("DataTycoon: No leaderstats after 20s!")
        -- Show error in UI
        dataLabel.Text = "💰  Error"
        dataLabel.TextColor3 = C.ACCENT_RED
        return
    end
    print("DataTycoon: leaderstats found")
    
    local dv = ls:FindFirstChild("Data")
    if dv then
        UpdateDataDisplay(dv.Value)
        print("DataTycoon: Initial data = " .. dv.Value)
        dv.Changed:Connect(function(v)
            print("DataTycoon: Data.Changed = " .. v)
            UpdateDataDisplay(v)
        end)
    else
        warn("DataTycoon: No Data value in leaderstats")
        -- Try to find it by iterating
        for _,child in ipairs(ls:GetChildren()) do
            print("  leaderstats child: " .. child.Name .. " = " .. tostring(child.Value))
        end
    end
    
    local hv = ls:FindFirstChild("House")
    if hv then
        local names = {"Shack","Small House","Modern House","Tech Villa","Mega Compound"}
        houseLabel.Text = "🏠 " .. (names[hv.Value] or "Shack")
        hv.Changed:Connect(function(v)
            houseLabel.Text = "🏠 " .. (names[v] or "Shack")
        end)
    end
end)

-- Method 2: DataUpdated RemoteEvent
task.spawn(function()
    local ev = ReplicatedStorage:WaitForChild("Events", 15)
    if ev then
        local du = ev:WaitForChild("DataUpdated", 10)
        if du then
            du.OnClientEvent:Connect(function(amount)
                print("DataTycoon: DataUpdated event = " .. amount)
                UpdateDataDisplay(amount)
            end)
            print("DataTycoon: DataUpdated connected")
        end
    end
end)

-- Method 3: Poll every 1s (aggressive fallback)
task.spawn(function()
    task.wait(3)
    while true do
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local dv = ls:FindFirstChild("Data")
            if dv and dv.Value ~= currentData then
                print("DataTycoon: Poll caught data = " .. dv.Value)
                UpdateDataDisplay(dv.Value)
            end
        end
        task.wait(1)
    end
end)

-- Method 4: Also update from the passive mining tick
-- The server fires DataUpdated every second, so Method 2 should catch it.
-- But as an extra safety net, increment locally
task.spawn(function()
    task.wait(5)
    while true do
        if currentData > 0 then
            currentData = currentData + 1
            dataLabel.Text = "💰  " .. tostring(currentData)
        end
        task.wait(1)
    end
end)

-- === EVENT CONNECTIONS ===
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
    
    if claimEv and claimedEv then
        dailyBtn.MouseButton1Click:Connect(function() claimEv:FireServer() end)
        claimedEv.OnClientEvent:Connect(function(reward, streak)
            ShowNotification("Day " .. streak .. ": +" .. reward .. " Data!", Color3.fromRGB(100,255,150))
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
            task.delay(2, function()
                if dailyBtn and dailyBtn.Parent then dailyBtn.Text = "🎁  Daily Reward"; dailyBtn.BackgroundColor3 = C.ACCENT_ORANGE end
            end)
        end)
        print("DataTycoon: Daily reward OK")
    end
    
    if collectEv then
        collectBtn.MouseButton1Click:Connect(function() collectEv:FireServer(1) end)
        print("DataTycoon: Collect OK")
    end
    
    if buyPlotEv then
        local function Buy() buyPlotEv:FireServer("plot_3_3") end
        buyPlotBtn.MouseButton1Click:Connect(Buy)
        UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and input.KeyCode == Enum.KeyCode.E then Buy() end
        end)
        print("DataTycoon: Buy plot OK")
    end
    
    if placeCompEv then
        placeCompBtn.MouseButton1Click:Connect(function() placeCompEv:FireServer("plot_3_3", 1) end)
        print("DataTycoon: Place computer OK")
    end
    
    if notifEv then
        notifEv.OnClientEvent:Connect(function(msg, t)
            local col = C.TEXT_WHITE
            if t == "success" then col = Color3.fromRGB(100,255,150) elseif t == "error" then col = Color3.fromRGB(255,100,100) end
            ShowNotification(msg, col)
        end)
    end
    
    if plotPurchEv then
        plotPurchEv.OnClientEvent:Connect(function(pid, oid, oname)
            if oid ~= player.UserId then ShowNotification(oname .. " bought a plot!", Color3.fromRGB(255,200,100)) end
        end)
    end
    
    if compPlacEv then
        compPlacEv.OnClientEvent:Connect(function(pid, tier, name) ShowNotification(name .. " placed!", C.ACCENT_BLUE) end)
    end
    
    if houseUpgEv then
        houseUpgEv.OnClientEvent:Connect(function(tier, name) ShowNotification("Upgraded to " .. name .. "!", C.ACCENT_PURPLE) end)
    end
    
    if upgradeEv then
        upgradeBtn.MouseButton1Click:Connect(function() upgradeEv:FireServer() end)
        print("DataTycoon: House upgrade OK")
    end
    
    statsBtn.MouseButton1Click:Connect(function()
        statsFrame.Visible = not statsFrame.Visible
        if statsFrame.Visible then RefreshStats() end
    end)
    statsClose.MouseButton1Click:Connect(function() statsFrame.Visible = false end)
    
    if collectBlkEv then
        local function SetupBlock(block)
            if not block:IsA("BasePart") then return end
            local prompt = block:FindFirstChildOfClass("ProximityPrompt")
            if prompt then prompt.Triggered:Connect(function() collectBlkEv:FireServer() end) end
        end
        local folder = workspace:WaitForChild("CollectibleBlocks", 10)
        if folder then
            for _,b in ipairs(folder:GetChildren()) do SetupBlock(b) end
            folder.ChildAdded:Connect(function(c) task.wait(0.2); SetupBlock(c) end)
            print("DataTycoon: Block collection OK")
        end
    end
    
    print("DataTycoon: All events connected!")
end)

print("DataTycoon: Client ready!")
