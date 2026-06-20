--[[
    GameClient.client.lua — DataTycoon v0.23
    Key fixes:
      - game.Loaded:Wait() before ANY WaitForChild (fixes ERR/connection failed)
      - Number formatter (1234 -> "1.2K")
      - Orb visual feedback: collected orbs fade out, respawn after timer
      - Proper shop panel with tier selection
      - DPS counter updates live
      - All mechanics verified: collect, accumulate, buy, subtract
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

-- ============================================================
-- CRITICAL: Wait for full replication before doing anything
-- This is the #1 fix for "connection failed" and "ERR"
-- ============================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then
    warn("[CLIENT] PlayerGui not found after 30s, using fallback")
    playerGui = Instance.new("ScreenGui")
    playerGui.Name = "PlayerGui"
    playerGui.Parent = player
end

print("[CLIENT] v0.23 starting (game loaded)")

-- ============================================================
-- UTIL
-- ============================================================
local function fmt(n)
    n = math.floor(n or 0)
    if n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(n) end
end

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p
end
local function stroke(p, col, thick)
    local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(40,40,65); s.Thickness = thick or 1; s.Parent = p
end

-- ============================================================
-- COLORS
-- ============================================================
local C = {
    BG     = Color3.fromRGB(14, 14, 24),
    CARD   = Color3.fromRGB(22, 22, 40),
    GREEN  = Color3.fromRGB(0,  210, 110),
    BLUE   = Color3.fromRGB(60, 140, 255),
    PURPLE = Color3.fromRGB(140, 80,  255),
    ORANGE = Color3.fromRGB(255, 140, 40),
    RED    = Color3.fromRGB(255, 70,  70),
    CYAN   = Color3.fromRGB(0,   200, 220),
    GOLD   = Color3.fromRGB(255, 215, 0),
    WHITE  = Color3.fromRGB(240, 240, 255),
    DIM    = Color3.fromRGB(155, 155, 185),
    BORDER = Color3.fromRGB(42,  42,  68),
}

local HOUSE_NAMES  = {"Shack","Small House","Modern House","Tech Villa","Mega Compound"}
local HOUSE_COSTS  = {0, 300, 1500, 8000, 30000}
local COMP_TIERS   = {
    {name="Budget Rig",    cost=100,   dps=2},
    {name="Gaming PC",     cost=500,   dps=8},
    {name="Server Rack",   cost=2500,  dps=30},
    {name="Supercomputer", cost=10000, dps=120},
}

-- ============================================================
-- SCREEN GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "DataTycoonHUD"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.Parent = playerGui

-- ---- DATA BAR (top-center) ----
local dataBar = Instance.new("Frame")
dataBar.Size = UDim2.new(0, 380, 0, 48)
dataBar.Position = UDim2.new(0.5, -190, 0, 10)
dataBar.BackgroundColor3 = C.BG; dataBar.BackgroundTransparency = 0.06
dataBar.Parent = gui; corner(dataBar, 24); stroke(dataBar, C.BORDER)

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0,0); barLayout.Parent = dataBar
local barPad = Instance.new("UIPadding")
barPad.PaddingLeft = UDim.new(0,16); barPad.PaddingRight = UDim.new(0,16)
barPad.Parent = dataBar

local dataLabel = Instance.new("TextLabel")
dataLabel.Size = UDim2.new(0, 145, 1, 0); dataLabel.BackgroundTransparency = 1
dataLabel.Text = "💰  Loading..."; dataLabel.TextColor3 = C.GREEN
dataLabel.TextSize = 17; dataLabel.Font = Enum.Font.GothamBold
dataLabel.TextXAlignment = Enum.TextXAlignment.Left; dataLabel.Parent = dataBar

local sep1 = Instance.new("Frame"); sep1.Size = UDim2.new(0,1,0,24)
sep1.BackgroundColor3 = C.BORDER; sep1.BackgroundTransparency = 0.3; sep1.Parent = dataBar

local houseLabel = Instance.new("TextLabel")
houseLabel.Size = UDim2.new(0, 100, 1, 0); houseLabel.BackgroundTransparency = 1
houseLabel.Text = "🏠 Shack"; houseLabel.TextColor3 = C.DIM
houseLabel.TextSize = 14; houseLabel.Font = Enum.Font.GothamBold
houseLabel.TextXAlignment = Enum.TextXAlignment.Left; houseLabel.Parent = dataBar

local sep2 = Instance.new("Frame"); sep2.Size = UDim2.new(0,1,0,24)
sep2.BackgroundColor3 = C.BORDER; sep2.BackgroundTransparency = 0.3; sep2.Parent = dataBar

local dpsLabel = Instance.new("TextLabel")
dpsLabel.Size = UDim2.new(0, 72, 1, 0); dpsLabel.BackgroundTransparency = 1
dpsLabel.Text = "⚡ 1/s"; dpsLabel.TextColor3 = C.CYAN
dpsLabel.TextSize = 13; dpsLabel.Font = Enum.Font.GothamBold
dpsLabel.TextXAlignment = Enum.TextXAlignment.Left; dpsLabel.Parent = dataBar

-- ---- SIDEBAR ----
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0,170,0,0); sidebar.Position = UDim2.new(0,10,0,72)
sidebar.BackgroundColor3 = C.CARD; sidebar.BackgroundTransparency = 0.06
sidebar.AutomaticSize = Enum.AutomaticSize.Y; sidebar.Parent = gui
corner(sidebar, 12); stroke(sidebar, C.BORDER)
local sbL = Instance.new("UIListLayout"); sbL.Padding = UDim.new(0,5); sbL.Parent = sidebar
local sbP = Instance.new("UIPadding")
sbP.PaddingTop=UDim.new(0,8); sbP.PaddingBottom=UDim.new(0,8)
sbP.PaddingLeft=UDim.new(0,8); sbP.PaddingRight=UDim.new(0,8); sbP.Parent=sidebar

