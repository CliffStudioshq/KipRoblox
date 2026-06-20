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

-- v0.30: Plot upgrade tiers (client-side display)
local PLOT_BUILDING_NAMES = {
    "Empty Plot", "Data Outpost", "Server Room", "Data Center",
    "Tech Campus", "Quantum Labs", "Neural Nexus", "Singularity Core"
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

local plotLabel = Instance.new("TextLabel")
plotLabel.Size = UDim2.new(0, 100, 1, 0); plotLabel.BackgroundTransparency = 1
plotLabel.Text = "📦 Empty Plot"; plotLabel.TextColor3 = C.DIM
plotLabel.TextSize = 14; plotLabel.Font = Enum.Font.GothamBold
plotLabel.TextXAlignment = Enum.TextXAlignment.Left; plotLabel.Parent = dataBar

local sep2 = Instance.new("Frame"); sep2.Size = UDim2.new(0,1,0,24)
sep2.BackgroundColor3 = C.BORDER; sep2.BackgroundTransparency = 0.3; sep2.Parent = dataBar

local dpsLabel = Instance.new("TextLabel")
dpsLabel.Size = UDim2.new(0, 72, 1, 0); dpsLabel.BackgroundTransparency = 1
dpsLabel.Text = "⚡ 1/s"; dpsLabel.TextColor3 = C.CYAN
dpsLabel.TextSize = 13; dpsLabel.Font = Enum.Font.GothamBold
dpsLabel.TextXAlignment = Enum.TextXAlignment.Left; dpsLabel.Parent = dataBar

-- ---- TITLE (top bar) ----
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 60, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = ""
titleLabel.TextColor3 = C.GOLD
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = dataBar

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
local shopBtn    = Btn("🏪  Upgrade Shop [F]", C.BLUE)
local statsBtn   = Btn("📊  Stats",           Color3.fromRGB(50,50,75))

-- ============================================================
-- v0.30 NEW UI: Plot Info Frame (bottom-left)
-- ============================================================
local plotInfoFrame = Instance.new("Frame")
plotInfoFrame.Size = UDim2.new(0, 200, 0, 120)
plotInfoFrame.Position = UDim2.new(0, 10, 1, -130)
plotInfoFrame.BackgroundColor3 = C.BG
plotInfoFrame.BackgroundTransparency = 0.1
plotInfoFrame.Visible = false
plotInfoFrame.Parent = gui
corner(plotInfoFrame, 12)
stroke(plotInfoFrame, C.BORDER)

local plotInfoPad = Instance.new("UIPadding")
plotInfoPad.PaddingTop = UDim.new(0, 8)
plotInfoPad.PaddingBottom = UDim.new(0, 8)
plotInfoPad.PaddingLeft = UDim.new(0, 10)
plotInfoPad.PaddingRight = UDim.new(0, 10)
plotInfoPad.Parent = plotInfoFrame

local plotInfoLayout = Instance.new("UIListLayout")
plotInfoLayout.Padding = UDim.new(0, 4)
plotInfoLayout.Parent = plotInfoFrame

local plotInfoTitle = Instance.new("TextLabel")
plotInfoTitle.Size = UDim2.new(1, 0, 0, 18)
plotInfoTitle.BackgroundTransparency = 1
plotInfoTitle.Text = "📦 My Plot"
plotInfoTitle.TextColor3 = C.WHITE
plotInfoTitle.TextSize = 14
plotInfoTitle.Font = Enum.Font.GothamBold
plotInfoTitle.TextXAlignment = Enum.TextXAlignment.Left
plotInfoTitle.Parent = plotInfoFrame

local plotBuildingLabel = Instance.new("TextLabel")
plotBuildingLabel.Size = UDim2.new(1, 0, 0, 16)
plotBuildingLabel.BackgroundTransparency = 1
plotBuildingLabel.Text = "Building: —"
plotBuildingLabel.TextColor3 = C.DIM
plotBuildingLabel.TextSize = 12
plotBuildingLabel.Font = Enum.Font.Gotham
plotBuildingLabel.TextXAlignment = Enum.TextXAlignment.Left
plotBuildingLabel.Parent = plotInfoFrame

local plotDpsBonusLabel = Instance.new("TextLabel")
plotDpsBonusLabel.Size = UDim2.new(1, 0, 0, 16)
plotDpsBonusLabel.BackgroundTransparency = 1
plotDpsBonusLabel.Text = "DPS Bonus: —"
plotDpsBonusLabel.TextColor3 = C.CYAN
plotDpsBonusLabel.TextSize = 12
plotDpsBonusLabel.Font = Enum.Font.Gotham
plotDpsBonusLabel.TextXAlignment = Enum.TextXAlignment.Left
plotDpsBonusLabel.Parent = plotInfoFrame

local plotDecorTitle = Instance.new("TextLabel")
plotDecorTitle.Size = UDim2.new(1, 0, 0, 14)
plotDecorTitle.BackgroundTransparency = 1
plotDecorTitle.Text = "Decorations"
plotDecorTitle.TextColor3 = C.WHITE
plotDecorTitle.TextSize = 12
plotDecorTitle.Font = Enum.Font.GothamBold
plotDecorTitle.TextXAlignment = Enum.TextXAlignment.Left
plotDecorTitle.Parent = plotInfoFrame

local decorSlotsFrame = Instance.new("Frame")
decorSlotsFrame.Size = UDim2.new(1, 0, 0, 22)
decorSlotsFrame.BackgroundTransparency = 1
decorSlotsFrame.Parent = plotInfoFrame

local decorSlotsLayout = Instance.new("UIListLayout")
decorSlotsLayout.FillDirection = Enum.FillDirection.Horizontal
decorSlotsLayout.Padding = UDim.new(0, 6)
decorSlotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
decorSlotsLayout.Parent = decorSlotsFrame

local decorSlotLabels = {}
for i = 1, 3 do
    local slot = Instance.new("TextLabel")
    slot.Name = "Slot" .. tostring(i)
    slot.Size = UDim2.new(0, 56, 1, 0)
    slot.BackgroundColor3 = C.CARD
    slot.BackgroundTransparency = 0.1
    slot.Text = "Empty"
    slot.TextColor3 = C.DIM
    slot.TextSize = 11
    slot.Font = Enum.Font.GothamBold
    slot.Parent = decorSlotsFrame
    corner(slot, 8)
    stroke(slot, C.BORDER)
    decorSlotLabels[i] = slot
end

-- ============================================================
-- v0.30 NEW UI: Shop GUI (F key)
-- ============================================================
local shopFrame = Instance.new("Frame")
shopFrame.Size = UDim2.new(0, 500, 0, 400)
shopFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
shopFrame.BackgroundColor3 = C.BG
shopFrame.BackgroundTransparency = 0.05
shopFrame.Visible = false
shopFrame.Parent = gui
corner(shopFrame, 16)
stroke(shopFrame, C.BORDER)

local shopTop = Instance.new("Frame")
shopTop.Size = UDim2.new(1, -20, 0, 44)
shopTop.Position = UDim2.new(0, 10, 0, 10)
shopTop.BackgroundTransparency = 1
shopTop.Parent = shopFrame

local shopTitle2 = Instance.new("TextLabel")
shopTitle2.Size = UDim2.new(0.5, 0, 1, 0)
shopTitle2.BackgroundTransparency = 1
shopTitle2.Text = "🛒 Shop"
shopTitle2.TextColor3 = C.WHITE
shopTitle2.TextSize = 18
shopTitle2.Font = Enum.Font.GothamBold
shopTitle2.TextXAlignment = Enum.TextXAlignment.Left
shopTitle2.Parent = shopTop

local shopDataLabel = Instance.new("TextLabel")
shopDataLabel.Size = UDim2.new(0.5, 0, 1, 0)
shopDataLabel.BackgroundTransparency = 1
shopDataLabel.Text = "💰 0"
shopDataLabel.TextColor3 = C.GREEN
shopDataLabel.TextSize = 16
shopDataLabel.Font = Enum.Font.GothamBold
shopDataLabel.TextXAlignment = Enum.TextXAlignment.Right
shopDataLabel.Parent = shopTop

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.new(0, 34, 0, 34)
shopClose.Position = UDim2.new(1, -44, 0, 10)
shopClose.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
shopClose.Text = "✕"
shopClose.TextColor3 = C.WHITE
shopClose.TextSize = 18
shopClose.Font = Enum.Font.GothamBold
shopClose.Parent = shopFrame
corner(shopClose, 10)

local shopTabs = Instance.new("Frame")
shopTabs.Size = UDim2.new(1, -20, 0, 36)
shopTabs.Position = UDim2.new(0, 10, 0, 54)
shopTabs.BackgroundTransparency = 1
shopTabs.Parent = shopFrame

local shopTabsLayout = Instance.new("UIListLayout")
shopTabsLayout.FillDirection = Enum.FillDirection.Horizontal
shopTabsLayout.Padding = UDim.new(0, 8)
shopTabsLayout.Parent = shopTabs

local function TabBtn(text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 155, 1, 0)
    b.BackgroundColor3 = C.CARD
    b.BackgroundTransparency = 0.1
    b.Text = text
    b.TextColor3 = C.WHITE
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.Parent = shopTabs
    corner(b, 10)
    stroke(b, C.BORDER)
    return b
end

local tabPlotBtn = TabBtn("📦 Plot Upgrades")
local tabPlayerBtn = TabBtn("⚡ Player Upgrades")
local tabFunBtn = TabBtn("✨ Fun")

local shopContent = Instance.new("Frame")
shopContent.Size = UDim2.new(1, -20, 1, -100)
shopContent.Position = UDim2.new(0, 10, 0, 92)
shopContent.BackgroundTransparency = 1
shopContent.Parent = shopFrame

local function MakeScrolling(name)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = name
    sc.Size = UDim2.new(1, 0, 1, 0)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 6
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Visible = false
    sc.Parent = shopContent
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = sc
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = sc
    return sc
end

local plotTab = MakeScrolling("PlotTab")
local playerTab = MakeScrolling("PlayerTab")
local funTab = MakeScrolling("FunTab")

local function SelectTab(which)
    plotTab.Visible = which == "plot"
    playerTab.Visible = which == "player"
    funTab.Visible = which == "fun"

    tabPlotBtn.BackgroundColor3 = (which == "plot") and C.BLUE or C.CARD
    tabPlayerBtn.BackgroundColor3 = (which == "player") and C.BLUE or C.CARD
    tabFunBtn.BackgroundColor3 = (which == "fun") and C.BLUE or C.CARD
end
SelectTab("plot")

tabPlotBtn.MouseButton1Click:Connect(function() SelectTab("plot") end)
tabPlayerBtn.MouseButton1Click:Connect(function() SelectTab("player") end)
tabFunBtn.MouseButton1Click:Connect(function() SelectTab("fun") end)

local function ShopRow(parent, icon, name, desc)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 64)
    row.BackgroundColor3 = C.CARD
    row.BackgroundTransparency = 0.08
    row.Parent = parent
    corner(row, 12)
    stroke(row, C.BORDER)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = row

    local iconL = Instance.new("TextLabel")
    iconL.Size = UDim2.new(0, 38, 1, 0)
    iconL.BackgroundTransparency = 1
    iconL.Text = icon or ""
    iconL.TextColor3 = C.WHITE
    iconL.TextSize = 20
    iconL.Font = Enum.Font.GothamBold
    iconL.TextXAlignment = Enum.TextXAlignment.Left
    iconL.Parent = row

    local textWrap = Instance.new("Frame")
    textWrap.Size = UDim2.new(1, -160, 1, 0)
    textWrap.Position = UDim2.new(0, 38, 0, 0)
    textWrap.BackgroundTransparency = 1
    textWrap.Parent = row

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1, 0, 0, 20)
    nm.BackgroundTransparency = 1
    nm.Text = name or "Upgrade"
    nm.TextColor3 = C.WHITE
    nm.TextSize = 14
    nm.Font = Enum.Font.GothamBold
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.Parent = textWrap

    local ds = Instance.new("TextLabel")
    ds.Size = UDim2.new(1, 0, 0, 18)
    ds.Position = UDim2.new(0, 0, 0, 22)
    ds.BackgroundTransparency = 1
    ds.Text = desc or ""
    ds.TextColor3 = C.DIM
    ds.TextSize = 12
    ds.Font = Enum.Font.Gotham
    ds.TextXAlignment = Enum.TextXAlignment.Left
    ds.TextWrapped = true
    ds.Parent = textWrap

    local meta = Instance.new("TextLabel")
    meta.Size = UDim2.new(0, 76, 1, 0)
    meta.Position = UDim2.new(1, -150, 0, 0)
    meta.BackgroundTransparency = 1
    meta.Text = ""
    meta.TextColor3 = C.DIM
    meta.TextSize = 11
    meta.Font = Enum.Font.GothamBold
    meta.TextXAlignment = Enum.TextXAlignment.Right
    meta.Parent = row

    local buy = Instance.new("TextButton")
    buy.Size = UDim2.new(0, 90, 0, 34)
    buy.Position = UDim2.new(1, -90, 0.5, -17)
    buy.BackgroundColor3 = C.GREEN
    buy.Text = "Buy"
    buy.TextColor3 = Color3.new(1,1,1)
    buy.TextSize = 13
    buy.Font = Enum.Font.GothamBold
    buy.Parent = row
    corner(buy, 10)
    return row, buy, meta
