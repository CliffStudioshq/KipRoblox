--[[
    GameClient.client.lua — DataTycoon v0.20
    Clean rewrite: nil-safe event connections, single leaderstats wait,
    proper pcall around every server call.
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[CLIENT] v0.20 starting...")

-- ============================================================
-- COLORS
-- ============================================================
local C = {
    BG      = Color3.fromRGB(14, 14, 24),
    CARD    = Color3.fromRGB(22, 22, 40),
    GREEN   = Color3.fromRGB(0, 210, 110),
    BLUE    = Color3.fromRGB(60, 140, 255),
    PURPLE  = Color3.fromRGB(140, 80, 255),
    ORANGE  = Color3.fromRGB(255, 140, 40),
    RED     = Color3.fromRGB(255, 70, 70),
    CYAN    = Color3.fromRGB(0, 200, 220),
    WHITE   = Color3.fromRGB(240, 240, 255),
    DIM     = Color3.fromRGB(155, 155, 185),
    BORDER  = Color3.fromRGB(42, 42, 68),
}

local HOUSE_NAMES = {"Shack","Small House","Modern House","Tech Villa","Mega Compound"}
-- cost to upgrade TO each tier (tier 2 costs 300, tier 3 costs 1500, etc.)
local HOUSE_COSTS = {0, 300, 1500, 8000, 30000}
local COMP_DPS    = {2, 8, 30, 120}

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=p
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name="DataTycoonHUD"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
gui.Parent=playerGui

-- ---- DATA BAR (top-center) ----
local dataBar = Instance.new("Frame")
dataBar.Size=UDim2.new(0,360,0,46); dataBar.Position=UDim2.new(0.5,-180,0,10)
dataBar.BackgroundColor3=C.BG; dataBar.BackgroundTransparency=0.06
dataBar.Parent=gui; corner(dataBar,23)
local dbs=Instance.new("UIStroke"); dbs.Color=C.BORDER; dbs.Thickness=1; dbs.Parent=dataBar
local dbLayout=Instance.new("UIListLayout"); dbLayout.FillDirection=Enum.FillDirection.Horizontal
dbLayout.VerticalAlignment=Enum.VerticalAlignment.Center; dbLayout.Padding=UDim.new(0,0); dbLayout.Parent=dataBar
local dbPad=Instance.new("UIPadding"); dbPad.PaddingLeft=UDim.new(0,14); dbPad.PaddingRight=UDim.new(0,14); dbPad.Parent=dataBar

local dataLabel = Instance.new("TextLabel")
dataLabel.Size=UDim2.new(0,140,1,0); dataLabel.BackgroundTransparency=1
dataLabel.Text="💰  Loading..."; dataLabel.TextColor3=C.GREEN
dataLabel.TextSize=17; dataLabel.Font=Enum.Font.GothamBold
dataLabel.TextXAlignment=Enum.TextXAlignment.Left; dataLabel.Parent=dataBar

local sep1=Instance.new("Frame"); sep1.Size=UDim2.new(0,1,0,22)
sep1.BackgroundColor3=C.BORDER; sep1.BackgroundTransparency=0.3; sep1.Parent=dataBar

local houseLabel = Instance.new("TextLabel")
houseLabel.Size=UDim2.new(0,95,1,0); houseLabel.BackgroundTransparency=1
houseLabel.Text="🏠 Shack"; houseLabel.TextColor3=C.DIM
houseLabel.TextSize=14; houseLabel.Font=Enum.Font.GothamBold
houseLabel.TextXAlignment=Enum.TextXAlignment.Left; houseLabel.Parent=dataBar

local sep2=Instance.new("Frame"); sep2.Size=UDim2.new(0,1,0,22)
sep2.BackgroundColor3=C.BORDER; sep2.BackgroundTransparency=0.3; sep2.Parent=dataBar

local dpsLabel = Instance.new("TextLabel")
dpsLabel.Size=UDim2.new(0,68,1,0); dpsLabel.BackgroundTransparency=1
dpsLabel.Text="⚡ 1/s"; dpsLabel.TextColor3=C.CYAN
dpsLabel.TextSize=13; dpsLabel.Font=Enum.Font.GothamBold
dpsLabel.TextXAlignment=Enum.TextXAlignment.Left; dpsLabel.Parent=dataBar

-- ---- LEFT SIDEBAR ----
local sidebar = Instance.new("Frame")
sidebar.Size=UDim2.new(0,165,0,0); sidebar.Position=UDim2.new(0,10,0,70)
sidebar.BackgroundColor3=C.CARD; sidebar.BackgroundTransparency=0.08
sidebar.AutomaticSize=Enum.AutomaticSize.Y; sidebar.Parent=gui; corner(sidebar,12)
local sbStroke=Instance.new("UIStroke"); sbStroke.Color=C.BORDER; sbStroke.Thickness=1; sbStroke.Parent=sidebar
local sbL=Instance.new("UIListLayout"); sbL.Padding=UDim.new(0,5); sbL.Parent=sidebar
local sbP=Instance.new("UIPadding")
sbP.PaddingTop=UDim.new(0,8); sbP.PaddingBottom=UDim.new(0,8)
sbP.PaddingLeft=UDim.new(0,8); sbP.PaddingRight=UDim.new(0,8); sbP.Parent=sidebar

local function Btn(text, color)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,36); b.BackgroundColor3=color
    b.Text=text; b.TextColor3=Color3.new(1,1,1)
    b.TextSize=12; b.Font=Enum.Font.GothamBold
    b.AutoButtonColor=true; b.Parent=sidebar; corner(b,7)
    return b
end

local dailyBtn    = Btn("🎁  Daily Reward",  C.ORANGE)
local collectBtn  = Btn("⛏️  Collect Orb",   C.BLUE)
local buyPlotBtn  = Btn("📦  Buy Plot  [E]", C.GREEN)
local compBtn     = Btn("💻  Buy Computer",  C.PURPLE)
local statsBtn    = Btn("📊  Stats",         Color3.fromRGB(50,50,75))

-- ---- NOTIFICATION ----
local notif = Instance.new("TextLabel")
notif.Size=UDim2.new(0,360,0,34); notif.Position=UDim2.new(0.5,-180,0,64)
notif.BackgroundTransparency=1; notif.Text=""
notif.TextColor3=C.WHITE; notif.TextSize=15; notif.Font=Enum.Font.GothamBold
notif.TextStrokeTransparency=0.5; notif.TextStrokeColor3=Color3.new(0,0,0)
notif.TextTransparency=1; notif.Parent=gui

local notifQ={}; local notifBusy=false

local function Notify(msg, color)
    table.insert(notifQ, {msg=msg, color=color or C.WHITE})
    if notifBusy then return end
    notifBusy=true
    task.spawn(function()
        while #notifQ>0 do
            local n=table.remove(notifQ,1)
            notif.Text=n.msg; notif.TextColor3=n.color; notif.TextTransparency=1
            for i=0,1,0.12 do notif.TextTransparency=1-i; task.wait(0.025) end
            task.wait(1.8)
            for i=0,1,0.1 do notif.TextTransparency=i; task.wait(0.025) end
        end
        notifBusy=false
    end)
end

-- ---- STATS PANEL ----
local panel = Instance.new("Frame")
panel.Size=UDim2.new(0,295,0,370); panel.Position=UDim2.new(0.5,-147,0.5,-185)
panel.BackgroundColor3=C.BG; panel.BackgroundTransparency=0.04
panel.Visible=false; panel.Parent=gui; corner(panel,14)
local pStroke=Instance.new("UIStroke"); pStroke.Color=C.BORDER; pStroke.Thickness=1; pStroke.Parent=panel

local ptitle=Instance.new("TextLabel"); ptitle.Size=UDim2.new(1,-40,0,40)
ptitle.Position=UDim2.new(0,14,0,0); ptitle.BackgroundTransparency=1
ptitle.Text="📊  Stats"; ptitle.TextColor3=C.WHITE; ptitle.TextSize=17
ptitle.Font=Enum.Font.GothamBold; ptitle.TextXAlignment=Enum.TextXAlignment.Left; ptitle.Parent=panel

local pclose=Instance.new("TextButton"); pclose.Size=UDim2.new(0,26,0,26)
pclose.Position=UDim2.new(1,-32,0,7); pclose.BackgroundColor3=C.RED
pclose.Text="✕"; pclose.TextColor3=Color3.new(1,1,1); pclose.TextSize=12
pclose.Font=Enum.Font.GothamBold; pclose.Parent=panel; corner(pclose,6)

local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,-16,1,-92)
scroll.Position=UDim2.new(0,8,0,42); scroll.BackgroundTransparency=1
scroll.ScrollBarThickness=3; scroll.CanvasSize=UDim2.new(0,0,0,320); scroll.Parent=panel
local scrollL=Instance.new("UIListLayout"); scrollL.Padding=UDim.new(0,4); scrollL.Parent=scroll