local function Btn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,36); b.BackgroundColor3 = color
    b.Text = text; b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 12; b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = true; b.Parent = sidebar; corner(b, 7)
    return b
end

local dailyBtn   = Btn("🎁  Daily Reward",   C.ORANGE)
local shopBtn    = Btn("🛒  Shop",            C.BLUE)
local buyPlotBtn = Btn("📦  Buy Plot  [E]",  C.GREEN)
local statsBtn   = Btn("📊  Stats",           Color3.fromRGB(50,50,75))

-- Stats should stay disabled until server confirms data is loaded
local statsEnabled = false
statsBtn.Text = "📊  Stats (Loading...)"
statsBtn.AutoButtonColor = false

-- ---- NOTIFICATION ----
local notif = Instance.new("TextLabel")
notif.Size = UDim2.new(0, 380, 0, 36)
notif.Position = UDim2.new(0.5, -190, 0, 66)
notif.BackgroundTransparency = 1; notif.Text = ""
notif.TextColor3 = C.WHITE; notif.TextSize = 15; notif.Font = Enum.Font.GothamBold
notif.TextStrokeTransparency = 0.5; notif.TextStrokeColor3 = Color3.new(0,0,0)
notif.TextTransparency = 1; notif.Parent = gui

local notifQ = {}; local notifBusy = false
local function Notify(msg, color)
    table.insert(notifQ, {msg=msg, color=color or C.WHITE})
    if notifBusy then return end
    notifBusy = true
    task.spawn(function()
        while #notifQ > 0 do
            local n = table.remove(notifQ, 1)
            notif.Text = n.msg; notif.TextColor3 = n.color; notif.TextTransparency = 1
            for i=0,1,0.12 do notif.TextTransparency = 1-i; task.wait(0.02) end
            task.wait(1.8)
            for i=0,1,0.1 do notif.TextTransparency = i; task.wait(0.02) end
        end
        notifBusy = false
    end)
end

-- ---- SHOP PANEL ----
local shopPanel = Instance.new("Frame")
shopPanel.Size = UDim2.new(0, 340, 0, 0)
shopPanel.Position = UDim2.new(0, 190, 0, 72)
shopPanel.BackgroundColor3 = C.BG; shopPanel.BackgroundTransparency = 0.04
shopPanel.AutomaticSize = Enum.AutomaticSize.Y
shopPanel.Visible = false; shopPanel.Parent = gui
corner(shopPanel, 14); stroke(shopPanel, C.BORDER)

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 6); shopLayout.Parent = shopPanel
local shopPad = Instance.new("UIPadding")
shopPad.PaddingTop=UDim.new(0,10); shopPad.PaddingBottom=UDim.new(0,10)
shopPad.PaddingLeft=UDim.new(0,10); shopPad.PaddingRight=UDim.new(0,10); shopPad.Parent=shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1,0,0,32); shopTitle.BackgroundTransparency = 1
shopTitle.Text = "🛒  Shop"; shopTitle.TextColor3 = C.WHITE
shopTitle.TextSize = 17; shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextXAlignment = Enum.TextXAlignment.Left; shopTitle.Parent = shopPanel