end

-- Placeholder rows (server-driven prices/levels should fill these later)
ShopRow(plotTab, "🏗️", "Upgrade Building", "Increase plot output")
ShopRow(plotTab, "🖼️", "Decoration Slot", "Add or swap decorations")

ShopRow(playerTab, "⚡", "Data Rate", "Earn more data per second")
ShopRow(playerTab, "👟", "Speed", "Move faster")
ShopRow(playerTab, "🧲", "Orb Magnetism", "Collect orbs from farther away")

ShopRow(funTab, "✨", "Title", "Show off with a title")
ShopRow(funTab, "🌈", "Particle Trail", "A subtle trail")
ShopRow(funTab, "🔥", "Fire Trail", "Spicy footsteps")
ShopRow(funTab, "🧸", "Pet", "A buddy that follows you")

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

-- ============================================================
-- v0.30 CLIENT STATE (plot + upgrades)
-- ============================================================
local currentData = 0
local myTitleText = ""
local lastPlayerUpgrade = {}
local plotState = {
    plotId = nil,
    buildingName = nil,
    dpsBonus = nil,
    decorations = {"Empty", "Empty", "Empty"},
}

local function SetTitle(text)
    myTitleText = tostring(text or "")
    titleLabel.Text = (myTitleText ~= "" and ("[" .. myTitleText .. "]") or "")