local function Row(icon, label, val, valColor)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,32)
    row.BackgroundColor3=C.CARD; row.BackgroundTransparency=0.25; row.Parent=scroll; corner(row,6)
    local ic=Instance.new("TextLabel"); ic.Size=UDim2.new(0,22,1,0); ic.Position=UDim2.new(0,5,0,0)
    ic.BackgroundTransparency=1; ic.Text=icon; ic.TextSize=14; ic.Font=Enum.Font.GothamBold
    ic.TextColor3=C.WHITE; ic.Parent=row
    local nl=Instance.new("TextLabel"); nl.Size=UDim2.new(0.55,-24,1,0); nl.Position=UDim2.new(0,27,0,0)
    nl.BackgroundTransparency=1; nl.Text=label; nl.TextColor3=C.DIM; nl.TextSize=12
    nl.Font=Enum.Font.Gotham; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=row
    local vl=Instance.new("TextLabel"); vl.Name="Val"; vl.Size=UDim2.new(0.45,-6,1,0)
    vl.Position=UDim2.new(0.55,0,0,0); vl.BackgroundTransparency=1; vl.Text=val
    vl.TextColor3=valColor or C.WHITE; vl.TextSize=13; vl.Font=Enum.Font.GothamBold
    vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row
    return vl
end