local shopCloseBtn = Instance.new("TextButton")
shopCloseBtn.Size = UDim2.new(1,0,0,30); shopCloseBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
shopCloseBtn.Text = "✕  Close Shop"; shopCloseBtn.TextColor3 = C.DIM
shopCloseBtn.TextSize = 12; shopCloseBtn.Font = Enum.Font.GothamBold
shopCloseBtn.Parent = shopPanel; corner(shopCloseBtn, 7)

-- Section header helper
local function ShopHeader(text)
    local h = Instance.new("TextLabel")
    h.Size = UDim2.new(1,0,0,22); h.BackgroundTransparency = 1
    h.Text = text; h.TextColor3 = C.CYAN; h.TextSize = 12
    h.Font = Enum.Font.GothamBold; h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = shopPanel
end

-- Shop item button helper — returns the button so we can update its text
local function ShopItem(icon, name, cost, detail, color, onBuy)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,48); row.BackgroundColor3 = C.CARD
    row.BackgroundTransparency = 0.3; row.Parent = shopPanel; corner(row, 8)

    local left = Instance.new("TextLabel")
    left.Size = UDim2.new(0.62,0,1,0); left.Position = UDim2.new(0,8,0,0)
    left.BackgroundTransparency = 1; left.TextXAlignment = Enum.TextXAlignment.Left
    left.Text = icon.." "..name.."\n"..detail
    left.TextColor3 = C.WHITE; left.TextSize = 12; left.Font = Enum.Font.Gotham
    left.TextWrapped = true; left.Parent = row

    local buyB = Instance.new("TextButton")
    buyB.Size = UDim2.new(0.34,0,0.7,0)
    buyB.Position = UDim2.new(0.64,0,0.15,0)
    buyB.BackgroundColor3 = color; buyB.Text = "💰 "..fmt(cost)
    buyB.TextColor3 = Color3.new(1,1,1); buyB.TextSize = 12
    buyB.Font = Enum.Font.GothamBold; buyB.Parent = row; corner(buyB, 6)
    buyB.MouseButton1Click:Connect(onBuy)
    return buyB
end

-- ---- STATS PANEL ----
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 295, 0, 0)
panel.Position = UDim2.new(0.5,-147,0.5,-180)
panel.BackgroundColor3 = C.BG; panel.BackgroundTransparency = 0.04
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Visible = false; panel.Parent = gui
corner(panel, 14); stroke(panel, C.BORDER)
local panelL = Instance.new("UIListLayout"); panelL.Padding = UDim.new(0,4); panelL.Parent = panel
local panelP = Instance.new("UIPadding")
panelP.PaddingTop=UDim.new(0,10); panelP.PaddingBottom=UDim.new(0,10)
panelP.PaddingLeft=UDim.new(0,10); panelP.PaddingRight=UDim.new(0,10); panelP.Parent=panel

local ptitle = Instance.new("TextLabel")
ptitle.Size=UDim2.new(1,0,0,32); ptitle.BackgroundTransparency=1
ptitle.Text="📊  Stats"; ptitle.TextColor3=C.WHITE
ptitle.TextSize=17; ptitle.Font=Enum.Font.GothamBold
ptitle.TextXAlignment=Enum.TextXAlignment.Left; ptitle.Parent=panel

local pclose = Instance.new("TextButton")
pclose.Size=UDim2.new(1,0,0,30); pclose.BackgroundColor3=Color3.fromRGB(40,40,60)
pclose.Text="✕  Close Stats"; pclose.TextColor3=C.DIM
pclose.TextSize=12; pclose.Font=Enum.Font.GothamBold; pclose.Parent=panel; corner(pclose,7)

