--[[
    Main.server.lua — DataTycoon Server
    v0.19 — Hardened rewrite
    Fixes: walkway/lamp/bench parents, naming collisions, DataStore races,
           debounce on orb collection, nil-data guard in passive loop,
           proper cleanup on PlayerRemoving.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

print("=":rep(40))
print("DataTycoon v0.19 — Server starting...")
print("=":rep(40))

-- ============================================================
-- CRITICAL: Create baseplate + spawn IMMEDIATELY so players
-- never fall through before the rest of the world builds.
-- ============================================================
do
    local base = Instance.new("Part")
    base.Name = "GrassBase"
    base.Size = Vector3.new(512, 4, 512)
    base.Position = Vector3.new(0, -2, 0)
    base.Anchored = true
    base.CanCollide = true
    base.BrickColor = BrickColor.new("Dark green")
    base.Material = Enum.Material.Grass
    base.Parent = workspace

    local spawnPad = Instance.new("Part")
    spawnPad.Name = "SpawnPlatform"
    spawnPad.Size = Vector3.new(14, 3, 14)
    spawnPad.Position = Vector3.new(0, 1.5, 0)
    spawnPad.Anchored = true
    spawnPad.BrickColor = BrickColor.new("Bright green")
    spawnPad.Material = Enum.Material.SmoothPlastic
    spawnPad.Parent = workspace

    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Size = Vector3.new(10, 1, 10)
    spawnLoc.Position = Vector3.new(0, 3.5, 0)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = false
    spawnLoc.Transparency = 1
    spawnLoc.Parent = workspace

    print("[OK] Baseplate + spawn created (early)")
end

local DataStore = DataStoreService:GetDataStore("DataTycoon_v4")

-- ============================================================
-- CREATE REMOTE EVENTS
-- ============================================================
local Events = Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

local function CreateEvent(name, className)
    local event = Instance.new(className or "RemoteEvent")
    event.Name = name
    event.Parent = Events
    return event
end

-- Client → Server
local ClaimDailyReward = CreateEvent("ClaimDailyReward")
local CollectOrb     = CreateEvent("CollectOrb")
local PurchasePlot   = CreateEvent("PurchasePlot")
local SellPlot       = CreateEvent("SellPlot")
local PlaceComputer  = CreateEvent("PlaceComputer")
local UpgradeHouse   = CreateEvent("UpgradeHouse")

-- Server → Client
local DailyRewardClaimed = CreateEvent("DailyRewardClaimed")
local Notification       = CreateEvent("Notification")
local DataUpdated        = CreateEvent("DataUpdated")
local PlotPurchased      = CreateEvent("PlotPurchased")
local PlotSold           = CreateEvent("PlotSold")
local ComputerPlaced     = CreateEvent("ComputerPlaced")
local HouseUpgraded      = CreateEvent("HouseUpgraded")

-- Remote Function
local GetPlayerData = CreateEvent("GetPlayerData", "RemoteFunction")

print("[OK] RemoteEvents created")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    STARTING_DATA  = 50,
    ORB_REWARD     = 5,
    PASSIVE_INCOME = 1,

    COMPUTER_TIERS = {
        {name = "Budget Rig",    cost = 100,   dps = 2},
        {name = "Gaming PC",     cost = 500,   dps = 8},
        {name = "Server Rack",   cost = 2500,  dps = 30},
        {name = "Supercomputer", cost = 10000, dps = 120},
    },

    HOUSE_TIERS = {
        {name = "Shack",         cost = 0,     maxComputers = 1, maxPlots = 2},
        {name = "Small House",   cost = 300,   maxComputers = 2, maxPlots = 4},
        {name = "Modern House",  cost = 1500,  maxComputers = 4, maxPlots = 8},
        {name = "Tech Villa",    cost = 8000,  maxComputers = 8, maxPlots = 8},
        {name = "Mega Compound", cost = 30000, maxComputers = 16, maxPlots = 8},
    },

    DAILY_REWARDS = {50, 75, 100, 150, 200, 300, 500},
}

-- ============================================================
-- PLAYER DATA
-- ============================================================
local PlayerData = {}

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    TotalSpent = 0,
    Plots = {},
    Computers = {},
    HouseTier = 1,
    LastLogin = 0,
    DailyStreak = 0,
    LastDailyReward = 0,
    BlocksCollected = 0,
}

-- ============================================================
-- PLOT SYSTEM
-- ============================================================
local Plots = {}

local function InitPlots()
    local coords = {
        {-3,-3},{-3,3},{3,-3},{3,3},
        {0,-3},{0,3},{-3,0},{3,0},
    }
    for _, c in ipairs(coords) do
        local x, z = c[1], c[2]
        local dist = math.max(math.abs(x), math.abs(z))
        local plotId = "plot_" .. x .. "_" .. z
        local price = math.floor(50 * (2 ^ dist))
        local spacing = 170
        Plots[plotId] = {
            id = plotId, owner = nil, ownerName = nil,
            x = x, z = z, dist = dist, price = price,
            center = Vector3.new(x * spacing, 0.5, z * spacing),
            computers = {},
        }
    end
    local count = 0
    for _ in pairs(Plots) do count = count + 1 end
    print("[OK] " .. count .. " plots initialized")
end

