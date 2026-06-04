--[[
    Baseplate.server.lua
    Creates the baseplate, spawn, collectible blocks, and plot markers for DataTycoon
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

-- === COLLECTIBLE BLOCKS ===
-- Well-spaced blocks in rings around the spawn

local blockFolder = Instance.new("Folder")
blockFolder.Name = "CollectibleBlocks"
blockFolder.Parent = workspace

local BLOCK_REWARD = 5
local RESPAWN_TIME = 10

-- Generate block positions in concentric rings
local blockPositions = {}
local function AddRing(radius, count)
    for i = 0, count - 1 do
        local angle = (i / count) * math.pi * 2
        local x = math.floor(math.cos(angle) * radius)
        local z = math.floor(math.sin(angle) * radius)
        table.insert(blockPositions, {x, 2, z})
    end
end

AddRing(25, 6)    -- Inner ring: 6 blocks
AddRing(50, 10)   -- Middle ring: 10 blocks
AddRing(80, 12)   -- Outer ring: 12 blocks
AddRing(110, 16)  -- Far ring: 16 blocks

local blockCount = 0
for _, pos in ipairs(blockPositions) do
    local block = Instance.new("Part")
    block.Name = "DataBlock_" .. blockCount
    block.Size = Vector3.new(5, 5, 5)
    block.Position = Vector3.new(pos[1], pos[2], pos[3])
    block.Anchored = true
    block.BrickColor = BrickColor.new("Cyan")
    block.Material = Enum.Material.Neon
    block.Shape = Enum.PartType.Block
    block.Parent = blockFolder
    
    -- Floating animation
    local bodyPos = Instance.new("BodyPosition")
    bodyPos.MaxForce = Vector3.new(0, 10000, 0)
    bodyPos.Position = Vector3.new(pos[1], pos[2] + 2, pos[3])
    bodyPos.Parent = block
    
    -- Slow spin
    local bodySpin = Instance.new("BodyAngularVelocity")
    bodySpin.AngularVelocity = Vector3.new(0, 0.5, 0)
    bodySpin.MaxTorque = Vector3.new(0, 100, 0)
    bodySpin.Parent = block
    
    -- Proximity prompt for collection
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Data Block (+" .. BLOCK_REWARD .. ")"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 12
    prompt.Parent = block
    
    -- Billboard label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = block
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "⛏️  +" .. BLOCK_REWARD .. " Data"
    label.TextColor3 = Color3.fromRGB(0, 255, 220)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.4
    label.Parent = billboard
    
    blockCount = blockCount + 1
end

-- === PLOT MARKERS ===
-- Clean grid with subtle visuals

local plotFolder = Instance.new("Folder")
plotFolder.Name = "PlotMarkers"
plotFolder.Parent = workspace

local PLOT_SIZE = 32

for x = -4, 4 do
    for z = -4, 4 do
        local center = Vector3.new(x * PLOT_SIZE, 0.05, z * PLOT_SIZE)
        local distance = math.sqrt(x * x + z * z)
        local price = math.floor(25 * (1.4 ^ distance))
        
        -- Plot floor tile
        local plotBase = Instance.new("Part")
        plotBase.Name = "Plot_" .. x .. "_" .. z
        plotBase.Size = Vector3.new(PLOT_SIZE - 2, 0.15, PLOT_SIZE - 2)
        plotBase.Position = center
        plotBase.Anchored = true
        plotBase.Material = Enum.Material.SmoothPlastic
        plotBase.Transparency = 0.3
        
        -- Color based on distance
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
        
        -- Price label (only show for nearby plots to reduce clutter)
        if distance <= 3 then
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 100, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 6, 0)
            billboard.AlwaysOnTop = false
            billboard.Parent = plotBase
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = x .. ", " .. z
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 11
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextStrokeTransparency = 0.5
            nameLabel.Parent = billboard
            
            local priceLabel = Instance.new("TextLabel")
            priceLabel.Size = UDim2.new(1, 0, 0.55, 0)
            priceLabel.Position = UDim2.new(0, 0, 0.45, 0)
            priceLabel.BackgroundTransparency = 1
            priceLabel.Text = "💰 " .. price
            priceLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
            priceLabel.TextSize = 12
            priceLabel.Font = Enum.Font.GothamBold
            priceLabel.TextStrokeTransparency = 0.5
            priceLabel.Parent = billboard
        end
    end
end

-- Workspace settings
workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: Baseplate, " .. blockCount .. " blocks, and " .. #plotFolder:GetChildren() .. " plot markers created!")
