--[[
    Main.server.lua — DataTycoon Server
    v0.4 — SIMPLIFIED: Go back to what worked in v0.1
    - Create RemoteEvents directly (no module system)
    - leaderstats as primary data display
    - DataStore for saving/loading
    - Daily rewards, offline income, computer mining
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local DataStore = DataStoreService:GetDataStore("DataTycoon_v2")

-- === CREATE REMOTE EVENTS ===
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
local CollectBlocks = CreateEvent("CollectBlocks")
local PurchasePlot = CreateEvent("PurchasePlot")

-- Server → Client
local DailyRewardClaimed = CreateEvent("DailyRewardClaimed")
local Notification = CreateEvent("Notification")
local DataUpdated = CreateEvent("DataUpdated")

print("DataTycoon: RemoteEvents created!")

-- === CONFIGURATION ===
local CONFIG = {
    STARTING_DATA = 50,
    BLOCK_REWARD = 5,
    DAILY_REWARDS = {50, 75, 100, 150, 200, 300, 500},
}

-- === PLAYER DATA ===
local PlayerData = {}

local DEFAULT_DATA = {
    Data = CONFIG.STARTING_DATA,
    TotalEarned = CONFIG.STARTING_DATA,
    HouseTier = 1,
    LastLogin = 0,
    DailyStreak = 0,
    LastDailyReward = 0,
}

-- === FUNCTIONS ===

local function LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, savedData = pcall(function()
        return DataStore:GetAsync(key)
    end)
    
    if success and savedData then
        -- Merge with defaults for any new fields
        for k, v in pairs(DEFAULT_DATA) do
            if savedData[k] == nil then
                savedData[k] = v
            end
        end
        PlayerData[player.UserId] = savedData
        print("DataTycoon: Loaded data for " .. player.Name .. " (Data: " .. savedData.Data .. ")")
    else
        PlayerData[player.UserId] = {}
        for k, v in pairs(DEFAULT_DATA) do
            PlayerData[player.UserId][k] = v
        end
        print("DataTycoon: New player " .. player.Name .. " (Data: " .. CONFIG.STARTING_DATA .. ")")
    end
    
    -- Offline income
    local now = os.time()
    local lastLogin = PlayerData[player.UserId].LastLogin or now
    local timeAway = math.max(0, now - lastLogin)
    
    if timeAway > 60 then
        local offlineEarnings = math.floor(timeAway * 0.5)  -- 0.5 Data per second offline
        if offlineEarnings > 0 then
            PlayerData[player.UserId].Data = PlayerData[player.UserId].Data + offlineEarnings
            PlayerData[player.UserId].TotalEarned = PlayerData[player.UserId].TotalEarned + offlineEarnings
            print("DataTycoon: " .. player.Name .. " earned " .. offlineEarnings .. " offline Data")
        end
    end
    
    PlayerData[player.UserId].LastLogin = now
    
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
    
    print("DataTycoon: Leaderstats created for " .. player.Name .. " (Data: " .. PlayerData[player.UserId].Data .. ")")
end

local function SavePlayerData(player)
    if not PlayerData[player.UserId] then return end
    local key = "Player_" .. player.UserId
    local success = pcall(function()
        DataStore:SetAsync(key, PlayerData[player.UserId])
    end)
    if success then
        print("DataTycoon: Saved data for " .. player.Name)
    else
        warn("DataTycoon: Failed to save data for " .. player.Name)
    end
end

local function UpdateData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    DataUpdated:FireClient(player, data.Data)
end

-- === EVENT HANDLERS ===

ClaimDailyReward.OnServerEvent:Connect(function(player)
    print("DataTycoon: Daily reward from " .. player.Name)
    
    local data = PlayerData[player.UserId]
    if not data then
        warn("DataTycoon: No data for " .. player.Name)
        return
    end
    
    local now = os.time()
    local lastClaim = data.LastDailyReward or 0
    local daysSinceLast = math.floor((now - lastClaim) / 86400)
    
    if daysSinceLast == 0 then
        Notification:FireClient(player, "Already claimed today!", "error")
        return
    end
    
    if daysSinceLast > 1 then
        data.DailyStreak = 1
    else
        data.DailyStreak = (data.DailyStreak or 0) + 1
    end
    
    local rewardIndex = ((data.DailyStreak - 1) % #CONFIG.DAILY_REWARDS) + 1
    local reward = CONFIG.DAILY_REWARDS[rewardIndex]
    
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    data.LastDailyReward = now
    
    UpdateData(player)
    DailyRewardClaimed:FireClient(player, reward, data.DailyStreak)
    Notification:FireClient(player, "Day " .. data.DailyStreak .. ": +" .. reward .. " Data!", "success")
    
    print("DataTycoon: " .. player.Name .. " got " .. reward .. " Data (day " .. data.DailyStreak .. ")")
end)

CollectBlocks.OnServerEvent:Connect(function(player, blockCount)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local reward = (blockCount or 1) * CONFIG.BLOCK_REWARD
    data.Data = data.Data + reward
    data.TotalEarned = data.TotalEarned + reward
    UpdateData(player)
    
    Notification:FireClient(player, "+" .. reward .. " Data!", "success")
    print("DataTycoon: " .. player.Name .. " collected " .. reward .. " Data")
end)

-- === PASSIVE MINING (simple) ===
task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                -- Passive income: 1 Data per second just for being online
                data.Data = data.Data + 1
                data.TotalEarned = data.TotalEarned + 1
                UpdateData(p)
            end
        end
    end
end)

-- === PLAYER CONNECTIONS ===

Players.PlayerAdded:Connect(function(player)
    LoadPlayerData(player)
    print("DataTycoon: " .. player.Name .. " joined!")
end)

Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
    PlayerData[player.UserId] = nil
    print("DataTycoon: " .. player.Name .. " left, data saved")
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        SavePlayerData(player)
    end
end)

print("DataTycoon v0.4 server ready!")