-- ============================================================
-- DATA FUNCTIONS
-- ============================================================
local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, savedData = pcall(function()
        return DataStore:GetAsync(key)
    end)

    if success and savedData then
        -- Merge saved data with defaults (handles new fields added in updates)
        for k, v in pairs(DEFAULT_DATA) do
            if savedData[k] == nil then savedData[k] = v end
        end
        PlayerData[player.UserId] = savedData
        print("[DATA] Loaded " .. player.Name .. " (Data: " .. savedData.Data .. ")")
    else
        PlayerData[player.UserId] = {}
        for k, v in pairs(DEFAULT_DATA) do
            PlayerData[player.UserId][k] = v
        end
        print("[DATA] New player " .. player.Name)
    end

    -- Create leaderstats
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = PlayerData[player.UserId].Data
    dataValue.Parent = leaderstats

    local houseValue = Instance.new("IntValue")
    houseValue.Name = "House"
    houseValue.Value = PlayerData[player.UserId].HouseTier
    houseValue.Parent = leaderstats

    print("[OK] Leaderstats for " .. player.Name .. " = " .. PlayerData[player.UserId].Data)
end

local function SavePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local key = "Player_" .. player.UserId
    local ok, err = pcall(function()
        DataStore:SetAsync(key, data)
    end)
    if not ok then
        warn("[DATA] Save failed for " .. player.Name .. ": " .. tostring(err))
    end
end

local function UpdateData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local dv = ls:FindFirstChild("Data")
        if dv then dv.Value = data.Data end
    end
    DataUpdated:FireClient(player, data.Data)
end

local function Notify(player, msg, notifType)
    Notification:FireClient(player, msg, notifType or "info")
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local daysSince = math.floor((now - lastClaim) / 86400)
    if daysSince == 0 then
        Notify(player, "Already claimed today!", "error")
        return
    end
    if daysSince > 1 then
        data.DailyStreak = 1
    else
        data.DailyStreak = (data.DailyStreak or 0) + 1
    end
    local idx = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[idx]
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day " .. data.DailyStreak .. ": +" .. reward .. " Data!", "success")
    print("[GAME] " .. player.Name .. " daily reward +" .. reward)
end)

-- Orb collection with server-side debounce
local orbCooldowns = {}

CollectOrb.OnServerEvent:Connect(function(player)
    -- Debounce: prevent spam (0.3s cooldown per player)
    local now = tick()
    if orbCooldowns[player.UserId] and (now - orbCooldowns[player.UserId]) < 0.3 then
        return
    end
    orbCooldowns[player.UserId] = now

    local data = PlayerData[player.UserId]
    if not data then return end
    data.Data = data.Data + CONFIG.ORB_REWARD
    data.TotalEarned = data.TotalEarned + CONFIG.ORB_REWARD
    data.BlocksCollected = (data.BlocksCollected or 0) + 1
    UpdateData(player)
    Notify(player, "+" .. CONFIG.ORB_REWARD .. " Data!", "success")
    print("[GAME] " .. player.Name .. " orb +" .. CONFIG.ORB_REWARD .. " (total: " .. data.Data .. ")")
end)

PurchasePlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot then Notify(player, "Plot not found!", "error") return end
    if plot.owner then Notify(player, "Already owned!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Plots >= ht.maxPlots then Notify(player, "Upgrade house for more plots!", "error") return end
    if data.Data < plot.price then Notify(player, "Need " .. plot.price .. " Data!", "error") return end
    data.Data = data.Data - plot.price
    data.TotalSpent = data.TotalSpent + plot.price
    plot.owner = player.UserId
    plot.ownerName = player.Name
    table.insert(data.Plots, plotId)
    UpdateData(player)
    PlotPurchased:FireAllClients(plotId, player.UserId, player.Name)
    Notify(player, "Plot purchased! (-" .. plot.price .. ")", "success")
    print("[GAME] " .. player.Name .. " bought " .. plotId)
end)

SellPlot.OnServerEvent:Connect(function(player, plotId)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    local sellPrice = math.floor(plot.price * 0.5)
    data.Data = data.Data + sellPrice
    data.TotalEarned = data.TotalEarned + sellPrice
    plot.owner = nil; plot.ownerName = nil
    for i = #data.Plots, 1, -1 do
        if data.Plots[i] == plotId then table.remove(data.Plots, i) break end
    end
    for i = #data.Computers, 1, -1 do
        if data.Computers[i].plotId == plotId then table.remove(data.Computers, i) end
    end
    plot.computers = {}
    UpdateData(player)
    PlotSold:FireAllClients(plotId)
    Notify(player, "Sold for " .. sellPrice .. " Data!", "success")
end)

PlaceComputer.OnServerEvent:Connect(function(player, plotId, tier)
    local plot = Plots[plotId]
    if not plot or plot.owner ~= player.UserId then Notify(player, "Not your plot!", "error") return end
    local data = PlayerData[player.UserId]
    if not data then return end
    tier = tier or 1
    local ct = CONFIG.COMPUTER_TIERS[tier]
    if not ct then Notify(player, "Invalid tier!", "error") return end
    local ht = CONFIG.HOUSE_TIERS[data.HouseTier]
    if #data.Computers >= ht.maxComputers then Notify(player, "Upgrade house!", "error") return end
    if data.Data < ct.cost then Notify(player, "Need " .. ct.cost .. " Data!", "error") return end
    data.Data = data.Data - ct.cost
    data.TotalSpent = data.TotalSpent + ct.cost
    local comp = {tier = tier, plotId = plotId, name = ct.name, dps = ct.dps}
    table.insert(data.Computers, comp)
    table.insert(plot.computers, comp)
    UpdateData(player)
    ComputerPlaced:FireClient(player, plotId, tier, ct.name)
    Notify(player, ct.name .. " placed! (+" .. ct.dps .. "/s)", "success")
    print("[GAME] " .. player.Name .. " placed " .. ct.name)
end)

