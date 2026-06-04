--[[
    Baseplate.server.lua
    Creates the baseplate, spawn, collectible blocks, and plot markers for DataTycoon
    v0.7 — Spacious plots (64x64), 5x5 grid, visual flair
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

-- Spawn location
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Parent = workspace

-- === CONFIG ===
local PLOT_SIZE = 64  -- Much bigger plots (was 32)
local GRID_RANGE = 2  -- 5x5 grid (was 9x9)
local BLOCK_REWARD = 5
local RESPAWN_TIME = 10

-- === COLLECTIBLE BLOCKS ===
-- Rings of floating, spinning blocks at varying heights

local blockFolder = Instance.new("Folder")
blockFolder.Name = "CollectibleBlocks"
blockFolder.Parent = workspace

local blockPositions = {}

-- Inner ring — low blocks near spawn
for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2
    table.insert(blockPositions, {
        x = math.cos(angle) * 30,
        y = 3,
        z = math.sin(angle) * 30,
        color = BrickColor.new("Cyan"),
        size = 5,
    })
end

-- Middle ring — medium height
for i = 1, 10 do
    local angle = (i / 10) * math.pi * 2
    table.insert(blockPositions, {
        x = math.cos(angle) * 65,
        y = 5,
        z = math.sin(angle) * 65,
        color = BrickColor.new("Bright blue"),
        size = 5,
    })
end

-- Outer ring — tall blocks
for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    table.insert(blockPositions, {
        x = math.cos(angle) * 100,
        y = 8,
        z = math.sin(angle) * 100,
        color = BrickColor.new("Bright violet"),
        size = 6,
    })
end

-- Far ring — very tall, glowing
for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2 + 0.4
    table.insert(blockPositions, {
        x = math.cos(angle) * 140,
        y = 12,
        z = math.sin(angle) * 140,
        color = BrickColor.new("Bright yellow"),
        size = 7,
    })
end

local blockCount = 0
for _, bp in ipairs(blockPositions) do
    local block = Instance.new("Part")
    block.Name = "DataBlock_" .. blockCount
    block.Size = Vector3.new(bp.size, bp.size, bp.size)
    block.Position = Vector3.new(bp.x, bp.y, bp.z)
    block.Anchored = true
    block.BrickColor = bp.color
    block.Material = Enum.Material.Neon
    block.Shape = Enum.PartType.Block
    block.Parent = blockFolder
    
    -- Billboard label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, bp.size * 0.8 + 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = block
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "⛏️  +" .. BLOCK_REWARD .. " Data"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard
    
    -- Proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Data Block"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 14
    prompt.Parent = block
    
    blockCount = blockCount + 1
end

-- === PLOT MARKERS ===
-- 5x5 spacious grid with roads between plots

local plotFolder = Instance.new("Folder")
plotFolder.Name = "PlotMarkers"
plotFolder.Parent = workspace

-- Road material between plots
local ROAD_WIDTH = 8

for x = -GRID_RANGE, GRID_RANGE do
    for z = -GRID_RANGE, GRID_RANGE do
        local center = Vector3.new(x * PLOT_SIZE, 0.05, z * PLOT_SIZE)
        local distance = math.sqrt(x * x + z * z)
        local price = math.floor(25 * (1.4 ^ distance))
        
        -- Plot tile
        local plotBase = Instance.new("Part")
        plotBase.Name = "Plot_" .. x .. "_" .. z
        plotBase.Size = Vector3.new(PLOT_SIZE - ROAD_WIDTH, 0.2, PLOT_SIZE - ROAD_WIDTH)
        plotBase.Position = center
        plotBase.Anchored = true
        plotBase.Material = Enum.Material.SmoothPlastic
        plotBase.Transparency = 0.15
        
        -- Color gradient: green (cheap) → yellow → orange → red (expensive)
        if distance <= 1 then
            plotBase.BrickColor = BrickColor.new("Bright green")
        elseif distance <= 2 then
            plotBase.BrickColor = BrickColor.new("Bright yellow")
        elseif distance <= 3 then
            plotBase.BrickColor = BrickColor.new("Bright orange")
        else
            plotBase.BrickColor = BrickColor.new("Bright red")
        end
        plotBase.Parent = plotFolder
        
        -- Corner posts (small pillars at each corner)
        local corners = {
            {PLOT_SIZE/2 - 1, PLOT_SIZE/2 - 1},
            {-PLOT_SIZE/2 + 1, PLOT_SIZE/2 - 1},
            {PLOT_SIZE/2 - 1, -PLOT_SIZE/2 + 1},
            {-PLOT_SIZE/2 + 1, -PLOT_SIZE/2 + 1},
        }
        for _, c in ipairs(corners) do
            local post = Instance.new("Part")
            post.Size = Vector3.new(1.5, 4, 1.5)
            post.Position = Vector3.new(center.X + c[1], 2, center.Z + c[2])
            post.Anchored = true
            post.BrickColor = BrickColor.new("Medium stone grey")
            post.Material = Enum.Material.SmoothPlastic
            post.Transparency = 0.3
            post.Parent = plotBase
        end
        
        -- Price signpost in center of plot
        local sign = Instance.new("Part")
        sign.Size = Vector3.new(1, 6, 1)
        sign.Position = Vector3.new(center.X, 3.1, center.Z)
        sign.Anchored = true
        sign.BrickColor = BrickColor.new("Dark stone grey")
        sign.Material = Enum.Material.SmoothPlastic
        sign.Transparency = 0.2
        sign.Parent = plotBase
        
        -- Billboard on sign
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 140, 0, 70)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = false
        billboard.Parent = sign
        
        local coordLabel = Instance.new("TextLabel")
        coordLabel.Size = UDim2.new(1, 0, 0.35, 0)
        coordLabel.BackgroundTransparency = 1
        coordLabel.Text = "(" .. x .. ", " .. z .. ")"
        coordLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        coordLabel.TextSize = 12
        coordLabel.Font = Enum.Font.GothamBold
        coordLabel.TextStrokeTransparency = 0.5
        coordLabel.Parent = billboard
        
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Size = UDim2.new(1, 0, 0.4, 0)
        priceLabel.Position = UDim2.new(0, 0, 0.35, 0)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = "💰 " .. price .. " Data"
        priceLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        priceLabel.TextSize = 14
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.TextStrokeTransparency = 0.4
        priceLabel.Parent = billboard
        
        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 0.25, 0)
        distLabel.Position = UDim2.new(0, 0, 0.75, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = distance <= 1 and "★ PRIME" or (distance <= 2 and "Good" or "Far")
        distLabel.TextColor3 = distance <= 1 and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(150, 150, 150)
        distLabel.TextSize = 10
        distLabel.Font = Enum.Font.GothamBold
        distLabel.TextStrokeTransparency = 0.5
        distLabel.Parent = billboard
    end
end

-- === ROADS ===
-- Asphalt strips between plots
local roadMat = Enum.Material.Asphalt
local roadColor = BrickColor.new("Dark stone grey")

-- Horizontal roads
for x = -GRID_RANGE, GRID_RANGE do
    local road = Instance.new("Part")
    road.Name = "Road_H_" .. x
    road.Size = Vector3.new(PLOT_SIZE - ROAD_WIDTH, 0.12, PLOT_SIZE * (GRID_RANGE * 2 + 1) + ROAD_WIDTH)
    road.Position = Vector3.new(x * PLOT_SIZE, 0.02, 0)
    road.Anchored = true
    road.BrickColor = roadColor
    road.Material = roadMat
    road.Transparency = 0.1
    road.Parent = workspace
end

-- Vertical roads
for z = -GRID_RANGE, GRID_RANGE do
    local road = Instance.new("Part")
    road.Name = "Road_V_" .. z
    road.Size = Vector3.new(PLOT_SIZE * (GRID_RANGE * 2 + 1) + ROAD_WIDTH, 0.12, PLOT_SIZE - ROAD_WIDTH)
    road.Position = Vector3.new(0, 0.02, z * PLOT_SIZE)
    road.Anchored = true
    road.BrickColor = roadColor
    road.Material = roadMat
    road.Transparency = 0.1
    road.Parent = workspace
end

-- === DECORATIONS ===
-- Trees around the edges
local treePositions = {
    {-180, 180}, {180, 180}, {-180, -180}, {180, -180},
    {-200, 0}, {200, 0}, {0, -200}, {0, 200},
    {-150, 100}, {150, 100}, {-150, -100}, {150, -100},
    {100, 150}, {-100, 150}, {100, -150}, {-100, -150},
}

for _, pos in ipairs(treePositions) do
    -- Trunk
    local trunk = Instance.new("Part")
    trunk.Size = Vector3.new(3, 12, 3)
    trunk.Position = Vector3.new(pos[1], 6, pos[2])
    trunk.Anchored = true
    trunk.BrickColor = BrickColor.new("Brown")
    trunk.Material = Enum.Material.Wood
    trunk.Parent = workspace
    
    -- Canopy
    local canopy = Instance.new("Part")
    canopy.Shape = Enum.PartType.Ball
    canopy.Size = Vector3.new(14, 14, 14)
    canopy.Position = Vector3.new(pos[1], 15, pos[2])
    canopy.Anchored = true
    canopy.BrickColor = BrickColor.new("Dark green")
    canopy.Material = Enum.Material.Grass
    canopy.Transparency = 0.1
    canopy.Parent = workspace
end

-- Workspace settings
workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: Baseplate, " .. blockCount .. " blocks, " .. (GRID_RANGE * 2 + 1) .. "x" .. (GRID_RANGE * 2 + 1) .. " plots, roads, and trees created!")
