--[[
    LandSystem.lua
    Server-side land/plot purchasing system for DataTycoon
    Handles plot ownership, pricing, and land expansion
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataCurrency = require(ReplicatedStorage.Modules.DataCurrency)

local LandSystem = {}

-- Plot configuration
local PLOT_SIZE = 32      -- Studs per plot side
local BASE_PRICE = 50     -- Data cost for first plot
local PRICE_MULTIPLIER = 1.5  -- Each subsequent plot costs more
local MAX_PLOTS = 25      -- Maximum plots per player

-- Plot storage: plotId = { owner = userId, position = {x, z}, price = number }
local Plots = {}
local PlotGrid = {}       -- grid[x][z] = plotId

-- Generate a unique plot ID
local function GeneratePlotId(x, z)
    return "plot_" .. x .. "_" .. z
end

-- Calculate plot price based on distance from center
local function CalculatePlotPrice(x, z)
    local distance = math.sqrt(x * x + z * z)
    local price = BASE_PRICE * (PRICE_MULTIPLIER ^ distance)
    return math.floor(price)
end

-- Initialize the plot grid (call this when server starts)
function LandSystem:Initialize()
    -- Create a 10x10 grid of purchasable plots centered at 0,0
    for x = -5, 5 do
        PlotGrid[x] = {}
        for z = -5, 5 do
            local plotId = GeneratePlotId(x, z)
            Plots[plotId] = {
                id = plotId,
                owner = nil,        -- nil = unowned
                position = {x = x, z = z},
                price = CalculatePlotPrice(x, z),
                center = Vector3.new(x * PLOT_SIZE, 0, z * PLOT_SIZE),
                size = PLOT_SIZE,
            }
            PlotGrid[x][z] = plotId
        end
    end
    print("DataTycoon: Land system initialized with " .. #Plots .. " plots")
end

-- Check if a plot is available for purchase
function LandSystem:IsPlotAvailable(plotId)
    local plot = Plots[plotId]
    if not plot then return false end
    return plot.owner == nil
end

-- Get plot info
function LandSystem:GetPlotInfo(plotId)
    return Plots[plotId]
end

-- Get all plots owned by a player
function LandSystem:GetPlayerPlots(player)
    local owned = {}
    for plotId, plot in pairs(Plots) do
        if plot.owner == player.UserId then
            table.insert(owned, plot)
        end
    end
    return owned
end

-- Purchase a plot
function LandSystem:PurchasePlot(player, plotId)
    local plot = Plots[plotId]
    if not plot then return false, "Plot does not exist" end
    if plot.owner ~= nil then return false, "Plot already owned" end
    
    -- Check player's plot count
    local playerPlots = self:GetPlayerPlots(player)
    if #playerPlots >= MAX_PLOTS then
        return false, "Maximum plots reached (" .. MAX_PLOTS .. ")"
    end
    
    -- Check if player has enough Data
    local data = DataCurrency:GetPlayerData(player)
    if not data then return false, "Player data not loaded" end
    
    if data.Data < plot.price then
        return false, "Not enough Data (need " .. plot.price .. ")"
    end
    
    -- Deduct Data and assign ownership
    local success = DataCurrency:RemoveData(player, plot.price)
    if not success then return false, "Transaction failed" end
    
    plot.owner = player.UserId
    
    -- Fire event to client to update the plot visually
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        local plotPurchased = events:FindFirstChild("PlotPurchased")
        if plotPurchased then
            plotPurchased:FireAllClients(plotId, player.UserId)
        end
    end
    
    print("DataTycoon: " .. player.Name .. " purchased plot " .. plotId .. " for " .. plot.price .. " Data")
    return true, "Purchase successful!"
end

-- Sell a plot back (for 50% of purchase price)
function LandSystem:SellPlot(player, plotId)
    local plot = Plots[plotId]
    if not plot then return false, "Plot does not exist" end
    if plot.owner ~= player.UserId then return false, "You don't own this plot" end
    
    local refund = math.floor(plot.price * 0.5)
    DataCurrency:AddData(player, refund)
    plot.owner = nil
    
    -- Fire event to client
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        local plotSold = events:FindFirstChild("PlotSold")
        if plotSold then
            plotSold:FireAllClients(plotId)
        end
    end
    
    return true, "Sold for " .. refund .. " Data"
end

-- Get all plots (for client rendering)
function LandSystem:GetAllPlots()
    return Plots
end

-- Get plot at grid position
function LandSystem:GetPlotAt(x, z)
    local plotId = PlotGrid[x] and PlotGrid[x][z]
    if plotId then
        return Plots[plotId]
    end
    return nil
end

-- Check if a position is inside a plot
function LandSystem:GetPlotAtPosition(position)
    local x = math.floor(position.X / PLOT_SIZE + 0.5)
    local z = math.floor(position.Z / PLOT_SIZE + 0.5)
    return self:GetPlotAt(x, z)
end

return LandSystem
