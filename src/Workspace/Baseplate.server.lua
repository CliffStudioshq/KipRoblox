--[[
    Baseplate.server.lua — DataTycoon World
    v0.8 — Complete world overhaul
    Layout: Center = data harvesting hub, Outer ring = player plots
    Massive detail: buildings, roads, trees, lamps, water, fences, decorations
]]

local function CreatePart(props)
    local p = Instance.new("Part")
    p.Name = props.Name or "Part"
    p.Size = props.Size or Vector3.new(4, 4, 4)
    p.Position = props.Position or Vector3.new(0, 0, 0)
    p.Anchored = true
    p.BrickColor = props.Color or BrickColor.new("Medium stone grey")
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.Transparency = props.Transparency or 0
    p.Shape = props.Shape or Enum.PartType.Block
    p.Parent = props.Parent or workspace
    if props.Rotation then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.Rotation), 0)
    end
    return p
end

local function AddCorner(parent, x, z, height, color)
    local post = CreatePart({
        Name = "Post",
        Size = Vector3.new(1.2, height or 5, 1.2),
        Position = Vector3.new(x, (height or 5) / 2, z),
        Color = color or BrickColor.new("Dark stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.2,
        Parent = parent,
    })
    -- Ball on top
    local ball = CreatePart({
        Name = "PostTop",
        Size = Vector3.new(1.8, 1.8, 1.8),
        Position = Vector3.new(x, (height or 5) + 0.9, z),
        Color = color or BrickColor.new("Dark stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Shape = Enum.PartType.Ball,
        Transparency = 0.2,
        Parent = parent,
    })
end

local function AddTree(x, z, scale)
    scale = scale or 1
    local trunk = CreatePart({
        Name = "TreeTrunk",
        Size = Vector3.new(2.5 * scale, 10 * scale, 2.5 * scale),
        Position = Vector3.new(x, 5 * scale, z),
        Color = BrickColor.new("Brown"),
        Material = Enum.Material.Wood,
    })
    -- Multi-layer canopy
    local c1 = CreatePart({
        Name = "Canopy1",
        Size = Vector3.new(12 * scale, 8 * scale, 12 * scale),
        Position = Vector3.new(x, 12 * scale, z),
        Color = BrickColor.new("Dark green"),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        Transparency = 0.05,
    })
    local c2 = CreatePart({
        Name = "Canopy2",
        Size = Vector3.new(9 * scale, 7 * scale, 9 * scale),
        Position = Vector3.new(x + 2 * scale, 15 * scale, z + 1 * scale),
        Color = BrickColor.new("Earth green"),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        Transparency = 0.1,
    })
    local c3 = CreatePart({
        Name = "Canopy3",
        Size = Vector3.new(7 * scale, 6 * scale, 7 * scale),
        Position = Vector3.new(x - 1 * scale, 17 * scale, z - 2 * scale),
        Color = BrickColor.new("Forest green"),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        Transparency = 0.15,
    })
end

local function AddLamp(x, z)
    -- Pole
    local pole = CreatePart({
        Name = "LampPole",
        Size = Vector3.new(0.8, 10, 0.8),
        Position = Vector3.new(x, 5, z),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Metal,
        Transparency = 0.1,
    })
    -- Light housing
    local housing = CreatePart({
        Name = "LampHousing",
        Size = Vector3.new(3, 1.5, 3),
        Position = Vector3.new(x, 10.5, z),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Metal,
        Transparency = 0.1,
    })
    -- Glow
    local glow = CreatePart({
        Name = "LampGlow",
        Size = Vector3.new(2.5, 0.5, 2.5),
        Position = Vector3.new(x, 9.5, z),
        Color = BrickColor.new("Institutional white"),
        Material = Enum.Material.Neon,
        Transparency = 0.3,
    })
    -- Actual light
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 240, 200)
    light.Brightness = 2
    light.Range = 30
    light.Parent = glow
end

local function AddBench(x, z, rotation)
    -- Seat
    local seat = CreatePart({
        Name = "BenchSeat",
        Size = Vector3.new(6, 0.5, 2),
        Position = Vector3.new(x, 2.5, z),
        Color = BrickColor.new("Brown"),
        Material = Enum.Material.Wood,
        Rotation = rotation,
    })
    -- Back
    local back = CreatePart({
        Name = "BenchBack",
        Size = Vector3.new(6, 3, 0.5),
        Position = Vector3.new(x, 4.5, z + 0.75 * (rotation and 1 or 1)),
        Color = BrickColor.new("Brown"),
        Material = Enum.Material.Wood,
        Rotation = rotation,
    })
    -- Legs
    for _, offset in ipairs({-2.2, 2.2}) do
        CreatePart({
            Name = "BenchLeg",
            Size = Vector3.new(0.5, 2, 0.5),
            Position = Vector3.new(x + offset, 1, z),
            Color = BrickColor.new("Dark stone grey"),
            Material = Enum.Material.Metal,
        })
    end
end

local function AddBush(x, z, scale)
    scale = scale or 1
    for i = 1, 3 do
        CreatePart({
            Name = "Bush",
            Size = Vector3.new(3 * scale, 2.5 * scale, 3 * scale),
            Position = Vector3.new(x + math.random(-1, 1), 1.25 * scale, z + math.random(-1, 1)),
            Color = BrickColor.new("Dark green"),
            Material = Enum.Material.Grass,
            Shape = Enum.PartType.Ball,
            Transparency = 0.1,
        })
    end
end

local function AddFlower(x, z)
    -- Stem
    CreatePart({
        Name = "FlowerStem",
        Size = Vector3.new(0.3, 1.5, 0.3),
        Position = Vector3.new(x, 0.75, z),
        Color = BrickColor.new("Dark green"),
        Material = Enum.Material.Grass,
    })
    -- Bloom
    local colors = {"Bright red", "Bright yellow", "Bright violet", "Bright orange", "Pink", "Cyan"}
    local color = colors[math.random(#colors)]
    CreatePart({
        Name = "FlowerBloom",
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(x, 1.8, z),
        Color = BrickColor.new(color),
        Material = Enum.Material.SmoothPlastic,
        Shape = Enum.PartType.Ball,
        Transparency = 0.2,
    })
end

local function AddRock(x, z, scale)
    scale = scale or 1
    CreatePart({
        Name = "Rock",
        Size = Vector3.new(3 * scale, 2 * scale, 3 * scale),
        Position = Vector3.new(x, 1 * scale, z),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Slate,
        Shape = Enum.PartType.Ball,
        Transparency = 0.1,
    })
end

-- ============================================================
-- BASEPLATE
-- ============================================================

local baseplate = CreatePart({
    Name = "Baseplate",
    Size = Vector3.new(512, 1, 512),
    Position = Vector3.new(0, -0.5, 0),
    Color = BrickColor.new("Dark green"),
    Material = Enum.Material.Grass,
})

-- Spawn
local spawn = CreatePart({
    Name = "SpawnLocation",
    Size = Vector3.new(8, 1, 8),
    Position = Vector3.new(0, 0.5, 0),
    Color = BrickColor.new("Bright green"),
    Material = Enum.Material.Neon,
    Transparency = 0.5,
})
spawn.CanCollide = false

-- ============================================================
-- CENTER: DATA HARVESTING HUB
-- ============================================================

local hubFolder = Instance.new("Folder")
hubFolder.Name = "DataHub"
hubFolder.Parent = workspace

-- Central platform (raised)
local hubPlatform = CreatePart({
    Name = "HubPlatform",
    Size = Vector3.new(80, 2, 80),
    Position = Vector3.new(0, 1, 0),
    Color = BrickColor.new("Dark stone grey"),
    Material = Enum.Material.SmoothPlastic,
    Parent = hubFolder,
})

-- Inner glowing ring
local hubRing = CreatePart({
    Name = "HubRing",
    Size = Vector3.new(50, 0.5, 50),
    Position = Vector3.new(0, 2.1, 0),
    Color = BrickColor.new("Cyan"),
    Material = Enum.Material.Neon,
    Transparency = 0.3,
    Parent = hubFolder,
})

-- Central server tower
for floor = 0, 4 do
    local y = 3 + floor * 8
    local size = 20 - floor * 2
    local tower = CreatePart({
        Name = "ServerTower_F" .. floor,
        Size = Vector3.new(size, 7, size),
        Position = Vector3.new(0, y, 0),
        Color = BrickColor.new(floor % 2 == 0 and "Dark stone grey" or "Medium stone grey"),
        Material = Enum.Material.Metal,
        Transparency = 0.1,
        Parent = hubFolder,
    })
    -- Glow strips on each floor
    local glowStrip = CreatePart({
        Name = "TowerGlow_F" .. floor,
        Size = Vector3.new(size + 0.5, 0.3, size + 0.5),
        Position = Vector3.new(0, y - 3.3, 0),
        Color = BrickColor.new("Cyan"),
        Material = Enum.Material.Neon,
        Transparency = 0.4,
        Parent = hubFolder,
    })
end

-- Server racks around the hub
for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2
    local x = math.cos(angle) * 28
    local z = math.sin(angle) * 28
    local rack = CreatePart({
        Name = "ServerRack_" .. i,
        Size = Vector3.new(6, 12, 3),
        Position = Vector3.new(x, 7, z),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Metal,
        Transparency = 0.1,
        Parent = hubFolder,
    })
    -- Blinking lights on rack
    for light = 0, 3 do
        CreatePart({
            Name = "RackLight_" .. i .. "_" .. light,
            Size = Vector3.new(0.8, 0.4, 0.8),
            Position = Vector3.new(x, 3 + light * 2.5, z + 1.6),
            Color = BrickColor.new(light % 2 == 0 and "Lime green" or "Bright green"),
            Material = Enum.Material.Neon,
            Transparency = 0.2,
            Parent = hubFolder,
        })
    end
end

-- Data stream pillars (tall glowing columns)
for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2
    local x = math.cos(angle) * 18
    local z = math.sin(angle) * 18
    CreatePart({
        Name = "DataPillar_" .. i,
        Size = Vector3.new(2, 20, 2),
        Position = Vector3.new(x, 11, z),
        Color = BrickColor.new("Cyan"),
        Material = Enum.Material.Neon,
        Transparency = 0.5,
        Parent = hubFolder,
    })
end

-- Floating data orbs above the hub
for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    local radius = 10 + (i % 3) * 5
    local x = math.cos(angle) * radius
    local z = math.sin(angle) * radius
    CreatePart({
        Name = "DataOrb_" .. i,
        Size = Vector3.new(2, 2, 2),
        Position = Vector3.new(x, 25 + math.sin(i) * 3, z),
        Color = BrickColor.new(i % 2 == 0 and "Cyan" or "Bright blue"),
        Material = Enum.Material.Neon,
        Shape = Enum.PartType.Ball,
        Transparency = 0.3,
        Parent = hubFolder,
    })
end

-- Hub entrance arches
for i = 1, 4 do
    local angle = (i / 4) * math.pi * 2
    local x = math.cos(angle) * 42
    local z = math.sin(angle) * 42
    -- Arch pillars
    CreatePart({
        Name = "ArchPillar_" .. i,
        Size = Vector3.new(3, 15, 3),
        Position = Vector3.new(x, 8.5, z),
        Color = BrickColor.new("Medium stone grey"),
        Material = Enum.Material.Metal,
        Transparency = 0.1,
        Parent = hubFolder,
    })
    -- Arch top
    CreatePart({
        Name = "ArchTop_" .. i,
        Size = Vector3.new(3, 2, 8),
        Position = Vector3.new(x, 16, z),
        Color = BrickColor.new("Cyan"),
        Material = Enum.Material.Neon,
        Transparency = 0.4,
        Parent = hubFolder,
    })
end

print("DataTycoon: Data hub created!")

-- ============================================================
-- COLLECTIBLE BLOCKS (scattered around the hub)
-- ============================================================

local blockFolder = Instance.new("Folder")
blockFolder.Name = "CollectibleBlocks"
blockFolder.Parent = workspace

local BLOCK_REWARD = 5

-- Generate blocks in rings around the hub
local blockConfigs = {}
-- Ring 1: Just outside hub
for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2
    table.insert(blockConfigs, {
        x = math.cos(angle) * 50, y = 4, z = math.sin(angle) * 50,
        color = BrickColor.new("Cyan"), size = 5,
    })
end
-- Ring 2
for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2 + 0.3
    table.insert(blockConfigs, {
        x = math.cos(angle) * 80, y = 6, z = math.sin(angle) * 80,
        color = BrickColor.new("Bright blue"), size = 5,
    })
end
-- Ring 3
for i = 1, 16 do
    local angle = (i / 16) * math.pi * 2 + 0.15
    table.insert(blockConfigs, {
        x = math.cos(angle) * 115, y = 8, z = math.sin(angle) * 115,
        color = BrickColor.new("Bright violet"), size = 6,
    })
end
-- Ring 4: Far out
for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    table.insert(blockConfigs, {
        x = math.cos(angle) * 160, y = 10, z = math.sin(angle) * 160,
        color = BrickColor.new("Bright yellow"), size = 7,
    })
end

local blockCount = 0
for _, bp in ipairs(blockConfigs) do
    local block = CreatePart({
        Name = "DataBlock_" .. blockCount,
        Size = Vector3.new(bp.size, bp.size, bp.size),
        Position = Vector3.new(bp.x, bp.y, bp.z),
        Color = bp.color,
        Material = Enum.Material.Neon,
        Parent = blockFolder,
    })
    -- Billboard
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 40)
    bb.StudsOffset = Vector3.new(0, bp.size * 0.8 + 2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = block
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "⛏️  +" .. BLOCK_REWARD .. " Data"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
    -- ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Data Block"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 14
    prompt.Parent = block
    blockCount = blockCount + 1
end

print("DataTycoon: " .. blockCount .. " collectible blocks created!")

-- ============================================================
-- PLAYER PLOTS (outer ring, pushed to edges for privacy)
-- ============================================================

local plotFolder = Instance.new("Folder")
plotFolder.Name = "PlotMarkers"
plotFolder.Parent = workspace

local PLOT_SIZE = 70
local PLOT_SPACING = 80  -- 70 plot + 10 road gap
local PLOT_RANGE = 3  -- 7x7 grid = 49 plots

-- Generate plot positions in outer ring (skip center area)
local plotPositions = {}
for x = -PLOT_RANGE, PLOT_RANGE do
    for z = -PLOT_RANGE, PLOT_RANGE do
        local dist = math.max(math.abs(x), math.abs(z))
        -- Only outer ring: skip the center 3x3 area
        if dist >= 2 then
            table.insert(plotPositions, {x = x, z = z, dist = dist})
        end
    end
end

-- Sort by distance (outer first for visual layering)
table.sort(plotPositions, function(a, b) return a.dist > b.dist end)

for _, pp in ipairs(plotPositions) do
    local x, z, dist = pp.x, pp.z, pp.dist
    local center = Vector3.new(x * PLOT_SPACING, 0.05, z * PLOT_SPACING)
    local price = math.floor(30 * (1.6 ^ dist))
    
    -- Plot ground
    local plotBase = CreatePart({
        Name = "Plot_" .. x .. "_" .. z,
        Size = Vector3.new(PLOT_SIZE - 4, 0.25, PLOT_SIZE - 4),
        Position = center,
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.1,
        Parent = plotFolder,
    })
    
    -- Color by ring
    if dist >= 3 then
        plotBase.BrickColor = BrickColor.new("Dark green")  -- Outer: peaceful green
    elseif dist == 2 then
        plotBase.BrickColor = BrickColor.new("Earth green")  -- Middle ring
    else
        plotBase.BrickColor = BrickColor.new("Forest green")
    end
    
    -- Corner posts
    local postH = 4 + dist * 0.5
    local postColor = dist >= 3 and BrickColor.new("Dark stone grey") or BrickColor.new("Medium stone grey")
    AddCorner(plotBase, PLOT_SIZE/2 - 2, PLOT_SIZE/2 - 2, postH, postColor)
    AddCorner(plotBase, -PLOT_SIZE/2 + 2, PLOT_SIZE/2 - 2, postH, postColor)
    AddCorner(plotBase, PLOT_SIZE/2 - 2, -PLOT_SIZE/2 + 2, postH, postColor)
    AddCorner(plotBase, -PLOT_SIZE/2 + 2, -PLOT_SIZE/2 + 2, postH, postColor)
    
    -- Fence along outer edges (privacy!)
    if dist >= 3 then
        -- Create low fence walls on outer-facing edges
        local fenceH = 3
        local fenceColor = BrickColor.new("Dark stone grey")
        local fenceTrans = 0.4
        local edge = PLOT_SIZE / 2
        local fenceThick = 0.8
        
        -- Check each edge: if it faces outward, add fence
        if math.abs(x) >= 3 then
            -- Left or right edge facing outward
            local fx = x > 0 and edge or -edge
            CreatePart({
                Name = "Fence",
                Size = Vector3.new(fenceThick, fenceH, PLOT_SIZE - 6),
                Position = Vector3.new(center.X + fx, fenceH/2, center.Z),
                Color = fenceColor,
                Material = Enum.Material.Wood,
                Transparency = fenceTrans,
                Parent = plotBase,
            })
        end
        if math.abs(z) >= 3 then
            local fz = z > 0 and edge or -edge
            CreatePart({
                Name = "Fence",
                Size = Vector3.new(PLOT_SIZE - 6, fenceH, fenceThick),
                Position = Vector3.new(center.X, fenceH/2, center.Z + fz),
                Color = fenceColor,
                Material = Enum.Material.Wood,
                Transparency = fenceTrans,
                Parent = plotBase,
            })
        end
    end
    
    -- Signpost
    local sign = CreatePart({
        Name = "Sign",
        Size = Vector3.new(0.8, 7, 0.8),
        Position = Vector3.new(center.X, 3.6, center.Z),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.15,
        Parent = plotBase,
    })
    
    -- Sign board
    local signBoard = CreatePart({
        Name = "SignBoard",
        Size = Vector3.new(8, 4, 0.3),
        Position = Vector3.new(center.X, 7.5, center.Z),
        Color = BrickColor.new("Medium stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.1,
        Parent = plotBase,
    })
    
    -- Billboard on sign
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 160, 0, 90)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = false
    bb.Parent = signBoard
    
    local coordLbl = Instance.new("TextLabel")
    coordLbl.Size = UDim2.new(1, 0, 0.25, 0)
    coordLbl.BackgroundTransparency = 1
    coordLbl.Text = "Plot (" .. x .. ", " .. z .. ")"
    coordLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    coordLbl.TextSize = 12
    coordLbl.Font = Enum.Font.GothamBold
    coordLbl.TextStrokeTransparency = 0.5
    coordLbl.Parent = bb
    
    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size = UDim2.new(1, 0, 0.35, 0)
    priceLbl.Position = UDim2.new(0, 0, 0.25, 0)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Text = "💰 " .. price .. " Data"
    priceLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    priceLbl.TextSize = 16
    priceLbl.Font = Enum.Font.GothamBold
    priceLbl.TextStrokeTransparency = 0.4
    priceLbl.Parent = bb
    
    local qualityLbl = Instance.new("TextLabel")
    qualityLbl.Size = UDim2.new(1, 0, 0.2, 0)
    qualityLbl.Position = UDim2.new(0, 0, 0.6, 0)
    qualityLbl.BackgroundTransparency = 1
    if dist >= 3 then
        qualityLbl.Text = "🌿 PRIVATE — Quiet Zone"
        qualityLbl.TextColor3 = Color3.fromRGB(100, 255, 150)
    elseif dist == 2 then
        qualityLbl.Text = "🏘️  Suburban — Good Value"
        qualityLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    else
        qualityLbl.Text = "⭐ Near Hub — Prime"
        qualityLbl.TextColor3 = Color3.fromRGB(255, 150, 255)
    end
    qualityLbl.TextSize = 10
    qualityLbl.Font = Enum.Font.GothamBold
    qualityLbl.TextStrokeTransparency = 0.5
    qualityLbl.Parent = bb
    
    -- Small decorative bushes on each plot
    AddBush(center.X + 15, center.Z + 15, 0.8)
    AddBush(center.X - 15, center.Z - 15, 0.6)
    
    -- Some plots get a tree
    if (x + z) % 3 == 0 then
        AddTree(center.X + 20, center.Z - 20, 0.7)
    end
end

print("DataTycoon: " .. #plotPositions .. " player plots created!")

-- ============================================================
-- ROADS (connecting everything)
-- ============================================================

local roadFolder = Instance.new("Folder")
roadFolder.Name = "Roads"
roadFolder.Parent = workspace

local ROAD_WIDTH = 10
local roadColor = BrickColor.new("Dark stone grey")
local roadMat = Enum.Material.Asphalt

-- Main roads through the center
local mainRoadH = CreatePart({
    Name = "MainRoad_H",
    Size = Vector3.new(512, 0.15, ROAD_WIDTH * 2),
    Position = Vector3.new(0, 0.08, 0),
    Color = roadColor,
    Material = roadMat,
    Transparency = 0.05,
    Parent = roadFolder,
})
local mainRoadV = CreatePart({
    Name = "MainRoad_V",
    Size = Vector3.new(ROAD_WIDTH * 2, 0.15, 512),
    Position = Vector3.new(0, 0.08, 0),
    Color = roadColor,
    Material = roadMat,
    Transparency = 0.05,
    Parent = roadFolder,
})

-- Ring roads at different distances
for _, radius in ipairs({120, 200, 280}) do
    local ringSegments = radius <= 120 and 16 or 24
    for i = 1, ringSegments do
        local angle = (i / ringSegments) * math.pi * 2
        local nextAngle = ((i + 1) / ringSegments) * math.pi * 2
        local midAngle = (angle + nextAngle) / 2
        local segLen = 2 * math.pi * radius / ringSegments + 2
        CreatePart({
            Name = "RingRoad_" .. radius .. "_" .. i,
            Size = Vector3.new(segLen, 0.12, ROAD_WIDTH),
            Position = Vector3.new(math.cos(midAngle) * radius, 0.06, math.sin(midAngle) * radius),
            Color = roadColor,
            Material = roadMat,
            Transparency = 0.05,
            Rotation = math.deg(-midAngle),
            Parent = roadFolder,
        })
    end
end

-- Road markings (yellow center lines)
for _, z in ipairs({-280, -200, -120, 0, 120, 200, 280}) do
    if math.abs(z) > 50 then  -- Skip center area (hub is there)
        for x = -240, 240, 20 do
            CreatePart({
                Name = "RoadMark",
                Size = Vector3.new(8, 0.02, 0.5),
                Position = Vector3.new(x, 0.1, z),
                Color = BrickColor.new("Bright yellow"),
                Material = Enum.Material.SmoothPlastic,
                Transparency = 0.3,
                Parent = roadFolder,
            })
        end
    end
end

print("DataTycoon: Roads created!")

-- ============================================================
-- LAMPS (along roads)
-- ============================================================

local lampFolder = Instance.new("Folder")
lampFolder.Name = "Lamps"
lampFolder.Parent = workspace

-- Lamps along main roads
for _, offset in ipairs({-240, -180, -120, 120, 180, 240}) do
    AddLamp(offset, 8)
    AddLamp(offset, -8)
    AddLamp(8, offset)
    AddLamp(-8, offset)
end

-- Lamps along ring roads
for _, radius in ipairs({120, 200, 280}) do
    local count = radius <= 120 and 8 or 12
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local x = math.cos(angle) * (radius + 6)
        local z = math.sin(angle) * (radius + 6)
        AddLamp(x, z)
    end
end

print("DataTycoon: Lamps created!")

-- ============================================================
-- TREES & NATURE (abundant)
-- ============================================================

local natureFolder = Instance.new("Folder")
natureFolder.Name = "Nature"
natureFolder.Parent = workspace

-- Forest clusters at the corners
local forestCenters = {
    {-200, -200}, {200, -200}, {-200, 200}, {200, 200},
    {-220, 0}, {220, 0}, {0, -220}, {0, 220},
}
for _, fc in ipairs(forestCenters) do
    for i = 1, 6 do
        local ox = math.random(-30, 30)
        local oz = math.random(-30, 30)
        AddTree(fc[1] + ox, fc[2] + oz, 0.8 + math.random() * 0.6)
    end
end

-- Trees along roads
for _, offset in ipairs({-260, -220, -160, 160, 220, 260}) do
    for i = 1, 4 do
        local perp = (i - 2.5) * 30
        AddTree(offset, perp + math.random(-5, 5), 0.7 + math.random() * 0.4)
        AddTree(perp + math.random(-5, 5), offset, 0.7 + math.random() * 0.4)
    end
end

-- Random trees scattered
for i = 1, 40 do
    local x = math.random(-230, 230)
    local z = math.random(-230, 230)
    -- Don't place too close to center (hub area)
    if math.abs(x) > 60 or math.abs(z) > 60 then
        AddTree(x, z, 0.5 + math.random() * 0.8)
    end
end

-- Bushes everywhere
for i = 1, 60 do
    local x = math.random(-240, 240)
    local z = math.random(-240, 240)
    if math.abs(x) > 50 or math.abs(z) > 50 then
        AddBush(x, z, 0.5 + math.random() * 0.8)
    end
end

-- Flowers
for i = 1, 80 do
    local x = math.random(-240, 240)
    local z = math.random(-240, 240)
    if math.abs(x) > 45 or math.abs(z) > 45 then
        AddFlower(x, z)
    end
end

-- Rocks
for i = 1, 25 do
    local x = math.random(-230, 230)
    local z = math.random(-230, 230)
    if math.abs(x) > 55 or math.abs(z) > 55 then
        AddRock(x, z, 0.5 + math.random() * 1.5)
    end
end

print("DataTycoon: Nature created!")

-- ============================================================
-- BENCHES & SEATING
-- ============================================================

local benchFolder = Instance.new("Folder")
benchFolder.Name = "Benches"
benchFolder.Parent = workspace

-- Benches along roads
for _, offset in ipairs({-200, -120, 120, 200}) do
    AddBench(offset + 15, 15, 0)
    AddBench(offset + 15, -15, 0)
    AddBench(15, offset + 15, 90)
    AddBench(-15, offset + 15, 90)
end

-- Benches near hub
for i = 1, 4 do
    local angle = (i / 4) * math.pi * 2 + math.pi / 4
    local x = math.cos(angle) * 48
    local z = math.sin(angle) * 48
    AddBench(x, z, math.deg(-angle) + 90)
end

print("DataTycoon: Benches created!")

-- ============================================================
-- WATER FEATURES
-- ============================================================

local waterFolder = Instance.new("Folder")
waterFolder.Name = "Water"
waterFolder.Parent = workspace

-- Small pond near the hub
local pond = CreatePart({
    Name = "Pond",
    Size = Vector3.new(30, 0.5, 20),
    Position = Vector3.new(55, 0.1, 55),
    Color = BrickColor.new("Bright blue"),
    Material = Enum.Material.Glass,
    Transparency = 0.5,
    Shape = Enum.PartType.Cylinder,
    Parent = waterFolder,
})
pond.CFrame = CFrame.new(55, 0.1, 55) * CFrame.Angles(0, 0, math.rad(90))

-- Pond edges (rocks)
for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    AddRock(55 + math.cos(angle) * 16, 55 + math.sin(angle) * 11, 0.4 + math.random() * 0.4)
end

-- Stream from pond
for i = 1, 8 do
    CreatePart({
        Name = "Stream",
        Size = Vector3.new(4, 0.3, 4),
        Position = Vector3.new(55 + i * 6, 0.05, 55 + i * 4),
        Color = BrickColor.new("Bright blue"),
        Material = Enum.Material.Glass,
        Transparency = 0.5,
        Parent = waterFolder,
    })
end

print("DataTycoon: Water features created!")

-- ============================================================
-- BUILDINGS (decorative, around the hub)
-- ============================================================

local buildingFolder = Instance.new("Folder")
buildingFolder.Name = "Buildings"
buildingFolder.Parent = workspace

-- Small shops/buildings around the hub
local buildingPositions = {
    {60, -60, "Data Store"}, {-60, 60, "Tech Shop"},
    {-60, -60, "Server Farm"}, {60, 60, "Mining Co"},
}
for _, bp in ipairs(buildingPositions) do
    local bx, bz, bname = bp[1], bp[2], bp[3]
    -- Building base
    CreatePart({
        Name = "Building_" .. bname,
        Size = Vector3.new(16, 12, 16),
        Position = Vector3.new(bx, 6, bz),
        Color = BrickColor.new("Medium stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.05,
        Parent = buildingFolder,
    })
    -- Roof
    CreatePart({
        Name = "Roof_" .. bname,
        Size = Vector3.new(18, 1, 18),
        Position = Vector3.new(bx, 12.5, bz),
        Color = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.SmoothPlastic,
        Parent = buildingFolder,
    })
    -- Sign
    local signBb = CreatePart({
        Name = "BuildingSign_" .. bname,
        Size = Vector3.new(12, 2, 0.3),
        Position = Vector3.new(bx, 10, bz + 8.2),
        Color = BrickColor.new("Bright blue"),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0.2,
        Parent = buildingFolder,
    })
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 30)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = signBb
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🏪 " .. bname
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
end

print("DataTycoon: Buildings created!")

-- ============================================================
-- WORKSPACE SETTINGS
-- ============================================================

workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

-- Atmosphere
local lighting = game:GetService("Lighting")
lighting.Ambient = Color3.fromRGB(100, 100, 120)
lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
lighting.Brightness = 2
lighting.ClockTime = 14
lighting.FogEnd = 500
lighting.FogColor = Color3.fromRGB(180, 200, 220)

print("DataTycoon: World complete! Hub + blocks + plots + roads + nature + water + buildings!")
