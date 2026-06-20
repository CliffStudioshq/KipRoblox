--[[
    Main.server.lua — DataTycoon v0.23
    Key changes from v0.21:
      - Early static baseplate Part (safety net before terrain loads)
      - OrbCollected RemoteEvent so client can animate orb disappear/respawn
      - All previous fixes retained
]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

-- Bridge builder lives in WorldBuilder.server.lua (global functions)

local DATASTORE_VERSION = 6

print(("="):rep(50))
print("DataTycoon v0.23 — Server starting...")
print(("="):rep(50))

-- ============================================================
-- EARLY BASEPLATE — exists before any yields so players never fall
-- ============================================================
do
    local base = Instance.new("Part")
    base.Name        = "EarlyBase"
    base.Size        = Vector3.new(600, 4, 600)
    base.Position    = Vector3.new(0, -2, 0)
    base.Anchored    = true
    base.CanCollide  = true
    base.Transparency = 1   -- invisible; terrain paints over it visually
    base.Parent      = workspace

    local sp = Instance.new("SpawnLocation")
    sp.Size        = Vector3.new(10, 1, 10)
    sp.Position    = Vector3.new(0, 3, 0)
    sp.Anchored    = true
    sp.CanCollide  = false
    sp.Transparency = 1
    sp.Neutral     = true
    sp.Parent      = workspace
end

-- ============================================================
-- DATASTORE — pcall so failure never kills Events creation
-- ============================================================
local DataStore = nil
local dsOk, dsErr = pcall(function()
    DataStore = DataStoreService:GetDataStore("DataTycoon_v" .. DATASTORE_VERSION)
end)
if not dsOk then
    warn("[DATA] DataStore unavailable: " .. tostring(dsErr))
    warn("[DATA] Enable API Services in Game Settings > Security")
end

-- ============================================================
-- REMOTE EVENTS
-- Build ALL children before parenting to ReplicatedStorage
-- so the entire folder replicates atomically (no partial state)
-- ============================================================
local Events = Instance.new("Folder")
Events.Name = "Events"   -- parent set LAST, below

local function MakeEvent(name, cls)
    local e = Instance.new(cls or "RemoteEvent")
    e.Name   = name
    e.Parent = Events
    return e
end

local ClaimDailyReward  = MakeEvent("ClaimDailyReward")
local CollectOrb        = MakeEvent("CollectOrb")
local PurchasePlotBuilding   = MakeEvent("PurchasePlotBuilding")
local PurchaseDecoration     = MakeEvent("PurchaseDecoration")
local PurchasePlayerUpgrade  = MakeEvent("PurchasePlayerUpgrade")
local PurchaseFunUpgrade     = MakeEvent("PurchaseFunUpgrade")
local DailyRewardClaimed = MakeEvent("DailyRewardClaimed")
local Notification      = MakeEvent("Notification")
local DataUpdated       = MakeEvent("DataUpdated")
local PlotUpgraded      = MakeEvent("PlotUpgraded")
local DecorationChanged = MakeEvent("DecorationChanged")
local PlayerUpgraded    = MakeEvent("PlayerUpgraded")
local BridgeBuilt       = MakeEvent("BridgeBuilt")
local BridgeRemoved     = MakeEvent("BridgeRemoved")
local OrbCollected      = MakeEvent("OrbCollected")   -- fires orb position back so client can animate
local OrbStateChanged   = MakeEvent("OrbStateChanged") -- server authoritative orb availability
local GetPlayerData     = MakeEvent("GetPlayerData", "RemoteFunction")
local PlayerDataReady   = MakeEvent("PlayerDataReady")

-- NOW parent — entire subtree replicates as one atomic snapshot
Events.Parent = ReplicatedStorage
print("[OK] RemoteEvents replicated")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    STARTING_DATA  = 10,
    ORB_REWARD     = 2,
    PASSIVE_INCOME = 0.5,

    DAILY_REWARDS  = {50, 75, 100, 150, 200, 300, 500},
    ORB_RESPAWN    = 30,  -- seconds before orb visually respawns on client
}