local sHouse  = Row("🏠","House",        "Shack",  C.ORANGE)
local sPlots  = Row("📦","Plots",         "0",      C.GREEN)
local sComps  = Row("💻","Computers",     "0",      C.BLUE)
local sOrbs   = Row("⛏️","Orbs Collected","0",      C.CYAN)
local sData   = Row("💰","Data",          "0",      C.GREEN)
local sEarned = Row("📈","Total Earned",  "0",      C.DIM)
local sSpent  = Row("💸","Total Spent",   "0",      C.DIM)
local sDPS    = Row("⚡","Data/sec",      "1/s",    C.CYAN)

local upgradeBtn=Instance.new("TextButton")
upgradeBtn.Size=UDim2.new(1,-16,0,36); upgradeBtn.Position=UDim2.new(0,8,1,-42)
upgradeBtn.BackgroundColor3=C.PURPLE; upgradeBtn.Text="🏠  Upgrade House"
upgradeBtn.TextColor3=Color3.new(1,1,1); upgradeBtn.TextSize=13
upgradeBtn.Font=Enum.Font.GothamBold; upgradeBtn.Parent=panel; corner(upgradeBtn,8)

-- ============================================================
-- DATA DISPLAY
-- ============================================================
local function SetData(v)
    dataLabel.Text = "💰  "..tostring(v)
    dataLabel.TextColor3 = Color3.fromRGB(120,255,160)
    task.delay(0.12, function() dataLabel.TextColor3 = C.GREEN end)
end

