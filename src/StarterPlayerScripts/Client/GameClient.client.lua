--[[
    GameClient.client.lua — DataTycoon Client
    v0.18 — Bulletproof: minimal, clear debug, single data tracking
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("========================================")
print("DataTycoon v0.18 — Client starting...")
print("========================================")

-- ============================================================
-- COLORS
-- ============================================================
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

-- ============================================================
-- SCREEN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DataTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- === DATA BAR (top-center) ===
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
houseLabel.Text = "🏠 --"
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
dpsLabel.Text = "⚡ --"
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
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = sidebar
    Corner(btn, 8)
    return btn
end

local dailyBtn    = MakeBtn("🎁  Daily Reward", C.ACCENT_ORANGE)
local collectBtn  = MakeBtn("⛏️  Collect Data", C.ACCENT_BLUE)
local buyPlotBtn  = MakeBtn("📦  Buy Plot [E]", C.ACCENT_GREEN)
local placeCompBtn = MakeBtn("💻  Place Computer", C.ACCENT_PURPLE)
local statsBtn    = MakeBtn("📊  Stats", Color3.fromRGB(55, 55, 80))

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
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
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
statsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
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
    ic.Size = UDim2.new(0, 24, 1, 0)
    ic.Position = UDim2.new(0, 6, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text = icon
    ic.TextSize = 14
    ic.Font = Enum.Font.GothamBold
    ic.TextColor3 = C.TEXT_WHITE
    ic.Parent = row
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(0.55, -26, 1, 0)
    nl.Position = UDim2.new(0, 30, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text = label
    nl.TextColor3 = C.TEXT_DIM
    nl.TextSize = 13
    nl.Font = Enum.Font.Gotham
    nl.TextXAlignment = Enum.TextXAlignment.Left
    nl.Parent = row
    local vl = Instance.new("TextLabel")
    vl.Name = "Value"
    vl.Size = UDim2.new(0.45, -6, 1, 0)
    vl.Position = UDim2.new(0.55, 0, 0, 0)
    vl.BackgroundTransparency = 1
    vl.Text = value
    vl.TextColor3 = valColor or C.TEXT_WHITE
    vl.TextSize = 14
    vl.Font = Enum.Font.GothamBold
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = row
    return vl
end

local sHouse  = AddRow("🏠", "House", "Shack", C.ACCENT_ORANGE)
local sPlots  = AddRow("📦", "Plots Owned", "0", C.ACCENT_GREEN)
local sComps  = AddRow("💻", "Computers", "0", C.ACCENT_BLUE)
local sBlocks = AddRow("⛏️", "Orbs Collected", "0", C.ACCENT_CYAN)
local sData   = AddRow("💰", "Current Data", "0", C.ACCENT_GREEN)
local sEarned = AddRow("📈", "Total Earned", "0", C.TEXT_DIM)
local sSpent  = AddRow("💸", "Total Spent", "0", C.TEXT_DIM)
local sDps    = AddRow("⚡", "Data / Second", "1/s", C.ACCENT_CYAN)

local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Size = UDim2.new(1, -20, 0, 38)
upgradeBtn.Position = UDim2.new(0, 10, 1, -44)
upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
upgradeBtn.Text = "🏠  Upgrade House"
upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeBtn.TextSize = 14
upgradeBtn.Font = Enum.Font.GothamBold
upgradeBtn.Parent = statsFrame
Corner(upgradeBtn, 8)

-- ============================================================
-- HELPER FUNCTIONS
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
        sHouse.Text = (names[data.HouseTier] or "Shack") .. " (T" .. data.HouseTier .. ")"
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
        sDps.Text = dps .. "/s"
        dpsLabel.Text = "⚡ " .. dps .. "/s"
        local nt = data.HouseTier + 1
        if nt <= 5 then
            upgradeBtn.Text = "🏠  " .. names[nt] .. "  —  " .. ({0, 200, 1000, 5000, 25000})[nt] .. " Data"
            upgradeBtn.BackgroundColor3 = C.ACCENT_PURPLE
        else
            upgradeBtn.Text = "✅  Max Level"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        end
    end
end

-- ============================================================
-- DATA TRACKING — Single method: leaderstats.Changed
-- ============================================================
print("DataTycoon: Waiting for leaderstats...")

task.spawn(function()
    local ls = nil
    for i = 1, 60 do
        ls = player:FindFirstChild("leaderstats")
        if ls then break end
        task.wait(0.5)
    end

    if not ls then
        warn("DataTycoon: ERROR — No leaderstats after 30s!")
        dataLabel.Text = "💰  ERR"
        dataLabel.TextColor3 = C.ACCENT_RED
        return
    end
    print("DataTycoon: leaderstats found ✓")

    local dv = ls:FindFirstChild("Data")
    if dv then
        print("DataTycoon: Data value = " .. dv.Value)
        UpdateDataDisplay(dv.Value)
        dv.Changed:Connect(function(v)
            print("DataTycoon: Data → " .. v)
            UpdateDataDisplay(v)
        end)
    else
        warn("DataTycoon: ERROR — No Data in leaderstats!")
        dataLabel.Text = "💰  ERR"
        dataLabel.TextColor3 = C.ACCENT_RED
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

-- Backup: DataUpdated RemoteEvent
task.spawn(function()
    local ev = ReplicatedStorage:WaitForChild("Events", 20)
    if ev then
        local du = ev:WaitForChild("DataUpdated", 15)
        if du then
            du.OnClientEvent:Connect(function(amount)
                print("DataTycoon: DataUpdated → " .. amount)
                UpdateDataDisplay(amount)
            end)
            print("DataTycoon: DataUpdated connected ✓")
        end
    end
end)

-- ============================================================
-- CONNECT BUTTONS (after Events are ready)
-- ============================================================
task.spawn(function()
    print("DataTycoon: Waiting for Events folder...")
    local Events = ReplicatedStorage:WaitForChild("Events", 30)
    if not Events then
        warn("DataTycoon: ERROR — No Events folder after 30s!")
        return
    end
    print("DataTycoon: Events folder found ✓")

    -- Wait for all events
    local claimEv     = Events:WaitForChild("ClaimDailyReward", 15)
    local claimedEv   = Events:WaitForChild("DailyRewardClaimed", 15)
    local notifEv     = Events:WaitForChild("Notification", 15)
    local collectEv   = Events:WaitForChild("CollectOrb", 15)
    local buyPlotEv   = Events:WaitForChild("PurchasePlot", 15)
    local plotPurchEv = Events:WaitForChild("PlotPurchased", 15)
    local compPlacEv  = Events:WaitForChild("ComputerPlaced", 15)
    local houseUpgEv  = Events:WaitForChild("HouseUpgraded", 15)
    local upgradeEv   = Events:WaitForChild("UpgradeHouse", 15)
    local placeCompEv = Events:WaitForChild("PlaceComputer", 15)

    print("DataTycoon: All events found, connecting buttons...")

    -- DAILY REWARD
    dailyBtn.MouseButton1Click:Connect(function()
        print("DataTycoon: [CLICK] Daily Reward")
        claimEv:FireServer()
    end)
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
    print("DataTycoon: Daily Reward ✓")

    -- COLLECT ORB (button)
    collectBtn.MouseButton1Click:Connect(function()
        print("DataTycoon: [CLICK] Collect")
        collectEv:FireServer()
    end)
    print("DataTycoon: Collect ✓")

    -- BUY PLOT
    local function Buy()
        print("DataTycoon: [CLICK] Buy Plot")
        buyPlotEv:FireServer("plot_3_3")
    end
    buyPlotBtn.MouseButton1Click:Connect(Buy)
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.E then Buy() end
    end)
    print("DataTycoon: Buy Plot ✓")

    -- PLACE COMPUTER
    placeCompBtn.MouseButton1Click:Connect(function()
        print("DataTycoon: [CLICK] Place Computer")
        placeCompEv:FireServer("plot_3_3", 1)
    end)
    print("DataTycoon: Place Computer ✓")

    -- HOUSE UPGRADE
    upgradeBtn.MouseButton1Click:Connect(function()
        print("DataTycoon: [CLICK] Upgrade House")
        upgradeEv:FireServer()
    end)
    print("DataTycoon: House Upgrade ✓")

    -- NOTIFICATIONS
    notifEv.OnClientEvent:Connect(function(msg, t)
        local col = C.TEXT_WHITE
        if t == "success" then col = Color3.fromRGB(100, 255, 150)
        elseif t == "error" then col = Color3.fromRGB(255, 100, 100) end
        ShowNotification(msg, col)
    end)

    -- OTHER PLAYERS
    plotPurchEv.OnClientEvent:Connect(function(pid, oid, oname)
        if oid ~= player.UserId then ShowNotification(oname .. " bought a plot!", Color3.fromRGB(255, 200, 100)) end
    end)
    compPlacEv.OnClientEvent:Connect(function(pid, tier, name) ShowNotification(name .. " placed!", C.ACCENT_BLUE) end)
    houseUpgEv.OnClientEvent:Connect(function(tier, name) ShowNotification("Upgraded to " .. name .. "!", C.ACCENT_PURPLE) end)

    -- STATS PANEL
    statsBtn.MouseButton1Click:Connect(function()
        statsFrame.Visible = not statsFrame.Visible
        if statsFrame.Visible then RefreshStats() end
    end)
    statsClose.MouseButton1Click:Connect(function() statsFrame.Visible = false end)

    -- ============================================================
    -- ORB TOUCH COLLECTION
    -- ============================================================
    print("DataTycoon: Looking for orb folder...")
    -- The server creates orbs in workspace.DataOrbs folder
    -- Try multiple possible folder names
    local orbFolder = nil
    for _, name in ipairs({"DataOrbs", "CollectibleBlocks", "DataOrb"}) do
        orbFolder = workspace:FindFirstChild(name)
        if orbFolder then break end
    end

    if not orbFolder then
        -- Wait for it
        for _, name in ipairs({"DataOrbs", "CollectibleBlocks"}) do
            orbFolder = workspace:WaitForChild(name, 15)
            if orbFolder then break end
        end
    end

    if orbFolder then
        print("DataTycoon: Orb folder found: " .. orbFolder.Name .. " ✓")

        local function onOrbTouched(hit)
            local character = hit.Parent
            local plr = Players:GetPlayerFromCharacter(character)
            if plr == player then
                print("DataTycoon: Orb touched!")
                collectEv:FireServer()
            end
        end

        -- Connect to all OrbRing parts (collidable ground rings)
        local orbCount = 0
        for _, desc in ipairs(orbFolder:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name == "OrbRing" then
                desc.Touched:Connect(onOrbTouched)
                orbCount = orbCount + 1
            end
        end
        print("DataTycoon: Connected " .. orbCount .. " orb touch zones ✓")

        -- Also connect future orbs
        orbFolder.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") and desc.Name == "OrbRing" then
                desc.Touched:Connect(onOrbTouched)
            end
        end)
    else
        warn("DataTycoon: WARNING — No orb folder found!")
    end

    print("========================================")
    print("DataTycoon: ALL BUTTONS CONNECTED! ✓")
    print("========================================")
end)