-- ============================================================
-- TELEMETRY (lightweight)
-- ============================================================
local Telemetry = {
    invalidCalls = {},  -- [userId] = count
    lastWarned = {},    -- [userId] = timestamp
}

local function LogInvalidCall(player, action)
    local uid = player.UserId
    Telemetry.invalidCalls[uid] = (Telemetry.invalidCalls[uid] or 0) + 1
    local now = tick()
    if (not Telemetry.lastWarned[uid]) or (now - Telemetry.lastWarned[uid]) > 30 then
        warn(string.format("[TELEMETRY] %s: invalid %s (%d total)", player.Name, action, Telemetry.invalidCalls[uid]))
        Telemetry.lastWarned[uid] = now
    end
end

-- ============================================================
-- ORB REGISTRY / STATE (server authoritative)
-- ============================================================
local OrbRegistry = {}  -- orbId -> BasePart (OrbRing)
local OrbState = {}     -- orbId -> {available = bool, cooldownUntil = timestamp}

local function RegisterOrbs()
    local dataOrbsFolder = workspace:FindFirstChild("DataOrbs")
    if not dataOrbsFolder then
        warn("[ORB] workspace.DataOrbs missing; orb registry not initialized")
        return
    end

    local n = 0
    for _, inst in ipairs(dataOrbsFolder:GetChildren()) do
        if inst:IsA("BasePart") and inst.Name:match("^OrbRing_") then
            local orbId = inst.Name
            OrbRegistry[orbId] = inst
            OrbState[orbId] = {available = true, cooldownUntil = 0}
            n = n + 1
        end
    end
    print("[ORB] Registered " .. n .. " orbs")
end

task.spawn(function()
    -- allow WorldBuilder to create DataOrbs
    task.wait(1)
    RegisterOrbs()
end)

-- ============================================================
-- PLAYER DATA
-- ============================================================
local PlayerData = {}

-- Offline income cooldowns: UserId -> last award timestamp
local OfflineIncomeCooldowns = {}
local OFFLINE_INCOME_MIN_TIME = 60      -- minimum seconds offline to qualify
local OFFLINE_INCOME_COOLDOWN  = 300     -- 5 minutes between awards

local DEFAULT_DATA = {
    Data = 10,
    TotalEarned = 10,
    TotalSpent = 0,

    -- Plot (single)
    Plot = {
        tier = 1,
        decorations = {},
        gridX = 0,
        gridZ = 0,
    },

    -- Player upgrades (levels)
    Upgrades = {
        dataMiningSpeed = 0,
        orbMagnetism = 0,
        orbValue = 0,
        idleMining = 0,
        walkSpeed = 0,
        sprintPower = 0,
        jumpBoost = 0,
    },

    -- Fun upgrades
    FunUpgrades = {},
    Title = "",
    Pet = "",

    DailyStreak = 0,
    LastDailyReward = 0,
    BlocksCollected = 0,
    LastSeen = 0,
}

local function defaultData()
    local d = {}
    for k, v in pairs(DEFAULT_DATA) do
        d[k] = type(v) == "table" and {} or v
    end
    return d
end

-- ============================================================
-- v0.30 — Single plot + upgrades
-- ============================================================
local PLOT_GRID_SPACING = 170

local PLOT_BUILDINGS = {
    {tier = 1, name = "Empty Plot",       cost = 0,      dpsBonus = 0},
    {tier = 2, name = "Data Outpost",     cost = 500,    dpsBonus = 5},
    {tier = 3, name = "Server Room",      cost = 2000,   dpsBonus = 15},
    {tier = 4, name = "Data Center",      cost = 8000,   dpsBonus = 50},
    {tier = 5, name = "Tech Campus",      cost = 25000,  dpsBonus = 150},
    {tier = 6, name = "Quantum Labs",     cost = 75000,  dpsBonus = 400},
    {tier = 7, name = "Neural Nexus",     cost = 200000, dpsBonus = 1000},
    {tier = 8, name = "Singularity Core", cost = 500000, dpsBonus = 3000},
}