UpgradeHouse.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local nextTier = data.HouseTier + 1
    if nextTier > #CONFIG.HOUSE_TIERS then Notify(player, "Max level!", "error") return end
    local cost = CONFIG.HOUSE_TIERS[nextTier].cost
    if data.Data < cost then Notify(player, "Need " .. cost .. " Data!", "error") return end
    data.Data = data.Data - cost
    data.TotalSpent = data.TotalSpent + cost
    data.HouseTier = nextTier
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local hv = ls:FindFirstChild("House")
        if hv then hv.Value = nextTier end
    end
    UpdateData(player)
    HouseUpgraded:FireClient(player, nextTier, CONFIG.HOUSE_TIERS[nextTier].name)
    Notify(player, "Upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name .. "!", "success")
    print("[GAME] " .. player.Name .. " upgraded to " .. CONFIG.HOUSE_TIERS[nextTier].name)
end)

GetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

print("[OK] Event handlers connected")

-- ============================================================
-- PASSIVE INCOME (1 Data/sec base + computers)
-- ============================================================
task.spawn(function()
    print("[OK] Passive income loop started")
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                local totalDPS = CONFIG.PASSIVE_INCOME
                if data.Computers then
                    for _, comp in ipairs(data.Computers) do
                        local tier = CONFIG.COMPUTER_TIERS[comp.tier]
                        if tier then totalDPS = totalDPS + tier.dps end
                    end
                end
                data.Data = data.Data + totalDPS
                data.TotalEarned = data.TotalEarned + totalDPS
                UpdateData(p)
            end
        end
    end
end)

-- ============================================================
-- PLAYER CONNECTIONS
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    print("[JOIN] " .. player.Name)
    LoadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    print("[LEAVE] " .. player.Name)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
    orbCooldowns[player.UserId] = nil
end)

game:BindToClose(function()
    for _, p in ipairs(Players:GetPlayers()) do SavePlayerData(p) end
end)

-- ============================================================
-- WORLD BUILDING
-- ============================================================
task.spawn(function()
print("[BUILD] Starting world build...")

-- Helper: create part with explicit properties
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.Name = props.name or "Part"
    p.Size = props.size or Vector3.new(4, 4, 4)
    p.Position = props.pos or Vector3.new(0, 0, 0)
    p.BrickColor = props.color or BrickColor.new("Medium stone grey")
    p.Material = props.mat or Enum.Material.SmoothPlastic
    p.Transparency = props.alpha or 0
    p.Shape = props.shape or Enum.PartType.Block
    if props.collide ~= nil then
        p.CanCollide = props.collide
    else
        p.CanCollide = true
    end
    p.Parent = props.parent or workspace
    if props.rotation then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.rotation), 0)
    end
    return p
end

-- Helper: create a PointLight inside a tiny anchor
local function makeLight(pos, color, brightness, range)
    local anchor = makePart({
        name = "LightAnchor",
        size = Vector3.new(0.1, 0.1, 0.1),
        pos = pos,
        alpha = 1,
        collide = false,
    })
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Parent = anchor
    return light
end

-- Baseplate + SpawnLocation already created at top of script (early init block).
print("[OK] Baseplate already exists (created at startup)")

-- === CENTER DATA HUB ===
local hubFolder = Instance.new("Folder")
hubFolder.Name = "DataHub"
hubFolder.Parent = workspace

-- Hub platform
makePart({
    name = "HubPlatform",
    size = Vector3.new(80, 3, 80),
    pos = Vector3.new(0, 1.5, 0),
    color = BrickColor.new("Dark stone grey"),
    mat = Enum.Material.SmoothPlastic,
    parent = hubFolder,
})

-- Hub ring
makePart({
    name = "HubRing",
    size = Vector3.new(50, 0.3, 50),
    pos = Vector3.new(0, 3.0, 0),
    color = BrickColor.new("Medium stone grey"),
    mat = Enum.Material.SmoothPlastic,
    parent = hubFolder,
})