local statValues = {}
local function StatRow(icon, label, val, valColor)
    local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0,32)
    row.BackgroundColor3=C.CARD; row.BackgroundTransparency=0.25
    row.Parent=panel; corner(row,6)
    local il=Instance.new("TextLabel"); il.Size=UDim2.new(0,20,1,0); il.Position=UDim2.new(0,5,0,0)
    il.BackgroundTransparency=1; il.Text=icon; il.TextSize=13; il.Font=Enum.Font.GothamBold
    il.TextColor3=C.WHITE; il.Parent=row
    local nl=Instance.new("TextLabel"); nl.Size=UDim2.new(0.55,-22,1,0); nl.Position=UDim2.new(0,25,0,0)
    nl.BackgroundTransparency=1; nl.Text=label; nl.TextColor3=C.DIM; nl.TextSize=12
    nl.Font=Enum.Font.Gotham; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=row
    local vl=Instance.new("TextLabel"); vl.Name="Val"; vl.Size=UDim2.new(0.45,-6,1,0)
    vl.Position=UDim2.new(0.55,0,0,0); vl.BackgroundTransparency=1; vl.Text=val
    vl.TextColor3=valColor or C.WHITE; vl.TextSize=13; vl.Font=Enum.Font.GothamBold
    vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row
    return vl
end

statValues.house  = StatRow("🏠","House",        "Shack",  C.ORANGE)
statValues.plots  = StatRow("📦","Plots Owned",  "0",      C.GREEN)
statValues.comps  = StatRow("💻","Computers",    "0",      C.BLUE)
statValues.orbs   = StatRow("⛏️","Orbs Collected","0",     C.CYAN)
statValues.data   = StatRow("💰","Data",          "0",     C.GREEN)
statValues.earned = StatRow("📈","Total Earned",  "0",     C.DIM)
statValues.spent  = StatRow("💸","Total Spent",   "0",     C.DIM)
statValues.dps    = StatRow("⚡","Data/sec",      "1/s",   C.CYAN)

-- ============================================================
-- DATA DISPLAY
-- ============================================================
local currentData = 0

local function SetData(v)
    currentData = v
    dataLabel.Text = "💰  "..fmt(v)
    dataLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
    task.delay(0.15, function() dataLabel.TextColor3 = C.GREEN end)
end

local function SetDps(dps)
    dps = math.max(0, math.floor(tonumber(dps) or 0))
    dpsLabel.Text = "⚡ "..dps.."/s"
    statValues.dps.Text = dps.."/s"
end

-- ============================================================
-- STEP 1: Wait for leaderstats (with game.Loaded already done)
-- ============================================================
task.spawn(function()
    print("[CLIENT] Waiting for leaderstats...")
    local ls = player:WaitForChild("leaderstats", 20)
    if not ls then
        warn("[CLIENT] leaderstats never arrived!")
        dataLabel.Text = "💰  ?"
        return
    end
    print("[CLIENT] leaderstats found")

    local dv = ls:WaitForChild("Data", 10)
    if dv then
        SetData(dv.Value)
        dv.Changed:Connect(SetData)
        print("[CLIENT] Data connected = "..tostring(dv.Value))
    end

    local hv = ls:WaitForChild("House", 10)
    if hv then
        houseLabel.Text = "🏠 "..(HOUSE_NAMES[hv.Value] or "Shack")
        hv.Changed:Connect(function(v)
            houseLabel.Text = "🏠 "..(HOUSE_NAMES[v] or "Shack")
        end)
    end
end)