local PLOT_DECORATIONS = {
    {name = "Flower Garden",      cost = 200,    dpsBonus = 1},
    {name = "Fountain",           cost = 800,    dpsBonus = 3},
    {name = "Neon Sign",          cost = 1500,   dpsBonus = 5},
    {name = "Hologram Tree",      cost = 3000,   dpsBonus = 10},
    {name = "Dragon Statue",      cost = 8000,   dpsBonus = 25},
    {name = "Particle Fountain",  cost = 15000,  dpsBonus = 50},
    {name = "Mining Drones",      cost = 30000,  dpsBonus = 100},
    {name = "Satellite Dish",     cost = 50000,  dpsBonus = 200},
}

local PLAYER_UPGRADES = {
    dataMiningSpeed = {baseCost = 500,  maxLevel = 20, scaling = 1.5, baseEffect = 2},
    orbMagnetism    = {baseCost = 1000, maxLevel = 10, scaling = 1.8, baseEffect = 3},
    orbValue        = {baseCost = 2000, maxLevel = 10, scaling = 2.0, baseEffect = 1},
    idleMining      = {baseCost = 5000, maxLevel = 5,  scaling = 2.5, baseEffect = 0.5},
    walkSpeed       = {baseCost = 300,  maxLevel = 10, scaling = 1.6, baseEffect = 2},
    sprintPower     = {baseCost = 2000, maxLevel = 5,  scaling = 2.0, baseEffect = 10},
    jumpBoost       = {baseCost = 1500, maxLevel = 5,  scaling = 2.0, baseEffect = 5},
}

local FUN_UPGRADES = {
    particleTrail = {cost = 5000,   name = "Particle Trail"},
    musicPack     = {cost = 3000,   name = "Music Pack"},
    titleMiner    = {cost = 10000,  name = "Title: Data Miner"},
    titleBaron    = {cost = 50000,  name = "Title: Data Baron"},
    titleTycoon   = {cost = 200000, name = "Title: Data Tycoon"},
    auraEffect    = {cost = 25000,  name = "Aura Effect"},
    fireTrail     = {cost = 100000, name = "Fire Trail"},
    rainbowMode   = {cost = 500000, name = "Rainbow Mode"},
    petOrb        = {cost = 75000,  name = "Pet: Data Orb"},
    petRobot      = {cost = 150000, name = "Pet: Robot Dog"},
}

local function GetUpgradeCost(upgradeKey, currentLevel)
    local upg = PLAYER_UPGRADES[upgradeKey]
    if not upg then return math.huge end
    return math.floor(upg.baseCost * (upg.scaling ^ currentLevel))
end

local PlayerPlot = {}      -- [userId] = Plot table
local PlayerUpgrades = {}  -- [userId] = Upgrades table

local function GetDecorationByName(name)
    for _, dec in ipairs(PLOT_DECORATIONS) do
        if dec.name == name then return dec end
    end
    return nil
end

