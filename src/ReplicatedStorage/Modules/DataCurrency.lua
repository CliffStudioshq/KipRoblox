--[[
    DataCurrency.lua
    Server-side currency system for DataTycoon
    Handles player Data balance, transactions, and leaderstats
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataStore = DataStoreService:GetDataStore("DataTycoon_v1")

local PlayerData = {}

-- Default player data
local DEFAULT_DATA = {
    Data = 100,           -- Starting Data
    LandOwned = {},       -- List of plot IDs owned
    Computers = {},       -- List of computers placed
    HouseTier = 1,        -- 1=Shack, 5=Mega Compound
    TotalEarned = 0,
    TotalSpent = 0,
}

local DataCurrency = {}

-- Load player data from DataStore
function DataCurrency:LoadPlayerData(player)
    local key = "Player_" .. player.UserId
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    
    if success and data then
        -- Merge with defaults in case new fields were added
        for key, value in pairs(DEFAULT_DATA) do
            if data[key] == nil then
                data[key] = value
            end
        end
        PlayerData[player.UserId] = data
    else
        PlayerData[player.UserId] = table.clone(DEFAULT_DATA)
    end
    
    self:SetupLeaderstats(player)
    return PlayerData[player.UserId]
end

-- Save player data to DataStore
function DataCurrency:SavePlayerData(player)
    if not PlayerData[player.UserId] then return end
    
    local key = "Player_" .. player.UserId
    local success, err = pcall(function()
        DataStore:SetAsync(key, PlayerData[player.UserId])
    end)
    
    if not success then
        warn("DataTycoon: Failed to save data for " .. player.Name .. ": " .. tostring(err))
    end
end

-- Create leaderstats GUI for the player
function DataCurrency:SetupLeaderstats(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local dataValue = Instance.new("IntValue")
    dataValue.Name = "Data"
    dataValue.Value = data.Data
    dataValue.Parent = leaderstats
    
    local houseValue = Instance.new("IntValue")
    houseValue.Name = "House"
    houseValue.Value = data.HouseTier
    houseValue.Parent = leaderstats
end

-- Add Data to a player's balance
function DataCurrency:AddData(player, amount)
    local data = PlayerData[player.UserId]
    if not data then return false end
    
    data.Data = data.Data + amount
    data.TotalEarned = data.TotalEarned + amount
    
    -- Update leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    
    return true
end

-- Remove Data from a player's balance (returns false if insufficient)
function DataCurrency:RemoveData(player, amount)
    local data = PlayerData[player.UserId]
    if not data then return false end
    
    if data.Data < amount then
        return false -- Insufficient funds
    end
    
    data.Data = data.Data - amount
    data.TotalSpent = data.TotalSpent + amount
    
    -- Update leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local dataValue = leaderstats:FindFirstChild("Data")
        if dataValue then
            dataValue.Value = data.Data
        end
    end
    
    return true
end

-- Get a player's Data balance
function DataCurrency:GetData(player)
    local data = PlayerData[player.UserId]
    if not data then return 0 end
    return data.Data
end

-- Get full player data table
function DataCurrency:GetPlayerData(player)
    return PlayerData[player.UserId]
end

-- Get full player data by UserId (for inter-player transactions)
function DataCurrency:GetPlayerDataById(userId)
    return PlayerData[userId]
end

-- Add Data by UserId (for raid systems)
function DataCurrency:AddDataById(userId, amount)
    local data = PlayerData[userId]
    if not data then return false end
    
    data.Data = data.Data + amount
    data.TotalEarned = data.TotalEarned + amount
    
    -- Update leaderstats if player is in game
    local player = Players:GetPlayerByUserId(userId)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local dataValue = leaderstats:FindFirstChild("Data")
            if dataValue then
                dataValue.Value = data.Data
            end
        end
    end
    
    return true
end

-- Remove Data by UserId (for raid systems)
function DataCurrency:RemoveDataById(userId, amount)
    local data = PlayerData[userId]
    if not data then return false end
    
    if data.Data < amount then
        return false
    end
    
    data.Data = data.Data - amount
    data.TotalSpent = data.TotalSpent + amount
    
    -- Update leaderstats if player is in game
    local player = Players:GetPlayerByUserId(userId)
    if player then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local dataValue = leaderstats:FindFirstChild("Data")
            if dataValue then
                dataValue.Value = data.Data
            end
        end
    end
    
    return true
end

-- Transfer Data between players
function DataCurrency:TransferData(fromPlayer, toPlayer, amount)
    local fromData = PlayerData[fromPlayer.UserId]
    local toData = PlayerData[toPlayer.UserId]
    
    if not fromData or not toData then return false end
    if fromData.Data < amount then return false end
    
    fromData.Data = fromData.Data - amount
    fromData.TotalSpent = fromData.TotalSpent + amount
    toData.Data = toData.Data + amount
    toData.TotalEarned = toData.TotalEarned + amount
    
    -- Update both leaderstats
    for _, player in ipairs({fromPlayer, toPlayer}) do
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local dataValue = leaderstats:FindFirstChild("Data")
            if dataValue then
                dataValue.Value = PlayerData[player.UserId].Data
            end
        end
    end
    
    return true
end

-- Player joined - load their data
Players.PlayerAdded:Connect(function(player)
    DataCurrency:LoadPlayerData(player)
end)

-- Player leaving - save their data
Players.PlayerRemoving:Connect(function(player)
    DataCurrency:SavePlayerData(player)
    PlayerData[player.UserId] = nil
end)

-- Save all data on server shutdown
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DataCurrency:SavePlayerData(player)
    end
end)

-- Auto-save every 5 minutes
task.spawn(function()
    while true do
        task.wait(300)
        for _, player in ipairs(Players:GetPlayers()) do
            DataCurrency:SavePlayerData(player)
        end
    end
end)

return DataCurrency