end

local function UpdatePlotInfoUI()
    plotBuildingLabel.Text = "Building: " .. tostring(plotState.buildingName or "—")
    if plotState.dpsBonus ~= nil then
        plotDpsBonusLabel.Text = "DPS Bonus: +" .. tostring(plotState.dpsBonus)
    else
        plotDpsBonusLabel.Text = "DPS Bonus: —"
    end
    for i = 1, 3 do
        local v = plotState.decorations[i]
        local txt = (v and tostring(v) ~= "" and tostring(v)) or "Empty"
        decorSlotLabels[i].Text = txt
        decorSlotLabels[i].TextColor3 = (txt == "Empty") and C.DIM or C.WHITE
    end
end

local function SetCurrentData(v)
    currentData = tonumber(v) or 0
    if shopDataLabel then
        shopDataLabel.Text = "💰 " .. fmt(currentData)
    end
end

-- Billboard prompts on plot (best-effort; depends on server plot model naming)
local plotBillboards = {}
local function ClearPlotBillboards()
    for _, g in ipairs(plotBillboards) do
        if g and g.Parent then g:Destroy() end
    end
    plotBillboards = {}
end

local function MakeBillboard(part, title, subtitle)
    local bb = Instance.new("BillboardGui")
    bb.Name = "UpgradeBillboard"
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = part
    bb.Parent = part

    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1, 0, 1, 0)
    fr.BackgroundColor3 = C.BG
    fr.BackgroundTransparency = 0.15
    fr.Parent = bb
    corner(fr, 10)
    stroke(fr, C.BORDER)

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -10, 0, 22)
    tl.Position = UDim2.new(0, 5, 0, 4)
    tl.BackgroundTransparency = 1
    tl.Text = title or "Upgrade"
    tl.TextColor3 = C.WHITE
    tl.TextSize = 14
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = fr

    local sl = Instance.new("TextLabel")
    sl.Size = UDim2.new(1, -10, 0, 18)
    sl.Position = UDim2.new(0, 5, 0, 28)
    sl.BackgroundTransparency = 1
    sl.Text = subtitle or "Press [E]"
    sl.TextColor3 = C.DIM
    sl.TextSize = 12
    sl.Font = Enum.Font.Gotham
    sl.TextXAlignment = Enum.TextXAlignment.Left
    sl.Parent = fr

    return bb