local function ApplyPlayerStats(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local upgrades = data.Upgrades or {}
    local baseSpeed = 16
    humanoid.WalkSpeed = baseSpeed + (upgrades.walkSpeed or 0) * (PLAYER_UPGRADES.walkSpeed.baseEffect)

    local baseJump = 50
    humanoid.JumpPower = baseJump + (upgrades.jumpBoost or 0) * (PLAYER_UPGRADES.jumpBoost.baseEffect)
end

local function SpiralCoord(n)
    if n == 0 then return 0, 0 end
    local ring = math.ceil((math.sqrt(n + 1) - 1) / 2)
    local sideLen = ring * 2
    local maxVal = (2 * ring + 1) ^ 2 - 1
    local d = maxVal - n
    local side = math.floor(d / sideLen)
    local pos = d % sideLen

    if side == 0 then
        return ring - pos, -ring
    elseif side == 1 then
        return -ring, -ring + pos
    elseif side == 2 then
        return -ring + pos, ring
    else
        return ring, ring - pos
    end
end

local function AssignPlot(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    data.Plot = data.Plot or {tier = 1, decorations = {}, gridX = 0, gridZ = 0}

    if data._plotAssigned == true then
        data.Plot.plotCenter = Vector3.new((data.Plot.gridX or 0) * PLOT_GRID_SPACING, 0.5, (data.Plot.gridZ or 0) * PLOT_GRID_SPACING)
        PlayerPlot[player.UserId] = data.Plot
        return
    end

    local used = {}
    for _, pd in pairs(PlayerData) do
        if pd and pd._plotAssigned == true and pd.Plot then
            used[tostring(pd.Plot.gridX) .. "," .. tostring(pd.Plot.gridZ)] = true
        end
    end

    local idx = 0
    while true do
        local gx, gz = SpiralCoord(idx)
        local key = tostring(gx) .. "," .. tostring(gz)
        if not used[key] then
            data.Plot.gridX = gx
            data.Plot.gridZ = gz
            data.Plot.plotCenter = Vector3.new(gx * PLOT_GRID_SPACING, 0.5, gz * PLOT_GRID_SPACING)
            data._plotAssigned = true
            PlayerPlot[player.UserId] = data.Plot
            print(string.format("[PLOT] Assigned %s to grid (%d,%d)", player.Name, gx, gz))
            break
        end
        idx += 1
        if idx > 20000 then
            warn("[PLOT] Failed to assign plot for " .. player.Name)
            break
        end
    end
end

local function dsGet(key)
    if not DataStore then return nil end
    for attempt = 1, 3 do
        local ok, result = pcall(function() return DataStore:GetAsync(key) end)
        if ok then return result end
        warn("[DATA] GetAsync attempt "..attempt.." failed: "..tostring(result))
        task.wait(1.5 ^ attempt)
    end
    return nil
end

local function dsSet(key, value)
    if not DataStore then return false end
    local ok, err = pcall(function()
        DataStore:UpdateAsync(key, function() return value end)
    end)
    if not ok then warn("[DATA] Save failed: "..tostring(err)) end
    return ok
end

-- ============================================================
-- PLOTS
-- ============================================================
-- (v0.30) Plots are per-player and assigned on a grid; no shared plot pool.

-- ============================================================
-- LOAD / SAVE
-- ============================================================
local function LoadPlayerData(player)
    local key   = "Player_"..player.UserId
    local saved = dsGet(key)
    local data

    if saved then
        -- ========================================================
        -- DATA MIGRATIONS
        -- ========================================================
        local oldVersion = saved._dataVersion or saved.DataVersion
        if oldVersion == nil then oldVersion = 1 end

        if oldVersion < DATASTORE_VERSION then
            local v = oldVersion

            -- v1 -> v2: Cash -> Data
            if v < 2 then
                if saved.Cash ~= nil and saved.Data == nil then
                    saved.Data = saved.Cash
                end
                saved.Cash = nil
                v = 2
            end

            -- v2 -> v3: PlotCount -> ensure Plots table exists
            if v < 3 then
                if saved.PlotCount ~= nil then
                    saved.Plots = saved.Plots or {}
                end
                v = 3
            end

            -- v3 -> v4: LastLogin -> LastSeen
            if v < 4 then
                if saved.LastLogin ~= nil and saved.LastSeen == nil then
                    saved.LastSeen = saved.LastLogin
                end
                saved.LastLogin = nil
                v = 4
            end

            -- v4 -> v5: defaults ensured by merge below
            if v < 5 then
                v = 5
            end

            if v < 6 then
                -- Migrate from old plot system to new
                saved.Plot = saved.Plot or {tier = 1, decorations = {}, gridX = 0, gridZ = 0}
                saved.Upgrades = saved.Upgrades or {dataMiningSpeed=0, orbMagnetism=0, orbValue=0, idleMining=0, walkSpeed=0, sprintPower=0, jumpBoost=0}
                saved.FunUpgrades = saved.FunUpgrades or {}
                saved.Title = saved.Title or ""
                saved.Pet = saved.Pet or ""
                -- Remove old fields
                saved.Plots = nil
                saved.Computers = nil
                saved.HouseTier = nil
                v = 6
            end

            saved._dataVersion = DATASTORE_VERSION
            print("[DATA] Migrated "..player.Name.." from v"..tostring(oldVersion).." to v"..tostring(DATASTORE_VERSION))
        end

        -- Ensure any new default fields exist (deep for tables)
        for k, v in pairs(DEFAULT_DATA) do
            if saved[k] == nil then
                saved[k] = type(v)=="table" and {} or v
            elseif type(v) == "table" and type(saved[k]) == "table" then
                for kk, vv in pairs(v) do
                    if saved[k][kk] == nil then
                        saved[k][kk] = type(vv) == "table" and {} or vv
                    end
                end
            end
        end
        data = saved
        print("[DATA] Loaded "..player.Name.." Data="..data.Data)
    else
        data = defaultData()
        print("[DATA] New player: "..player.Name)
    end

    -- Offline income (capped at 2 hours)
    local now = os.time()
    if data.LastSeen and data.LastSeen > 0 then
        local elapsed = math.min(now - data.LastSeen, 7200)

        if elapsed < OFFLINE_INCOME_MIN_TIME then
            print(string.format("[DATA] Offline bonus skipped for %s: only %ds offline (<%ds)", player.Name, elapsed, OFFLINE_INCOME_MIN_TIME))
        else
            local lastAward = OfflineIncomeCooldowns[player.UserId]
            if lastAward and (now - lastAward) < OFFLINE_INCOME_COOLDOWN then
                print(string.format("[DATA] Offline bonus skipped for %s: cooldown %ds remaining", player.Name, OFFLINE_INCOME_COOLDOWN - (now - lastAward)))
            else
                local offDPS = CONFIG.PASSIVE_INCOME

                -- Plot building DPS
                local plot = data.Plot
                if plot then
                    local building = PLOT_BUILDINGS[plot.tier or 1]
                    if building then offDPS = offDPS + (building.dpsBonus or 0) end

                    -- Decoration DPS
                    for _, decName in ipairs(plot.decorations or {}) do
                        local dec = GetDecorationByName(decName)
                        if dec then offDPS = offDPS + (dec.dpsBonus or 0) end
                    end
                end

                -- Player upgrade DPS
                local upgrades = data.Upgrades
                if upgrades then
                    offDPS = offDPS + (upgrades.dataMiningSpeed or 0) * (PLAYER_UPGRADES.dataMiningSpeed.baseEffect)
                end

                local bonus = math.floor(elapsed * offDPS * 0.5)
                if bonus > 0 then
                    data.Data        = data.Data + bonus
                    data.TotalEarned = data.TotalEarned + bonus
                    OfflineIncomeCooldowns[player.UserId] = now

                    -- Notify after client connects (give it 4s to set up)
                    task.delay(4, function()
                        if player.Parent then
                            Notification:FireClient(player,
                                "Welcome back! +"..bonus.." Data offline 💤", "success")
                        end
                    end)
                    print("[DATA] Offline bonus for "..player.Name..": +"..bonus)
                end
            end
        end
    end
    data.LastSeen = now
    PlayerData[player.UserId] = data

    -- Assign single plot + cache upgrades
    AssignPlot(player)
    PlayerUpgrades[player.UserId] = data.Upgrades

    -- Build leaderstats — ALL children added before parenting (atomic replication)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"

    local dv = Instance.new("IntValue")
    dv.Name = "Data"; dv.Value = data.Data; dv.Parent = ls

    ls.Parent = player   -- atomic: client gets complete folder in one replication
    print("[OK] leaderstats created for "..player.Name)

    -- Signal client that GetPlayerData is now safe to call
    PlayerDataReady:FireClient(player)

    -- Apply movement upgrades
    task.defer(function()
        ApplyPlayerStats(player)
    end)
end

local function SavePlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    data.LastSeen = os.time()
    data._dataVersion = DATASTORE_VERSION
    dsSet("Player_"..player.UserId, data)
end

-- Some saved data fields may be missing or nil; using # on nil will error.
local function safeLen(t)
    return (type(t) == "table") and #t or 0
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

local function Notify(player, msg, t)
    Notification:FireClient(player, msg, t or "info")
end

-- (v0.30) No shared plot pool to search.

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

ClaimDailyReward.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]; if not data then return end
    local now   = os.time()
    local since = math.floor((now - (data.LastDailyReward or 0)) / 86400)
    if since == 0 then
        LogInvalidCall(player, "ClaimDailyReward")
        Notify(player, "Already claimed today!", "error")
        return
    end
    if since > 1 then data.DailyStreak = 1
    else data.DailyStreak = (data.DailyStreak or 0) + 1 end
    local idx    = ((data.DailyStreak-1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[idx]
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notify(player, "Day "..data.DailyStreak..": +"..reward.." Data! 🎉", "success")
end)

local orbCooldowns = {}
CollectOrb.OnServerEvent:Connect(function(player, orbId)
    -- Server-side validation (anti-cheat): ensure orb is real and near the player
    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if type(orbId) ~= "string" then
        LogInvalidCall(player, "CollectOrb")
        return
    end

    -- (1) Verify orb exists in workspace.DataOrbs and is a known OrbRing_* instance
    local dataOrbsFolder = workspace:FindFirstChild("DataOrbs")
    if not dataOrbsFolder then
        warn("[ANTI-CHEAT] DataOrbs folder missing; denying orb collection for " .. player.Name)
        return
    end

    local orbPart = OrbRegistry[orbId]
    if not (orbPart and orbPart.Parent == dataOrbsFolder) then
        -- Attempt lazy re-register (WorldBuilder might have rebuilt)
        RegisterOrbs()
        orbPart = OrbRegistry[orbId]
    end

    if not (orbPart and orbPart.Parent == dataOrbsFolder) then
        LogInvalidCall(player, "CollectOrb")
        warn(string.format("[ANTI-CHEAT] %s attempted orb collection for invalid orbId=%s", player.Name, tostring(orbId)))
        return
    end

    local state = OrbState[orbId]
    if not state then
        state = {available = true, cooldownUntil = 0}
        OrbState[orbId] = state
    end

    local nowT = os.clock()
    if (not state.available) and nowT < (state.cooldownUntil or 0) then
        return
    end

    local orbPos = orbPart.Position
    local distance = (hrp.Position - orbPos).Magnitude
    if distance > 50 then
        warn("[ANTI-CHEAT] " .. player.Name .. " attempted orb collection at distance " .. distance)
        return
    end

    local now = tick()
    if orbCooldowns[player.UserId] and (now - orbCooldowns[player.UserId]) < 0.4 then return end
    orbCooldowns[player.UserId] = now

    -- Mark orb unavailable
    state.available = false
    state.cooldownUntil = nowT + CONFIG.ORB_RESPAWN
    OrbStateChanged:FireAllClients(orbId, false)

    print("[ORB] " .. player.Name .. " collected " .. orbId)

    local data = PlayerData[player.UserId]; if not data then return end
    local upgrades = data.Upgrades or {}
    local orbReward = CONFIG.ORB_REWARD + (upgrades.orbValue or 0) * (PLAYER_UPGRADES.orbValue.baseEffect)
    data.Data = data.Data + orbReward
    data.TotalEarned = data.TotalEarned + orbReward
    data.BlocksCollected = (data.BlocksCollected or 0) + 1
    UpdateData(player)

    -- keep existing client feedback event
    OrbCollected:FireClient(player, orbPos, CONFIG.ORB_RESPAWN)

    task.delay(CONFIG.ORB_RESPAWN, function()
        local st = OrbState[orbId]
        if not st then return end
        st.available = true
        st.cooldownUntil = 0
        OrbStateChanged:FireAllClients(orbId, true)
        print("[ORB] Orb " .. orbId .. " now available")
    end)
end)

PurchasePlotBuilding.OnServerEvent:Connect(function(player, payload)
    local data = PlayerData[player.UserId]; if not data then return end
    local plot = data.Plot; if not plot then return end

    if type(payload) ~= "table" then
        LogInvalidCall(player, "PurchasePlotBuilding")
        return
    end

    local gx = tonumber(payload.plotX)
    local gz = tonumber(payload.plotZ)
    if gx == nil or gz == nil or gx ~= plot.gridX or gz ~= plot.gridZ then
        LogInvalidCall(player, "PurchasePlotBuilding")
        Notify(player, "Invalid plot.", "error")
        return
    end

    local nextTier = (plot.tier or 1) + 1
    if nextTier > #PLOT_BUILDINGS then
        Notify(player, "Already max building tier!", "error")
        return
    end
    local nextBuilding = PLOT_BUILDINGS[nextTier]
    if not nextBuilding then return end
    local cost = nextBuilding.cost or 0
    if data.Data < cost then
        Notify(player, "Need " .. cost .. " Data!", "error")
        return
    end

    data.Data -= cost
    data.TotalSpent = (data.TotalSpent or 0) + cost
    plot.tier = nextTier
    UpdateData(player)

    PlotUpgraded:FireClient(player, {plotX = gx, plotZ = gz, newTier = nextTier, buildingName = nextBuilding.name, dpsBonus = nextBuilding.dpsBonus})
    Notify(player, "Upgraded plot to " .. nextBuilding.name .. "!", "success")
    print(string.format("[PLOT] %s upgraded building to tier %d (%s)", player.Name, nextTier, tostring(nextBuilding.name)))
end)

PurchaseDecoration.OnServerEvent:Connect(function(player, payload)
    local data = PlayerData[player.UserId]; if not data then return end
    local plot = data.Plot; if not plot then return end

    if type(payload) ~= "table" then
        LogInvalidCall(player, "PurchaseDecoration")
        return
    end
    local gx = tonumber(payload.plotX)
    local gz = tonumber(payload.plotZ)
    local slotIndex = tonumber(payload.slotIndex)
    local decorationName = payload.decorationName

    if gx == nil or gz == nil or gx ~= plot.gridX or gz ~= plot.gridZ then
        LogInvalidCall(player, "PurchaseDecoration")
        Notify(player, "Invalid plot.", "error")
        return
    end
    slotIndex = math.clamp(math.floor(slotIndex or 0), 1, 3)
    if type(decorationName) ~= "string" then
        LogInvalidCall(player, "PurchaseDecoration")
        return
    end
    local dec = GetDecorationByName(decorationName)
    if not dec then
        Notify(player, "Decoration not found!", "error")
        return
    end
    local cost = dec.cost or 0
    if data.Data < cost then
        Notify(player, "Need " .. cost .. " Data!", "error")
        return
    end

    plot.decorations = plot.decorations or {}
    plot.decorations[slotIndex] = decorationName
    data.Data -= cost
    data.TotalSpent = (data.TotalSpent or 0) + cost
    UpdateData(player)

    DecorationChanged:FireClient(player, {plotX = gx, plotZ = gz, slot = slotIndex, name = decorationName, dpsBonus = dec.dpsBonus})
    Notify(player, "Placed " .. decorationName .. "!", "success")
    print(string.format("[PLOT] %s changed decoration slot %d -> %s", player.Name, slotIndex, decorationName))
end)

PurchasePlayerUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
    local data = PlayerData[player.UserId]; if not data then return end
    if type(upgradeKey) ~= "string" then
        LogInvalidCall(player, "PurchasePlayerUpgrade")
        return
    end
    local def = PLAYER_UPGRADES[upgradeKey]
    if not def then
        Notify(player, "Upgrade not found!", "error")
        return
    end

    data.Upgrades = data.Upgrades or {}
    local current = tonumber(data.Upgrades[upgradeKey] or 0) or 0
    if current >= (def.maxLevel or 0) then
        Notify(player, "Already max level!", "error")
        return
    end
    local cost = GetUpgradeCost(upgradeKey, current)
    if data.Data < cost then
        Notify(player, "Need " .. cost .. " Data!", "error")
        return
    end

    data.Data -= cost
    data.TotalSpent = (data.TotalSpent or 0) + cost
    local newLevel = current + 1
    data.Upgrades[upgradeKey] = newLevel
    PlayerUpgrades[player.UserId] = data.Upgrades
    UpdateData(player)
    ApplyPlayerStats(player)

    local effect = (def.baseEffect or 0) * newLevel
    PlayerUpgraded:FireClient(player, {upgradeKey = upgradeKey, newLevel = newLevel, effect = effect, cost = cost})
    Notify(player, "Upgraded " .. upgradeKey .. " to Lv." .. newLevel .. "!", "success")
    print(string.format("[UPG] %s upgraded %s -> %d (cost %d)", player.Name, upgradeKey, newLevel, cost))
end)

PurchaseFunUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
    local data = PlayerData[player.UserId]; if not data then return end
    if type(upgradeKey) ~= "string" then
        LogInvalidCall(player, "PurchaseFunUpgrade")
        return
    end
    local def = FUN_UPGRADES[upgradeKey]
    if not def then
        Notify(player, "Fun upgrade not found!", "error")
        return
    end
    data.FunUpgrades = data.FunUpgrades or {}
    if data.FunUpgrades[upgradeKey] then
        Notify(player, "Already owned!", "error")
        return
    end
    local cost = def.cost or 0
    if data.Data < cost then
        Notify(player, "Need " .. cost .. " Data!", "error")
        return
    end
    data.Data -= cost
    data.TotalSpent = (data.TotalSpent or 0) + cost
    data.FunUpgrades[upgradeKey] = true
    UpdateData(player)

    Notify(player, "Purchased: " .. (def.name or upgradeKey), "success")
    print(string.format("[FUN] %s purchased %s (cost %d)", player.Name, upgradeKey, cost))
end)