-- Tower floors
for f = 0, 4 do
    local y = 4 + f * 8
    local sz = 22 - f * 2
    local col = f % 2 == 0 and BrickColor.new("Dark stone grey") or BrickColor.new("Medium stone grey")
    makePart({
        name = "TowerFloor" .. f,
        size = Vector3.new(sz, 7, sz),
        pos = Vector3.new(0, y, 0),
        color = col,
        mat = Enum.Material.Metal,
        parent = hubFolder,
    })
    makePart({
        name = "TowerTrim" .. f,
        size = Vector3.new(sz + 0.5, 0.15, sz + 0.5),
        pos = Vector3.new(0, y - 3.3, 0),
        color = BrickColor.new("Cyan"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
end

-- Server racks
for i = 1, 8 do
    local a = (i / 8) * math.pi * 2
    local x, z = math.cos(a) * 28, math.sin(a) * 28
    makePart({
        name = "ServerRack" .. i,
        size = Vector3.new(6, 12, 3),
        pos = Vector3.new(x, 7, z),
        color = BrickColor.new("Dark stone grey"),
        mat = Enum.Material.Metal,
        parent = hubFolder,
    })
    for l = 0, 3 do
        local ledCol = l % 2 == 0 and BrickColor.new("Lime green") or BrickColor.new("Forest green")
        makePart({
            name = "LED" .. i .. "_" .. l,
            size = Vector3.new(0.4, 0.25, 0.4),
            pos = Vector3.new(x, 3 + l * 2.5, z + 1.6),
            color = ledCol,
            mat = Enum.Material.SmoothPlastic,
            parent = hubFolder,
        })
    end
end

-- Data stream pillars
for i = 1, 6 do
    local a = (i / 6) * math.pi * 2
    local px, pz = math.cos(a) * 18, math.sin(a) * 18
    makePart({
        name = "DataPillar" .. i,
        size = Vector3.new(3, 22, 3),
        pos = Vector3.new(px, 12, pz),
        color = BrickColor.new("Medium stone grey"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
    makePart({
        name = "PillarTop" .. i,
        size = Vector3.new(3.5, 0.4, 3.5),
        pos = Vector3.new(px, 1.2, pz),
        color = BrickColor.new("Cyan"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
end

-- Floating orbs
for i = 1, 10 do
    local a = (i / 10) * math.pi * 2
    local r = 12 + (i % 3) * 4
    local col = i % 2 == 0 and BrickColor.new("Cyan") or BrickColor.new("Bright blue")
    makePart({
        name = "HubOrb" .. i,
        size = Vector3.new(2, 2, 2),
        pos = Vector3.new(math.cos(a) * r, 26 + math.sin(i) * 2, math.sin(a) * r),
        color = col,
        mat = Enum.Material.SmoothPlastic,
        shape = Enum.PartType.Ball,
        parent = hubFolder,
    })
end

-- Entrance arches
for i = 1, 4 do
    local a = (i / 4) * math.pi * 2
    local x, z = math.cos(a) * 42, math.sin(a) * 42
    makePart({
        name = "ArchPost" .. i,
        size = Vector3.new(3, 16, 3),
        pos = Vector3.new(x, 9, z),
        color = BrickColor.new("Medium stone grey"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
    makePart({
        name = "ArchTop" .. i,
        size = Vector3.new(3, 2, 10),
        pos = Vector3.new(x, 18, z),
        color = BrickColor.new("Medium stone grey"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
    makePart({
        name = "ArchAccent" .. i,
        size = Vector3.new(3.2, 0.2, 10.2),
        pos = Vector3.new(x, 19.1, z),
        color = BrickColor.new("Cyan"),
        mat = Enum.Material.SmoothPlastic,
        parent = hubFolder,
    })
end

-- Hub lamps
for i = 1, 8 do
    local a = (i / 8) * math.pi * 2
    local x, z = math.cos(a) * 35, math.sin(a) * 35
    makePart({name = "LampPole" .. i, size = Vector3.new(0.5, 8, 0.5), pos = Vector3.new(x, 4, z), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Metal, parent = hubFolder})
    makePart({name = "LampHead" .. i, size = Vector3.new(1.5, 0.5, 1.5), pos = Vector3.new(x, 8.2, z), color = BrickColor.new("Institutional white"), mat = Enum.Material.SmoothPlastic, parent = hubFolder})
    makeLight(Vector3.new(x, 8.2, z), Color3.fromRGB(100, 200, 255), 1.5, 20)
end

print("[OK] Hub done")
task.wait()

-- === WALKWAYS (4 cardinal) ===
local walkFolder = Instance.new("Folder")
walkFolder.Name = "Walkways"
walkFolder.Parent = workspace

local walkColor = BrickColor.new("Medium stone grey")
local walkMat = Enum.Material.Concrete
local walkWidth = 8

for dirIdx, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    local dx, dz = d[1], d[2]
    local mx, mz = dx * 157.5, dz * 157.5
    if dx ~= 0 then
        makePart({name = "Walkway_" .. dirIdx, size = Vector3.new(230, 0.3, walkWidth), pos = Vector3.new(mx, 0.15, mz), color = walkColor, mat = walkMat, parent = walkFolder})
    else
        makePart({name = "Walkway_" .. dirIdx, size = Vector3.new(walkWidth, 0.3, 230), pos = Vector3.new(mx, 0.15, mz), color = walkColor, mat = walkMat, parent = walkFolder})
    end
end

print("[OK] Walkways done")
task.wait()

-- === PLAYER PLOTS (8) ===
local plotFolder = Instance.new("Folder")
plotFolder.Name = "PlotMarkers"
plotFolder.Parent = workspace
local plotCount = 0

for _, pp in ipairs({{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}) do
    local x, z = pp[1], pp[2]
    local dist = math.max(math.abs(x), math.abs(z))
    local cx, cz = x * 170, z * 170
    local price = math.floor(50 * (2 ^ dist))

    makePart({
        name = "Plot_" .. x .. "_" .. z,
        size = Vector3.new(116, 0.6, 116),
        pos = Vector3.new(cx, 0.3, cz),
        color = BrickColor.new("Dark green"),
        mat = Enum.Material.SmoothPlastic,
        parent = plotFolder,
    })

    -- Corner posts
    for _, c in ipairs({{55, 55}, {-55, 55}, {55, -55}, {-55, -55}}) do
        makePart({name = "PlotPost_" .. x .. "_" .. z, size = Vector3.new(1.2, 5, 1.2), pos = Vector3.new(cx + c[1], 3, cz + c[2]), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.SmoothPlastic, parent = plotFolder})
    end

    -- Fences
    local edge = 60
    if math.abs(x) >= 3 then
        makePart({name = "PlotFenceX_" .. x .. "_" .. z, size = Vector3.new(0.5, 3, 114), pos = Vector3.new(cx + (x > 0 and edge or -edge), 2, cz), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Wood, parent = plotFolder})
    end
    if math.abs(z) >= 3 then
        makePart({name = "PlotFenceZ_" .. x .. "_" .. z, size = Vector3.new(114, 3, 0.5), pos = Vector3.new(cx, 2, cz + (z > 0 and edge or -edge)), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Wood, parent = plotFolder})
    end

    -- Sign
    makePart({name = "SignPost_" .. x .. "_" .. z, size = Vector3.new(0.6, 6, 0.6), pos = Vector3.new(cx, 3.5, cz), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.SmoothPlastic, parent = plotFolder})
    makePart({name = "SignBoard_" .. x .. "_" .. z, size = Vector3.new(8, 4, 0.3), pos = Vector3.new(cx, 7.5, cz), color = BrickColor.new("Medium stone grey"), mat = Enum.Material.SmoothPlastic, parent = plotFolder})

    -- Sign billboard
    local signAnchor = makePart({name = "SignData_" .. x .. "_" .. z, size = Vector3.new(0.1, 0.1, 0.1), pos = Vector3.new(cx, 9.5, cz), alpha = 1, collide = false, parent = plotFolder})
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 150, 0, 80)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = false
    bb.Parent = signAnchor
    local t1 = Instance.new("TextLabel")
    t1.Size = UDim2.new(1, 0, 0.22, 0)
    t1.BackgroundTransparency = 1
    t1.Text = "(" .. x .. ", " .. z .. ")"
    t1.TextColor3 = Color3.fromRGB(200, 200, 200)
    t1.TextSize = 12
    t1.Font = Enum.Font.GothamBold
    t1.TextStrokeTransparency = 0.5
    t1.Parent = bb
    local t2 = Instance.new("TextLabel")
    t2.Size = UDim2.new(1, 0, 0.35, 0)
    t2.Position = UDim2.new(0, 0, 0.22, 0)
    t2.BackgroundTransparency = 1
    t2.Text = "💰 " .. price
    t2.TextColor3 = Color3.fromRGB(255, 220, 100)
    t2.TextSize = 15
    t2.Font = Enum.Font.GothamBold
    t2.TextStrokeTransparency = 0.4
    t2.Parent = bb
    local t3 = Instance.new("TextLabel")
    t3.Size = UDim2.new(1, 0, 0.23, 0)
    t3.Position = UDim2.new(0, 0, 0.57, 0)
    t3.BackgroundTransparency = 1
    t3.Text = "🌿 PRIVATE"
    t3.TextColor3 = Color3.fromRGB(100, 255, 150)
    t3.TextSize = 11
    t3.Font = Enum.Font.GothamBold
    t3.TextStrokeTransparency = 0.5
    t3.Parent = bb

    plotCount = plotCount + 1
end

print("[OK] " .. plotCount .. " plots done")
task.wait()

-- === DATA ORBS (48 total, 4 rings) ===
local orbFolder = Instance.new("Folder")
orbFolder.Name = "DataOrbs"
orbFolder.Parent = workspace

local PI = math.pi

local function createOrb(cx, cy, cz, col)
    -- Ground ring (collidable, opaque, neon) — thick for visibility
    local ring = makePart({
        name = "OrbRing",
        size = Vector3.new(10, 4, 10),
        pos = Vector3.new(cx, 2, cz),
        color = col,
        mat = Enum.Material.Neon,
        alpha = 0,
        shape = Enum.PartType.Cylinder,
        collide = true,
        parent = orbFolder,
    })
    ring.CFrame = CFrame.new(cx, 1, cz) * CFrame.Angles(0, 0, math.rad(90))

    -- Main orb (opaque neon sphere)
    makePart({
        name = "OrbSphere",
        size = Vector3.new(4, 4, 4),
        pos = Vector3.new(cx, cy, cz),
        color = col,
        mat = Enum.Material.Neon,
        alpha = 0,
        shape = Enum.PartType.Ball,
        collide = false,
        parent = orbFolder,
    })

    -- Core (white, opaque)
    makePart({
        name = "OrbCore",
        size = Vector3.new(2, 2, 2),
        pos = Vector3.new(cx, cy, cz),
        color = BrickColor.new("Institutional white"),
        mat = Enum.Material.Neon,
        alpha = 0,
        shape = Enum.PartType.Ball,
        collide = false,
        parent = orbFolder,
    })

    -- Light (brighter)
    makeLight(Vector3.new(cx, cy + 2, cz), col, 6, 35)

    -- Star spikes
    for i = 1, 4 do
        local a = (i / 4) * PI * 2
        makePart({
            name = "OrbSpikes" .. i,
            size = Vector3.new(0.5, 5, 0.5),
            pos = Vector3.new(cx + math.cos(a) * 3.5, cy, cz + math.sin(a) * 3.5),
            color = col,
            mat = Enum.Material.Neon,
            alpha = 0,
            rotation = math.deg(-a),
            collide = false,
            parent = orbFolder,
        })
    end

    -- Billboard (size must be >=1 for BillboardGui to render reliably)
    local bbp = makePart({
        name = "OrbBillboard",
        size = Vector3.new(1, 1, 1),
        pos = Vector3.new(cx, cy, cz),
        alpha = 1,
        collide = false,
        parent = orbFolder,
    })
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 40)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = bbp
    local lbl1 = Instance.new("TextLabel")
    lbl1.Size = UDim2.new(1, 0, 0.6, 0)
    lbl1.BackgroundTransparency = 1
    lbl1.Text = "✦ +5 Data"
    lbl1.TextColor3 = col.Color
    lbl1.TextSize = 16
    lbl1.Font = Enum.Font.GothamBold
    lbl1.TextStrokeTransparency = 0.1
    lbl1.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl1.Parent = bb
    local lbl2 = Instance.new("TextLabel")
    lbl2.Size = UDim2.new(1, 0, 0.4, 0)
    lbl2.Position = UDim2.new(0, 0, 0.6, 0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text = "Walk to collect"
    lbl2.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl2.TextSize = 11
    lbl2.Font = Enum.Font.GothamBold
    lbl2.TextStrokeTransparency = 0.3
    lbl2.Parent = bb
end

-- Ring 1: Cyan (10 orbs, radius 55)
for i = 1, 10 do
    local a = (i / 10) * PI * 2
    createOrb(math.cos(a) * 55, 6, math.sin(a) * 55, BrickColor.new("Cyan"))
end
-- Ring 2: Blue (12 orbs, radius 90)
for i = 1, 12 do
    local a = (i / 12) * PI * 2 + 0.3
    createOrb(math.cos(a) * 90, 8, math.sin(a) * 90, BrickColor.new("Bright blue"))
end
-- Ring 3: Purple (14 orbs, radius 130)
for i = 1, 14 do
    local a = (i / 14) * PI * 2 + 0.15
    createOrb(math.cos(a) * 130, 10, math.sin(a) * 130, BrickColor.new("Bright violet"))
end
-- Ring 4: Gold (12 orbs, radius 175)
for i = 1, 12 do
    local a = (i / 12) * PI * 2
    createOrb(math.cos(a) * 175, 12, math.sin(a) * 175, BrickColor.new("Bright yellow"))
end

print("[OK] 48 data orbs done")
task.wait()

-- === NATURE (trees, bushes, flowers, butterflies) ===
local natureFolder = Instance.new("Folder")
natureFolder.Name = "Nature"
natureFolder.Parent = workspace

local R = math.random

-- Tree function
local function plantTree(x, z, s)
    s = s or 1
    makePart({name = "TreeTrunk", size = Vector3.new(2.5*s, 10*s, 2.5*s), pos = Vector3.new(x, 5*s, z), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = natureFolder})
    makePart({name = "TreeCanopy1", size = Vector3.new(14*s, 10*s, 14*s), pos = Vector3.new(x, 13*s, z), color = BrickColor.new("Dark green"), mat = Enum.Material.Grass, shape = Enum.PartType.Ball, parent = natureFolder})
    makePart({name = "TreeCanopy2", size = Vector3.new(10*s, 7*s, 10*s), pos = Vector3.new(x + 2*s, 17*s, z + 1*s), color = BrickColor.new("Earth green"), mat = Enum.Material.Grass, shape = Enum.PartType.Ball, parent = natureFolder})
    makePart({name = "TreeCanopy3", size = Vector3.new(7*s, 5*s, 7*s), pos = Vector3.new(x - 1*s, 20*s, z - 2*s), color = BrickColor.new("Forest green"), mat = Enum.Material.Grass, shape = Enum.PartType.Ball, parent = natureFolder})
end

-- Bush function
local function plantBush(x, z, s)
    s = s or 1
    for i = 1, 4 do
        makePart({name = "Bush", size = Vector3.new(3*s, 2.5*s, 3*s), pos = Vector3.new(x + R(-2, 2), 1.25*s, z + R(-2, 2)), color = BrickColor.new("Dark green"), mat = Enum.Material.Grass, shape = Enum.PartType.Ball, parent = natureFolder})
    end
end

-- Flower function (multi-petal, colorful)
local function plantFlower(x, z)
    local colors = {
        BrickColor.new("Bright red"), BrickColor.new("Bright yellow"),
        BrickColor.new("Bright violet"), BrickColor.new("Bright orange"),
        BrickColor.new("Pink"), BrickColor.new("Cyan"),
        BrickColor.new("Bright blue"), BrickColor.new("Hot pink"),
    }
    local col = colors[R(#colors)]
    -- Stem
    makePart({name = "FlowerStem", size = Vector3.new(0.3, 1.2, 0.3), pos = Vector3.new(x, 0.6, z), color = BrickColor.new("Dark green"), mat = Enum.Material.Grass, parent = natureFolder})
    -- Center
    makePart({name = "FlowerCenter", size = Vector3.new(0.7, 0.7, 0.7), pos = Vector3.new(x, 1.5, z), color = col, mat = Enum.Material.SmoothPlastic, shape = Enum.PartType.Ball, parent = natureFolder})
    -- Petals
    for i = 1, 6 do
        local a = (i / 6) * PI * 2
        makePart({name = "FlowerPetal", size = Vector3.new(0.5, 0.35, 0.5), pos = Vector3.new(x + math.cos(a) * 0.5, 1.4, z + math.sin(a) * 0.5), color = col, mat = Enum.Material.SmoothPlastic, shape = Enum.PartType.Ball, parent = natureFolder})
    end
end

-- Rock function
local function plantRock(x, z, s)
    s = s or 1
    makePart({name = "Rock", size = Vector3.new(3*s, 2*s, 3*s), pos = Vector3.new(x, 1*s, z), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Slate, shape = Enum.PartType.Ball, parent = natureFolder})
end

-- Butterfly function
local function plantButterfly(x, z, col)
    local h = 4 + R() * 3
    makePart({name = "Butterfly", size = Vector3.new(1.5, 0.5, 2), pos = Vector3.new(x, h, z), color = col, mat = Enum.Material.SmoothPlastic, shape = Enum.PartType.Ball, alpha = 0, collide = false, parent = natureFolder})
    makeLight(Vector3.new(x, h, z), col.Color, 1, 8)
end

-- Forest clusters at corners
for _, fc in ipairs({{-220, -220}, {220, -220}, {-220, 220}, {220, 220}}) do
    for i = 1, 10 do plantTree(fc[1] + R(-30, 30), fc[2] + R(-30, 30), 0.6 + R() * 0.5) end
    for i = 1, 5 do plantBush(fc[1] + R(-35, 35), fc[2] + R(-35, 35), 0.7 + R() * 0.5) end
    for i = 1, 4 do plantRock(fc[1] + R(-25, 25), fc[2] + R(-25, 25), 0.5 + R() * 0.8) end
    for i = 1, 8 do plantFlower(fc[1] + R(-35, 35), fc[2] + R(-35, 35)) end
end

-- Scattered trees
for i = 1, 50 do
    local tx, tz = R(-250, 250), R(-250, 250)
    if math.abs(tx) > 40 or math.abs(tz) > 40 then plantTree(tx, tz, 0.5 + R() * 0.6) end
end

-- Bushes everywhere
for i = 1, 80 do plantBush(R(-250, 250), R(-250, 250), 0.4 + R() * 0.6) end

-- Flowers everywhere
for i = 1, 200 do plantFlower(R(-250, 250), R(-250, 250)) end

-- Rocks
for i = 1, 35 do plantRock(R(-240, 240), R(-240, 240), 0.4 + R() * 1.0) end

-- Butterflies
local bflyCols = {
    BrickColor.new("Bright yellow"), BrickColor.new("Bright blue"),
    BrickColor.new("Bright violet"), BrickColor.new("Bright orange"),
    BrickColor.new("Pink"), BrickColor.new("Cyan"),
}
for i = 1, 30 do
    plantButterfly(R(-230, 230), R(-230, 230), bflyCols[R(#bflyCols)])
end

-- Trees along walkways
for dirIdx, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    local dx, dz = d[1], d[2]
    for dist = 50, 260, 15 do
        local tx, tz = dx * dist, dz * dist
        if dx == 0 then
            plantTree(tx + 10, tz, 0.5 + R() * 0.3)
            plantTree(tx - 10, tz, 0.5 + R() * 0.3)
        else
            plantTree(tx, tz + 10, 0.5 + R() * 0.3)
            plantTree(tx, tz - 10, 0.5 + R() * 0.3)
        end
    end
end

-- Flowers along walkways
for _, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    local dx, dz = d[1], d[2]
    for dist = 45, 260, 45 do
        local tx, tz = dx * dist, dz * dist
        if dx == 0 then
            plantFlower(tx + 12, tz)
            plantFlower(tx - 12, tz)
        else
            plantFlower(tx, tz + 12)
            plantFlower(tx, tz - 12)
        end
    end
end

-- Lamps along walkways (FIXED: unique names per direction)
for dirIdx, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    local dx, dz = d[1], d[2]
    for dist = 60, 260, 25 do
        local lx, lz = dx * dist, dz * dist
        if dx == 0 then
            makePart({name = "WalkLampPole_L" .. dirIdx .. "_" .. dist, size = Vector3.new(0.5, 8, 0.5), pos = Vector3.new(lx + 9, 4, lz), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Metal, parent = walkFolder})
            makePart({name = "WalkLampHead_L" .. dirIdx .. "_" .. dist, size = Vector3.new(1.5, 0.5, 1.5), pos = Vector3.new(lx + 9, 8.2, lz), color = BrickColor.new("Institutional white"), mat = Enum.Material.SmoothPlastic, parent = walkFolder})
            makeLight(Vector3.new(lx + 9, 8.2, lz), Color3.fromRGB(255, 240, 200), 1.5, 20)
            makePart({name = "WalkLampPole_R" .. dirIdx .. "_" .. dist, size = Vector3.new(0.5, 8, 0.5), pos = Vector3.new(lx - 9, 4, lz), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Metal, parent = walkFolder})
            makePart({name = "WalkLampHead_R" .. dirIdx .. "_" .. dist, size = Vector3.new(1.5, 0.5, 1.5), pos = Vector3.new(lx - 9, 8.2, lz), color = BrickColor.new("Institutional white"), mat = Enum.Material.SmoothPlastic, parent = walkFolder})
            makeLight(Vector3.new(lx - 9, 8.2, lz), Color3.fromRGB(255, 240, 200), 1.5, 20)
        else
            makePart({name = "WalkLampPole_L" .. dirIdx .. "_" .. dist, size = Vector3.new(0.5, 8, 0.5), pos = Vector3.new(lx, 4, lz + 9), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Metal, parent = walkFolder})
            makePart({name = "WalkLampHead_L" .. dirIdx .. "_" .. dist, size = Vector3.new(1.5, 0.5, 1.5), pos = Vector3.new(lx, 8.2, lz + 9), color = BrickColor.new("Institutional white"), mat = Enum.Material.SmoothPlastic, parent = walkFolder})
            makeLight(Vector3.new(lx, 8.2, lz + 9), Color3.fromRGB(255, 240, 200), 1.5, 20)
            makePart({name = "WalkLampPole_R" .. dirIdx .. "_" .. dist, size = Vector3.new(0.5, 8, 0.5), pos = Vector3.new(lx, 4, lz - 9), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.Metal, parent = walkFolder})
            makePart({name = "WalkLampHead_R" .. dirIdx .. "_" .. dist, size = Vector3.new(1.5, 0.5, 1.5), pos = Vector3.new(lx, 8.2, lz - 9), color = BrickColor.new("Institutional white"), mat = Enum.Material.SmoothPlastic, parent = walkFolder})
            makeLight(Vector3.new(lx, 8.2, lz - 9), Color3.fromRGB(255, 240, 200), 1.5, 20)
        end
    end
end

-- Benches along walkways (FIXED: unique names per direction)
for dirIdx, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    local dx, dz = d[1], d[2]
    for dist = 90, 220, 50 do
        local bx, bz = dx * dist, dz * dist
        if dx == 0 then
            makePart({name = "BenchSeat_L" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 0.5, 2), pos = Vector3.new(bx + 12, 2.5, bz), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchBack_L" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 3, 0.5), pos = Vector3.new(bx + 12, 4.5, bz + 0.75), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchSeat_R" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 0.5, 2), pos = Vector3.new(bx - 12, 2.5, bz), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchBack_R" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 3, 0.5), pos = Vector3.new(bx - 12, 4.5, bz + 0.75), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
        else
            makePart({name = "BenchSeat_L" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 0.5, 2), pos = Vector3.new(bx, 2.5, bz + 12), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchBack_L" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 3, 0.5), pos = Vector3.new(bx, 4.5, bz + 12.75), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchSeat_R" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 0.5, 2), pos = Vector3.new(bx, 2.5, bz - 12), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
            makePart({name = "BenchBack_R" .. dirIdx .. "_" .. dist, size = Vector3.new(6, 3, 0.5), pos = Vector3.new(bx, 4.5, bz - 12.75), color = BrickColor.new("Brown"), mat = Enum.Material.Wood, parent = walkFolder})
        end
    end
end

print("[OK] Nature + fauna done")
task.wait()

-- === WATER ===
local waterFolder = Instance.new("Folder")
waterFolder.Name = "Water"
waterFolder.Parent = workspace

local pond1 = makePart({name = "Pond1", size = Vector3.new(28, 0.5, 18), pos = Vector3.new(58, 0.2, 58), color = BrickColor.new("Bright blue"), mat = Enum.Material.Glass, shape = Enum.PartType.Cylinder, parent = waterFolder})
pond1.CFrame = CFrame.new(58, 0.2, 58) * CFrame.Angles(0, 0, math.rad(90))
for i = 1, 10 do local a = (i / 10) * PI * 2 plantRock(58 + math.cos(a) * 15, 58 + math.sin(a) * 10, 0.3 + R() * 0.3) end
for i = 1, 6 do makePart({name = "Stream", size = Vector3.new(4, 0.3, 4), pos = Vector3.new(58 + i * 7, 0.15, 58 + i * 5), color = BrickColor.new("Bright blue"), mat = Enum.Material.Glass, parent = waterFolder}) end

local pond2 = makePart({name = "Pond2", size = Vector3.new(16, 0.5, 12), pos = Vector3.new(-55, 0.2, -55), color = BrickColor.new("Bright blue"), mat = Enum.Material.Glass, shape = Enum.PartType.Cylinder, parent = waterFolder})
pond2.CFrame = CFrame.new(-55, 0.2, -55) * CFrame.Angles(0, 0, math.rad(90))
for i = 1, 6 do plantRock(-55 + math.cos((i / 6) * PI * 2) * 9, -55 + math.sin((i / 6) * PI * 2) * 7, 0.3) end

print("[OK] Water done")
task.wait()

-- === DECORATIVE BUILDINGS ===
local buildFolder = Instance.new("Folder")
buildFolder.Name = "Buildings"
buildFolder.Parent = workspace
for _, bp in ipairs({{62, -62, "Data Store"}, {-62, 62, "Tech Shop"}, {-62, -62, "Server Farm"}, {62, 62, "Mining Co"}}) do
    makePart({name = "Building", size = Vector3.new(14, 11, 14), pos = Vector3.new(bp[1], 6, bp[2]), color = BrickColor.new("Medium stone grey"), mat = Enum.Material.SmoothPlastic, parent = buildFolder})
    makePart({name = "Roof", size = Vector3.new(16, 1, 16), pos = Vector3.new(bp[1], 12, bp[2]), color = BrickColor.new("Dark stone grey"), mat = Enum.Material.SmoothPlastic, parent = buildFolder})
    local sign = makePart({name = "BldgSign", size = Vector3.new(10, 2, 0.3), pos = Vector3.new(bp[1], 10, bp[2] + 7.2), color = BrickColor.new("Bright blue"), mat = Enum.Material.SmoothPlastic, parent = buildFolder})
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 100, 0, 25)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = sign
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🏪 " .. bp[3]
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
end

print("[OK] Buildings done")

-- === LIGHTING ===
local lt = game:GetService("Lighting")
lt.Ambient = Color3.fromRGB(90, 90, 110)
lt.OutdoorAmbient = Color3.fromRGB(110, 110, 130)
lt.Brightness = 2.5
lt.ClockTime = 14
lt.FogEnd = 1000
lt.FogColor = Color3.fromRGB(170, 190, 220)
lt.GlobalShadows = true
lt.ShadowSoftness = 0.3

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 35
bloom.Threshold = 0.7
bloom.Parent = lt

local cc = Instance.new("ColorCorrectionEffect")
cc.Brightness = 0.03
cc.Contrast = 0.08
cc.Saturation = 0.2
cc.TintColor = Color3.fromRGB(210, 225, 255)
cc.Parent = lt

local sunrays = Instance.new("SunRaysEffect")
sunrays.Intensity = 0.2
sunrays.Spread = 0.9
sunrays.Parent = lt

local atmos = Instance.new("Atmosphere")
atmos.Density = 0.25
atmos.Offset = 0.1
atmos.Color = Color3.fromRGB(180, 200, 230)
atmos.Decay = 0.95
atmos.Glare = 0.3
atmos.Haze = 1.5
atmos.Parent = lt

local sky = Instance.new("Sky")
sky.SkyboxBk = "rbxassetid://1007059817"
sky.SkyboxDn = "rbxassetid://1007060023"
sky.SkyboxFt = "rbxassetid://1007059817"
sky.SkyboxLf = "rbxassetid://1007059817"
sky.SkyboxRt = "rbxassetid://1007059817"
sky.SkyboxUp = "rbxassetid://1007060023"
sky.Parent = lt

workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("[OK] Lighting done")
print("=":rep(40))
print("DataTycoon v0.19 — SERVER READY!")
print("=":rep(40))

end) -- end task.spawn world build

-- === INIT ===
InitPlots()