end

local function TryAttachPlotBillboards()
    ClearPlotBillboards()
    local plotRoot = nil
    if plotState.plotId then
        plotRoot = workspace:FindFirstChild("Plot_" .. tostring(plotState.plotId)) or workspace:FindFirstChild(tostring(plotState.plotId))
    end
    if not plotRoot then
        for _, inst in ipairs(workspace:GetChildren()) do
            if inst.Name:match("^Plot_") then
                local sign = inst:FindFirstChild("Sign", true)
                local bb = sign and sign:FindFirstChildWhichIsA("BillboardGui", true)
                local lbl = bb and bb:FindFirstChildWhichIsA("TextLabel", true)
                if lbl and lbl.Text == player.Name then
                    plotRoot = inst
                    break
                end
            end
        end
    end
    if not plotRoot then return end

    local buildingPart = plotRoot:FindFirstChild("BuildingUpgrade", true) or plotRoot:FindFirstChild("UpgradeBuilding", true)
    if buildingPart and buildingPart:IsA("BasePart") then
        table.insert(plotBillboards, MakeBillboard(buildingPart, "🏗️ Building", "Press [E] to upgrade"))
    end
    for i = 1, 3 do
        local p = plotRoot:FindFirstChild("DecorSlot" .. tostring(i), true) or plotRoot:FindFirstChild("Decoration" .. tostring(i), true)
        if p and p:IsA("BasePart") then
            local name = plotState.decorations[i] or "Empty"
            table.insert(plotBillboards, MakeBillboard(p, "🖼️ Decor " .. tostring(i), "Current: " .. tostring(name) .. "  [E]"))
        end
    end