GetPlayerData.OnServerInvoke = function(player)
    local data = PlayerData[player.UserId]
    if not data then
        return {ok = false, reason = "loading"}
    end
    return {
        ok = true,
        data = {
        	Data = data.Data,
        	TotalEarned = data.TotalEarned,
        	TotalSpent = data.TotalSpent,
        	Plot = data.Plot,
        	Upgrades = data.Upgrades,
        	FunUpgrades = data.FunUpgrades,
        	Title = data.Title,
        	Pet = data.Pet,
        	DailyStreak = data.DailyStreak,
        	BlocksCollected = data.BlocksCollected,
        }
    }
end

print("[OK] All event handlers connected")

-- ============================================================
-- PASSIVE INCOME (every 1s, in-memory only)
-- ============================================================
task.spawn(function()
    print("[OK] Passive income loop running")
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                local totalDPS = CONFIG.PASSIVE_INCOME

                -- Add plot building DPS
                local plot = PlayerPlot[p.UserId]
                if plot then
                    local building = PLOT_BUILDINGS[plot.tier or 1]
                    if building then totalDPS = totalDPS + (building.dpsBonus or 0) end
                    -- Add decoration DPS
                    for _, decName in ipairs(plot.decorations or {}) do
                        local dec = GetDecorationByName(decName)
                        if dec then totalDPS = totalDPS + (dec.dpsBonus or 0) end
                    end
                end

                -- Add player upgrade DPS
                local upgrades = PlayerUpgrades[p.UserId]
                if upgrades then
                    totalDPS = totalDPS + (upgrades.dataMiningSpeed or 0) * (PLAYER_UPGRADES.dataMiningSpeed.baseEffect)
                end

                data.Data        = data.Data + totalDPS
                data.TotalEarned = data.TotalEarned + totalDPS
                UpdateData(p)
            end
        end
    end
end)

-- ============================================================
-- AUTOSAVE every 60s
-- ============================================================
task.spawn(function()
    while true do
        task.wait(60)
        for _, p in ipairs(Players:GetPlayers()) do
            task.spawn(SavePlayerData, p)
        end
        print("[DATA] Autosave complete")
    end
end)

-- ============================================================
-- PLAYER CONNECTIONS
-- ============================================================
local function onPlayerAdded(player)
    print("[JOIN] "..player.Name)
    task.spawn(LoadPlayerData, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Backfill: handles Studio local test where player joins before script connects
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
    print("[LEAVE] "..player.Name)
    task.spawn(SavePlayerData, player)
    task.delay(5, function()
        PlayerData[player.UserId]   = nil
        orbCooldowns[player.UserId] = nil
    end)
end)

game:BindToClose(function()
    print("[DATA] Closing — saving all players...")
    for _, p in ipairs(Players:GetPlayers()) do SavePlayerData(p) end
    print("[DATA] All saved.")
end)

-- (v0.30) No global plot initialization
print(("="):rep(50))
print("DataTycoon v0.23 — SERVER READY")
print(("="):rep(50))