-- ============================================================
-- STEP 1: Wait for leaderstats (simple, direct)
-- ============================================================
task.spawn(function()
    print("[CLIENT] Waiting for leaderstats...")
    local ls = player:WaitForChild("leaderstats", 30)
    if not ls then
        warn("[CLIENT] No leaderstats after 30s")
        dataLabel.Text = "💰  ERR"
        dataLabel.TextColor3 = C.RED
        return
    end
    print("[CLIENT] leaderstats found")

    local dv = ls:WaitForChild("Data", 10)
    if dv then
        SetData(dv.Value)
        dv.Changed:Connect(SetData)
        print("[CLIENT] Data connected, value="..dv.Value)
    else
        warn("[CLIENT] No Data value in leaderstats")
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
-- STEP 2: Wait for Events, connect everything
-- ============================================================
task.spawn(function()
    print("[CLIENT] Waiting for Events folder...")
    local Events = ReplicatedStorage:WaitForChild("Events", 30)
    if not Events then
        warn("[CLIENT] No Events folder after 30s — buttons won't work")
        Notify("⚠️ Connection failed — try rejoining", C.RED)
        return
    end
    print("[CLIENT] Events found, connecting...")

    -- Helper: get event safely
    local function Ev(name)
        local e = Events:WaitForChild(name, 10)
        if not e then warn("[CLIENT] Missing event: "..name) end
        return e
    end

    local claimEv     = Ev("ClaimDailyReward")
    local claimedEv   = Ev("DailyRewardClaimed")
    local notifEv     = Ev("Notification")
    local collectEv   = Ev("CollectOrb")
    local buyPlotEv   = Ev("PurchasePlot")
    local plotPurchEv = Ev("PlotPurchased")
    local upgradeEv   = Ev("UpgradeHouse")
    local placeCompEv = Ev("PlaceComputer")
    local compPlacEv  = Ev("ComputerPlaced")
    local houseUpgEv  = Ev("HouseUpgraded")
    local dataUpdEv   = Ev("DataUpdated")
    local getDataFn   = Ev("GetPlayerData")

    -- Backup data sync
    if dataUpdEv then
        dataUpdEv.OnClientEvent:Connect(function(v)
            SetData(v)
        end)
    end

    -- Server notifications
    if notifEv then
        notifEv.OnClientEvent:Connect(function(msg, t)
            local col = C.WHITE
            if t=="success" then col=C.GREEN
            elseif t=="error" then col=C.RED end
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
            Notify("Day "..streak..": +"..reward.." Data! 🎉", C.GREEN)
            dailyBtn.Text="✅ Claimed!"
            dailyBtn.BackgroundColor3=Color3.fromRGB(50,50,70)
            task.delay(3, function()
                dailyBtn.Text="🎁  Daily Reward"
                dailyBtn.BackgroundColor3=C.ORANGE
            end)
        end)
    end

    -- Collect orb (button)
    if collectEv then
        collectBtn.MouseButton1Click:Connect(function()
            collectEv:FireServer()
        end)
    end

    -- Buy plot (cycles through cheapest first)
    local plotOrder = {"plot_0_3","plot_0_-3","plot_3_0","plot_-3_0","plot_3_3","plot_3_-3","plot_-3_3","plot_-3_-3"}
    local plotIdx = 0
    local function BuyNext()
        if not buyPlotEv then return end
        plotIdx = (plotIdx % #plotOrder) + 1
        buyPlotEv:FireServer(plotOrder[plotIdx])
    end
    buyPlotBtn.MouseButton1Click:Connect(BuyNext)
    UserInputService.InputBegan:Connect(function(inp, gp)
        if not gp and inp.KeyCode==Enum.KeyCode.E then BuyNext() end
    end)

    if plotPurchEv then
        plotPurchEv.OnClientEvent:Connect(function(pid, uid, uname)
            if uid ~= player.UserId then
                Notify(uname.." bought a plot!", Color3.fromRGB(255,210,80))
            end
        end)
    end

    -- Place computer
    if placeCompEv and getDataFn then
        compBtn.MouseButton1Click:Connect(function()
            local ok, data = pcall(function() return getDataFn:InvokeServer() end)
            if ok and data and data.Plots and #data.Plots > 0 then
                placeCompEv:FireServer(data.Plots[1], 1)
            else
                Notify("Buy a plot first!", C.RED)
            end
        end)
    end

    if compPlacEv then
        compPlacEv.OnClientEvent:Connect(function(pid, tier, name)
            Notify(name.." placed! +"..COMP_DPS[tier or 1].."/s", C.BLUE)
            dpsLabel.Text = "⚡ ?"  -- will update on next data tick
        end)
    end

    -- House upgrade
    if upgradeEv then
        upgradeBtn.MouseButton1Click:Connect(function()
            upgradeEv:FireServer()
        end)
    end
    if houseUpgEv then
        houseUpgEv.OnClientEvent:Connect(function(tier, name)
            Notify("Upgraded to "..name.."! 🏠", C.PURPLE)
            houseLabel.Text = "🏠 "..name
        end)
    end

    -- Stats panel
    local function RefreshStats()
        if not getDataFn then return end
        local ok, data = pcall(function() return getDataFn:InvokeServer() end)
        if not (ok and data) then return end
        local hn = HOUSE_NAMES[data.HouseTier] or "Shack"
        sHouse.Text  = hn.." (T"..data.HouseTier..")"
        sPlots.Text  = tostring(data.Plots and #data.Plots or 0)
        sComps.Text  = tostring(data.Computers and #data.Computers or 0)
        sOrbs.Text   = tostring(data.BlocksCollected or 0)
        sData.Text   = tostring(data.Data)
        sEarned.Text = tostring(data.TotalEarned or 0)
        sSpent.Text  = tostring(data.TotalSpent or 0)
        local dps = 1
        if data.Computers then
            for _, c in ipairs(data.Computers) do
                dps = dps + (COMP_DPS[c.tier] or 0)
            end
        end
        sDPS.Text = dps.."/s"; dpsLabel.Text = "⚡ "..dps.."/s"
        local nt = data.HouseTier + 1
        if nt <= #HOUSE_NAMES then
            upgradeBtn.Text = "🏠  "..HOUSE_NAMES[nt].."  ("..HOUSE_COSTS[nt].." Data)"
            upgradeBtn.BackgroundColor3 = C.PURPLE
        else
            upgradeBtn.Text = "✅  Max Level"
            upgradeBtn.BackgroundColor3 = Color3.fromRGB(45,45,65)
        end
    end

    statsBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        if panel.Visible then RefreshStats() end
    end)
    pclose.MouseButton1Click:Connect(function() panel.Visible=false end)

    -- ============================================================
    -- ORB TOUCH COLLECTION
    -- ============================================================
    if collectEv then
        local function hookOrbs(folder)
            local debounce = {}
            local function onTouch(hit)
                local char = hit.Parent
                local plr = Players:GetPlayerFromCharacter(char)
                if plr ~= player then return end
                local now = tick()
                if debounce[hit] and (now - debounce[hit]) < 0.5 then return end
                debounce[hit] = now
                collectEv:FireServer()
            end
            local n = 0
            for _, d in ipairs(folder:GetDescendants()) do
                if d:IsA("BasePart") and d.Name=="OrbRing" then
                    d.Touched:Connect(onTouch); n=n+1
                end
            end
            folder.DescendantAdded:Connect(function(d)
                task.wait(0.05)
                if d:IsA("BasePart") and d.Name=="OrbRing" then
                    d.Touched:Connect(onTouch)
                end
            end)
            print("[CLIENT] Hooked "..n.." orb rings")
        end

        -- Try immediately, then wait up to 30s
        local orbFolder = workspace:FindFirstChild("DataOrbs")
        if orbFolder then
            hookOrbs(orbFolder)
        else
            task.spawn(function()
                local f = workspace:WaitForChild("DataOrbs", 30)
                if f then hookOrbs(f)
                else warn("[CLIENT] DataOrbs folder never appeared") end
            end)
        end
    end

    print("[CLIENT] ✅ All systems connected!")
    Notify("DataTycoon loaded! Walk into glowing orbs to collect data.", C.CYAN)
end)