end

-- ============================================================
-- v0.30 VISUALS: orb magnetism + fun upgrades
-- ============================================================
local orbRangeRing = nil
local funFx = { trail = nil, auraLight = nil, auraParticles = nil, fire = nil, titleBillboard = nil, petModel = nil }

local function EnsureOrbRing(char, radius)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if radius <= 0 then
        if orbRangeRing and orbRangeRing.Parent then orbRangeRing:Destroy() end
        orbRangeRing = nil
        return
    end
    if not orbRangeRing or not orbRangeRing.Parent then
        local p = Instance.new("Part")
        p.Name = "OrbRangeRing"
        p.Shape = Enum.PartType.Cylinder
        p.Transparency = 0.8
        p.BrickColor = BrickColor.new("Bright blue")
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.Neon
        p.Parent = char
        orbRangeRing = p
    end
    orbRangeRing.Size = Vector3.new(0.2, radius * 2, radius * 2)
    orbRangeRing.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
end

local function ApplyFunUpgrades(char, upgrades)
    if type(upgrades) ~= "table" then return end
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    if not hrp then return end

    if upgrades.particleTrail and upgrades.particleTrail > 0 then
        if not funFx.trail or not funFx.trail.Parent then
            local pe = Instance.new("ParticleEmitter")
            pe.Name = "FunTrail"
            pe.Texture = "rbxassetid://243660364"
            pe.Rate = 12
            pe.Lifetime = NumberRange.new(0.35, 0.6)
            pe.Speed = NumberRange.new(0.5, 1.5)
            pe.SpreadAngle = Vector2.new(20, 20)
            pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
            pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
            pe.Color = ColorSequence.new(C.BLUE)
            pe.Parent = hrp
            funFx.trail = pe
        end
    elseif funFx.trail then
        funFx.trail:Destroy(); funFx.trail = nil
    end

    if upgrades.aura and upgrades.aura > 0 then
        if not funFx.auraLight or not funFx.auraLight.Parent then
            local l = Instance.new("PointLight")
            l.Name = "FunAuraLight"
            l.Brightness = 0.8
            l.Range = 10
            l.Color = C.PURPLE
            l.Parent = hrp
            funFx.auraLight = l
        end
        if not funFx.auraParticles or not funFx.auraParticles.Parent then
            local pe = Instance.new("ParticleEmitter")
            pe.Name = "FunAuraParticles"
            pe.Texture = "rbxassetid://243660364"
            pe.Rate = 8
            pe.Lifetime = NumberRange.new(0.6, 1.0)
            pe.Speed = NumberRange.new(0.2, 0.6)
            pe.SpreadAngle = Vector2.new(360, 360)
            pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
            pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
            pe.Color = ColorSequence.new(C.PURPLE)
            pe.Parent = hrp
            funFx.auraParticles = pe
        end
    else
        if funFx.auraLight then funFx.auraLight:Destroy(); funFx.auraLight = nil end
        if funFx.auraParticles then funFx.auraParticles:Destroy(); funFx.auraParticles = nil end
    end

    if upgrades.fireTrail and upgrades.fireTrail > 0 then
        if not funFx.fire or not funFx.fire.Parent then
            local f = Instance.new("Fire")
            f.Name = "FunFire"
            f.Heat = 2
            f.Size = 3
            f.Parent = hrp
            funFx.fire = f
        end
    elseif funFx.fire then
        funFx.fire:Destroy(); funFx.fire = nil
    end

    if upgrades.title and tostring(upgrades.title) ~= "" and head then
        SetTitle(upgrades.title)
        if not funFx.titleBillboard or not funFx.titleBillboard.Parent then
            local bb = Instance.new("BillboardGui")
            bb.Name = "TitleBillboard"
            bb.Size = UDim2.new(0, 200, 0, 40)
            bb.StudsOffset = Vector3.new(0, 2.6, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = head
            bb.Parent = head
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Text = tostring(upgrades.title)
            tl.TextColor3 = C.GOLD
            tl.TextSize = 16
            tl.Font = Enum.Font.GothamBold
            tl.TextStrokeTransparency = 0.6
            tl.TextStrokeColor3 = Color3.new(0,0,0)
            tl.Parent = bb
            funFx.titleBillboard = bb
        else
            local tl = funFx.titleBillboard:FindFirstChildWhichIsA("TextLabel")
            if tl then tl.Text = tostring(upgrades.title) end
        end
    else
        SetTitle("")
        if funFx.titleBillboard then funFx.titleBillboard:Destroy(); funFx.titleBillboard = nil end
    end

    if upgrades.pet and upgrades.pet > 0 then
        if not funFx.petModel or not funFx.petModel.Parent then
            local m = Instance.new("Model")
            m.Name = "Pet"
            local body = Instance.new("Part")
            body.Name = "Body"
            body.Size = Vector3.new(1.5, 1.5, 1.5)
            body.Shape = Enum.PartType.Ball
            body.Material = Enum.Material.Neon
            body.Color = C.BLUE
            body.Anchored = false
            body.CanCollide = false
            body.Parent = m
            m.PrimaryPart = body
            m.Parent = workspace
            local att0 = Instance.new("Attachment")
            att0.Parent = body
            local lv = Instance.new("LinearVelocity")
            lv.Name = "PetVelocity"
            lv.Attachment0 = att0
            lv.MaxForce = math.huge
            lv.VectorVelocity = Vector3.zero
            lv.Parent = body
            funFx.petModel = m
            task.spawn(function()
                while m and m.Parent and char and char.Parent do
                    task.wait(0.1)
                    local hrp2 = char:FindFirstChild("HumanoidRootPart")
                    if not hrp2 then continue end
                    local target = hrp2.Position + Vector3.new(2, 1, 2)
                    local delta = target - body.Position
                    lv.VectorVelocity = delta * 4
                end
            end)
        end
    else
        if funFx.petModel then funFx.petModel:Destroy(); funFx.petModel = nil end
    end
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
    -- v0.30 shop currency display
    SetCurrentData(v)
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

    -- v0.30: House leaderstat removed; plot info shown via plotLabel
    local hv = ls:WaitForChild("House", 10)
    if hv then
        hv.Changed:Connect(function() end)
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
    local dataUpdEv    = Ev("DataUpdated")
    local getDataFn    = Ev("GetPlayerData")
    local dataReadyEv  = Ev("PlayerDataReady")

    -- v0.30 upgrade events
    local plotUpgEv = Ev("PlotUpgraded")
    local decorChangedEv = Ev("DecorationChanged")
    local playerUpgEv = Ev("PlayerUpgraded")

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

    -- E key: interact with plot upgrades / shop
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.E then
            -- v0.30: interact with plot upgrade buttons
            -- (server handles proximity checks)
        end
    end)

    -- Stats panel (v0.30: uses new data format)
    local function RefreshStats()
        if not getDataFn then return end
        local ok, result = pcall(function() return getDataFn:InvokeServer() end)
        if not (ok and result) then return end
        local data = (result.ok and result.data) or result
        if not data then return end
        -- Stats rows (simplified for v0.30)
        statValues.data.Text = fmt(data.Data or 0)
        statValues.earned.Text = fmt(data.TotalEarned or 0)
        statValues.spent.Text = fmt(data.TotalSpent or 0)
        statValues.orbs.Text = tostring(data.BlocksCollected or 0)
    end
    if plotUpgEv then
        plotUpgEv.OnClientEvent:Connect(function(plotId, newBuildingName, dpsBonus)
            plotState.plotId = plotId or plotState.plotId
            if newBuildingName ~= nil then plotState.buildingName = newBuildingName end
            if dpsBonus ~= nil then plotState.dpsBonus = dpsBonus end
            plotInfoFrame.Visible = true
            UpdatePlotInfoUI()
            Notify("📦 Plot upgraded!", C.GREEN)
            TryAttachPlotBillboards()
        end)
    end

    if decorChangedEv then
        decorChangedEv.OnClientEvent:Connect(function(plotId, slotIndex, decorName)
            plotState.plotId = plotId or plotState.plotId
            local idx = tonumber(slotIndex)
            if idx and idx >= 1 and idx <= 3 then
                plotState.decorations[idx] = tostring(decorName or "Empty")
            end
            plotInfoFrame.Visible = true
            UpdatePlotInfoUI()
            Notify("🖼️ Decoration updated!", C.BLUE)
            TryAttachPlotBillboards()
        end)
    end

    if playerUpgEv then
        playerUpgEv.OnClientEvent:Connect(function(upgName, level, effect, payload)
            local nm = tostring(upgName or "Upgrade")
            local lv = tonumber(level) or 0
            local ef = effect ~= nil and tostring(effect) or ""
            Notify("⬆️ " .. nm .. " Level " .. tostring(lv) .. ((ef ~= "") and (" (" .. ef .. ")") or "") .. "!", C.GREEN)
            lastPlayerUpgrade[nm] = lv

            -- Apply visuals if included
            if type(payload) == "table" then
                if payload.orbMagnetismLevel then
                    local r = 12 + (tonumber(payload.orbMagnetismLevel) or 0) * 3
                    EnsureOrbRing(player.Character, (tonumber(payload.orbMagnetismLevel) or 0) > 0 and r or 0)
                end
                if payload.fun then
                    ApplyFunUpgrades(player.Character, payload.fun)
                end
                if payload.title then
                    SetTitle(payload.title)
                end
            end
        end)
    end

    -- Re-try billboards once player data is ready
    if dataReadyEv then
        dataReadyEv.OnClientEvent:Connect(function()
            task.delay(0.25, function()
                TryAttachPlotBillboards()
            end)
        end)
    end

    -- Shop currency refresh (every 2s)
    task.spawn(function()
        while gui and gui.Parent do
            task.wait(2)
            SetCurrentData(currentData)
        end
    end)

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

        local plotName = PLOT_BUILDING_NAMES[snapshot.PlotTier] or "Empty Plot"
        statValues.house.Text  = plotName
        statValues.plots.Text  = tostring(#(snapshot.Plots or {}))
        statValues.comps.Text  = tostring(#(snapshot.Computers or {}))
        statValues.orbs.Text   = tostring(snapshot.BlocksCollected or 0)
        statValues.data.Text   = fmt(snapshot.Data)
        statValues.earned.Text = fmt(snapshot.TotalEarned or 0)
        statValues.spent.Text  = fmt(snapshot.TotalSpent or 0)
        -- v0.30: DPS from plot + upgrades (not computers)
        local dps = 0.5  -- base
        if snapshot.PlotTier then
            local tier = math.min(snapshot.PlotTier, #PLOT_BUILDING_NAMES)
            dps = dps + ({0, 5, 15, 50, 150, 400, 1000, 3000})[tier] or 0
        end
        SetDps(dps)
    end

    statsBtn.MouseButton1Click:Connect(function()
        if not statsEnabled then
            Notify("Loading...", C.DIM)
            return
        end
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

    -- v0.30 shop toggle
    local function ToggleShopUI()
        panel.Visible = false
        shopFrame.Visible = not shopFrame.Visible
    end

    shopBtn.MouseButton1Click:Connect(ToggleShopUI)
    shopClose.MouseButton1Click:Connect(function() shopFrame.Visible = false end)

    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.F then
            ToggleShopUI()
        end
    end)

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