-- ============================================================
-- STEP 2: Connect to Events
-- ============================================================
task.spawn(function()
    print("[CLIENT] Waiting for Events...")
    local Events = ReplicatedStorage:WaitForChild("Events", 20)
    if not Events then
        warn("[CLIENT] Events folder not found after 20s!")
        Notify("⚠️ Server connection issue — try rejoining", C.RED)
        return
    end
    print("[CLIENT] Events found")

    local function Ev(name)
        local e = Events:WaitForChild(name, 10)
        if not e then warn("[CLIENT] Missing event: "..name) end
        return e
    end

    local claimEv      = Ev("ClaimDailyReward")
    local claimedEv    = Ev("DailyRewardClaimed")
    local notifEv      = Ev("Notification")
    local collectEv    = Ev("CollectOrb")
    local orbCollected = Ev("OrbCollected")
    local orbStateChanged = Ev("OrbStateChanged")
    local buyPlotEv    = Ev("PurchasePlot")
    local plotPurchEv  = Ev("PlotPurchased")
    local plotSoldEv   = Ev("PlotSold")
    local upgradeEv    = Ev("UpgradeHouse")
    local placeCompEv  = Ev("PlaceComputer")
    local compPlacEv   = Ev("ComputerPlaced")
    local houseUpgEv   = Ev("HouseUpgraded")
    local dataUpdEv    = Ev("DataUpdated")
    local getDataFn    = Ev("GetPlayerData")
    local dataReadyEv  = Ev("PlayerDataReady")
    local bridgeBuiltEv = Ev("BridgeBuilt")
    local bridgeRemEv   = Ev("BridgeRemoved")

    if dataReadyEv then
        dataReadyEv.OnClientEvent:Connect(function()
            statsEnabled = true
            statsBtn.Text = "📊  Stats"
            statsBtn.AutoButtonColor = true
        end)
    end

    -- Backup data sync from server
    if dataUpdEv then
        dataUpdEv.OnClientEvent:Connect(SetData)
    end

    -- Server notifications
    if notifEv then
        notifEv.OnClientEvent:Connect(function(msg, t)
            local col = t=="success" and C.GREEN or (t=="error" and C.RED or C.WHITE)
            Notify(msg, col)
        end)
    end

    -- Daily reward
    if claimEv then
        dailyBtn.MouseButton1Click:Connect(function()
            claimEv:FireServer()
        end)
    end
    if claimedEv then
        claimedEv.OnClientEvent:Connect(function(reward, streak)
            Notify("Day "..streak..": +"..fmt(reward).." Data! 🎉", C.GREEN)
            dailyBtn.Text = "✅ Claimed!"
            dailyBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
            task.delay(3, function()
                if dailyBtn and dailyBtn.Parent then
                    dailyBtn.Text = "🎁  Daily Reward"
                    dailyBtn.BackgroundColor3 = C.ORANGE
                end
            end)
        end)
    end

    -- Buy plot (server picks nearest unowned plot, E key shortcut)
    local function BuyNext()
        if not buyPlotEv then return end
        buyPlotEv:FireServer()
    end
    buyPlotBtn.MouseButton1Click:Connect(BuyNext)
    UserInputService.InputBegan:Connect(function(inp, gp)
        if not gp and inp.KeyCode == Enum.KeyCode.E then BuyNext() end
    end)

    if plotPurchEv then
        plotPurchEv.OnClientEvent:Connect(function(pid, uid, uname)
            -- Plot ownership visuals
            local function setOwnerSign(plotRoot)
                local candidates = {
                    plotRoot:FindFirstChild("Sign", true),
                    plotRoot:FindFirstChild("BillboardGui", true),
                    plotRoot:FindFirstChild("SurfaceGui", true),
                }

                for _, inst in ipairs(candidates) do
                    if inst then
                        local label = inst:FindFirstChildWhichIsA("TextLabel", true)
                        if label then
                            label.Text = tostring(uname or "Unknown")
                            return
                        end
                    end
                end
            end

            local plotBase = workspace:FindFirstChild("Plot_" .. tostring(pid)) or workspace:FindFirstChild(tostring(pid))
            if plotBase then
                local ownerColor = (uid == player.UserId) and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(100, 150, 255)

                local basePart = plotBase:IsA("BasePart") and plotBase or plotBase:FindFirstChildWhichIsA("BasePart", true)
                if basePart then
                    basePart.Color = ownerColor
                end

                setOwnerSign(plotBase)

                local highlight = Instance.new("Highlight")
                highlight.Name = "OwnerPulse"
                highlight.FillColor = ownerColor
                highlight.OutlineColor = Color3.new(1, 1, 1)
                highlight.FillTransparency = 0.7
                highlight.Parent = plotBase
                task.delay(3, function()
                    if highlight and highlight.Parent then
                        highlight:Destroy()
                    end
                end)

                if basePart then
                    local att = Instance.new("Attachment")
                    att.Name = "OwnerPulseAttachment"
                    att.Parent = basePart
                    local emit = Instance.new("ParticleEmitter")
                    emit.Name = "OwnerPulseEmitter"
                    emit.Texture = "rbxassetid://243660364"
                    emit.Lifetime = NumberRange.new(0.35, 0.6)
                    emit.Speed = NumberRange.new(4, 8)
                    emit.Rate = 0
                    emit.Rotation = NumberRange.new(0, 360)
                    emit.RotSpeed = NumberRange.new(-180, 180)
                    emit.SpreadAngle = Vector2.new(360, 360)
                    emit.Color = ColorSequence.new(ownerColor)
                    emit.LightEmission = 0.6
                    emit.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.5),
                        NumberSequenceKeypoint.new(1, 0),
                    })
                    emit.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.15),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    emit.Parent = att
                    emit:Emit(20)
                    task.delay(1, function()
                        if att and att.Parent then
                            att:Destroy()
                        end
                    end)
                end
            else
                warn("[CLIENT] PlotPurchased: could not find plot base for pid=" .. tostring(pid))
            end

            if uid ~= player.UserId then
                Notify(uname.." bought a plot!", Color3.fromRGB(255,210,80))
            end
        end)
    end

    if plotSoldEv then
        plotSoldEv.OnClientEvent:Connect(function(pid)
            local plotBase = workspace:FindFirstChild("Plot_" .. tostring(pid)) or workspace:FindFirstChild(tostring(pid))
            if plotBase then
                local old = plotBase:FindFirstChild("OwnerPulse")
                if old then
                    old:Destroy()
                end
            end
        end)
    end

    if bridgeBuiltEv then
        bridgeBuiltEv.OnClientEvent:Connect(function(pid, ownerName, ownerUserId)
            Notify("🌉 Bridge built to "..tostring(pid).." by "..tostring(ownerName).."!", C.CYAN)
        end)
    end

    if bridgeRemEv then
        bridgeRemEv.OnClientEvent:Connect(function(pid)
            Notify("🌉 Bridge removed from "..tostring(pid), C.DIM)
        end)
    end

    -- House upgrade events
    if houseUpgEv then
        houseUpgEv.OnClientEvent:Connect(function(tier, name)
            houseLabel.Text = "🏠 "..name
        end)
    end

    -- Computer placed
    if compPlacEv then
        compPlacEv.OnClientEvent:Connect(function(pid, tier, name, dps)
            Notify(name.." online! +"..tostring(dps).."/s ⚡", C.BLUE)
        end)
    end

    -- Stats panel
    local function RefreshStats()
        if not getDataFn then return end
        local ok, data = pcall(function() return getDataFn:InvokeServer() end)
        if not (ok and data) then return end

        if data.ok == false then
            statValues.house.Text  = "Loading..."
            statValues.plots.Text  = "Loading..."
            statValues.comps.Text  = "Loading..."
            statValues.orbs.Text   = "Loading..."
            statValues.data.Text   = "Loading..."
            statValues.earned.Text = "Loading..."
            statValues.spent.Text  = "Loading..."
            task.delay(2, function()
                if panel.Visible then
                    RefreshStats()
                end
            end)
            return
        end

        local snapshot = data.data
        if type(snapshot) ~= "table" then return end

        local hn = HOUSE_NAMES[snapshot.HouseTier] or "Shack"
        statValues.house.Text  = hn.." (T"..snapshot.HouseTier..")"
        statValues.plots.Text  = tostring(#(snapshot.Plots or {}))
        statValues.comps.Text  = tostring(#(snapshot.Computers or {}))
        statValues.orbs.Text   = tostring(snapshot.BlocksCollected or 0)
        statValues.data.Text   = fmt(snapshot.Data)
        statValues.earned.Text = fmt(snapshot.TotalEarned or 0)
        statValues.spent.Text  = fmt(snapshot.TotalSpent or 0)
        local dps = 1
        for _, comp in ipairs(snapshot.Computers or {}) do
            dps = dps + (COMP_TIERS[comp.tier] and COMP_TIERS[comp.tier].dps or 0)
        end
        SetDps(dps)
    end

    statsBtn.MouseButton1Click:Connect(function()
        if not statsEnabled then
            Notify("Loading...", C.DIM)
            return
        end
        shopPanel.Visible = false
        panel.Visible = not panel.Visible
        if panel.Visible then RefreshStats() end
    end)
    pclose.MouseButton1Click:Connect(function() panel.Visible = false end)

    -- Keep DPS/stats fresh while Stats panel is open, without spamming.
    task.spawn(function()
        while gui and gui.Parent do
            task.wait(5)
            if panel.Visible then
                RefreshStats()
            end
        end
    end)

    -- ---- SHOP PANEL ----
    ShopHeader("─── Computers ───")
    for i, ct in ipairs(COMP_TIERS) do
        local tier = i
        ShopItem("💻", ct.name, ct.cost, "+"..ct.dps.."/s passive income", C.BLUE, function()
            if not placeCompEv or not getDataFn then return end
            local ok, data = pcall(function() return getDataFn:InvokeServer() end)
            local snapshot = ok and data and data.ok and data.data
            if snapshot and snapshot.Plots and #snapshot.Plots > 0 then
                placeCompEv:FireServer(snapshot.Plots[1], tier)
            else
                Notify("Buy a plot first! [E key]", C.RED)
            end
        end)
    end

    ShopHeader("─── House Upgrades ───")
    for i = 2, #HOUSE_NAMES do
        local tier = i
        ShopItem("🏠", HOUSE_NAMES[i], HOUSE_COSTS[i],
            "Max "..({1,2,4,8,16})[i].." computers", C.PURPLE, function()
            if upgradeEv then upgradeEv:FireServer() end
        end)
    end

    shopBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
        shopPanel.Visible = not shopPanel.Visible
    end)
    shopCloseBtn.MouseButton1Click:Connect(function() shopPanel.Visible = false end)

    -- ============================================================
    -- ORB COLLECTION
    -- ============================================================
    if collectEv and orbCollected then
        orbCollected.OnClientEvent:Connect(function(orbPos, respawnTime)
            if typeof(orbPos) ~= "Vector3" then return end

            local orbFolder = workspace:FindFirstChild("DataOrbs")
            if not orbFolder then return end

            -- Collect all parts within 12 studs of orb center
            local affectedParts = {}
            for _, desc in ipairs(orbFolder:GetDescendants()) do
                if desc:IsA("BasePart") then
                    local dist = (desc.Position - orbPos).Magnitude
                    if dist < 12 then
                        affectedParts[#affectedParts+1] = {part=desc, origAlpha=desc.Transparency}
                    end
                end
            end

            -- Fade out
            for _, info in ipairs(affectedParts) do
                info.part.Transparency = 1
                info.part.CanCollide   = false
            end

            -- Respawn after timer
            task.delay(respawnTime or 30, function()
                for _, info in ipairs(affectedParts) do
                    if info.part and info.part.Parent then
                        info.part.Transparency = info.origAlpha
                        info.part.CanCollide   = info.part.Name:match("^OrbRing") ~= nil
                    end
                end
            end)
        end)

        if orbStateChanged then
            orbStateChanged.OnClientEvent:Connect(function(orbId, available)
                if type(orbId) ~= "string" then return end
                if type(available) ~= "boolean" then return end

                local orbFolder = workspace:FindFirstChild("DataOrbs")
                if not orbFolder then return end

                local ring = orbFolder:FindFirstChild(orbId)
                if ring and ring:IsA("BasePart") then
                    ring.Transparency = available and 0 or 1
                    ring.CanCollide = available
                end
            end)
        end

        -- Touch handler
        local function hookOrbs(folder)
            local debounce = {}

            local function onTouch(ring, hit)
                local char = hit.Parent
                local plr  = Players:GetPlayerFromCharacter(char)
                if plr ~= player then return end
                local now = tick()
                if debounce[ring] and (now - debounce[ring]) < 0.6 then return end
                debounce[ring] = now
                -- Pass orb id (ring.Name) so server can enforce per-orb cooldown
                collectEv:FireServer(ring.Name)
            end

            local n = 0
            for _, d in ipairs(folder:GetDescendants()) do
                if d:IsA("BasePart") and d.Name == "OrbRing" then
                    local ring = d
                    ring.Touched:Connect(function(hit) onTouch(ring, hit) end)
                    n = n + 1
                end
            end

            folder.DescendantAdded:Connect(function(d)
                task.wait(0.05)
                if d:IsA("BasePart") and d.Name == "OrbRing" then
                    local ring = d
                    ring.Touched:Connect(function(hit) onTouch(ring, hit) end)
                end
            end)
            print("[CLIENT] Hooked "..n.." orb rings")
        end

        local orbF = workspace:FindFirstChild("DataOrbs")
        if orbF then
            hookOrbs(orbF)
        else
            task.spawn(function()
                local f = workspace:WaitForChild("DataOrbs", 45)
                if f then hookOrbs(f)
                else warn("[CLIENT] DataOrbs never appeared") end
            end)
        end
    end

    print("[CLIENT] ✅ All systems connected!")
    Notify("DataTycoon loaded! Walk into orbs to collect data. ⚡", C.CYAN)
end)
