--[[
    Baseplate.server.lua
    Creates the baseplate, spawn, and collectible blocks for DataTycoon
]]

-- Create the baseplate
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = Vector3.new(512, 1, 512)
baseplate.Position = Vector3.new(0, -0.5, 0)
baseplate.Anchored = true
baseplate.BrickColor = BrickColor.new("Dark green")
baseplate.Material = Enum.Material.Grass
baseplate.Parent = workspace

-- Create a spawn location
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Parent = workspace

-- === COLLECTIBLE BLOCKS ===
-- Scatter blocks around the map that players can walk over to collect

local blockPositions = {
    {20, 1, 20}, {-20, 1, 20}, {20, 1, -20}, {-20, 1, -20},
    {40, 1, 0}, {-40, 1, 0}, {0, 1, 40}, {0, 1, -40},
    {30, 1, 30}, {-30, 1, 30}, {30, 1, -30}, {-30, 1, -30},
    {60, 1, 0}, {-60, 1, 0}, {0, 1, 60}, {0, 1, -60},
    {50, 1, 50}, {-50, 1, 50}, {50, 1, -50}, {-50, 1, -50},
    {15, 1, 45}, {-15, 1, 45}, {15, 1, -45}, {-15, 1, -45},
    {45, 1, 15}, {-45, 1, 15}, {45, 1, -15}, {-45, 1, -15},
}

local blockFolder = Instance.new("Folder")
blockFolder.Name = "CollectibleBlocks"
blockFolder.Parent = workspace

local blockCount = 0
for _, pos in ipairs(blockPositions) do
    local block = Instance.new("Part")
    block.Name = "DataBlock_" .. blockCount
    block.Size = Vector3.new(4, 4, 4)
    block.Position = Vector3.new(pos[1], pos[2], pos[3])
    block.Anchored = true
    block.BrickColor = BrickColor.new("Cyan")
    block.Material = Enum.Material.Neon
    block.Shape = Enum.PartType.Block
    block.Parent = blockFolder
    
    -- Add a click detector for collecting
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 12
    clickDetector.Parent = block
    
    -- Add a billboard gui to show it's collectible
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = block
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "⛏️ +5 Data"
    label.TextColor3 = Color3.fromRGB(0, 255, 200)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.5
    label.Parent = billboard
    
    blockCount = blockCount + 1
end

-- === PLOT MARKERS ===
-- Visual markers for each plot

local plotFolder = Instance.new("Folder")
plotFolder.Name = "PlotMarkers"
plotFolder.Parent = workspace

local PLOT_SIZE = 32

for x = -4, 4 do
    for z = -4, 4 do
        local center = Vector3.new(x * PLOT_SIZE, 0.1, z * PLOT_SIZE)
        
        -- Plot border
        local plotBase = Instance.new("Part")
        plotBase.Name = "PlotMarker_" .. x .. "_" .. z
        plotBase.Size = Vector3.new(PLOT_SIZE - 1, 0.2, PLOT_SIZE - 1)
        plotBase.Position = center
        plotBase.Anchored = true
        plotBase.BrickColor = BrickColor.new("Medium stone grey")
        plotBase.Material = Enum.Material.SmoothPlastic
        plotBase.Transparency = 0.5
        plotBase.Parent = plotFolder
        
        -- Plot label
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 120, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = plotBase
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0.5, 0)
        label.BackgroundTransparency = 1
        label.Text = "Plot " .. x .. "," .. z
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 12
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.5
        label.Parent = billboard
        
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
        priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
        priceLabel.BackgroundTransparency = 1
        local distance = math.sqrt(x * x + z * z)
        local price = math.floor(25 * (1.4 ^ distance))
        priceLabel.Text = "💰 " .. price .. " Data"
        priceLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        priceLabel.TextSize = 11
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.TextStrokeTransparency = 0.5
        priceLabel.Parent = billboard
    end
end

-- Set workspace properties
workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: Baseplate, " .. blockCount .. " blocks, and plot markers created!")
