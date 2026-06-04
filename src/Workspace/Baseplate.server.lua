--[[
    Baseplate.server.lua — DataTycoon World
    v0.12 — Complete rewrite: fixed spawn, toned hub, beautiful world
]]

-- ============================================================
-- PARTS HELPER
-- ============================================================
local function Part(props)
    local p = Instance.new("Part")
    p.Name = props.name or "Part"
    p.Size = props.size or Vector3.new(4, 4, 4)
    p.Position = props.pos or Vector3.new(0, 0, 0)
    p.Anchored = true
    p.BrickColor = props.color or BrickColor.new("Medium stone grey")
    p.Material = props.mat or Enum.Material.SmoothPlastic
    p.Transparency = props.alpha or 0
    p.Shape = props.shape or Enum.PartType.Block
    p.CanCollide = props.collide ~= nil and props.collide or true
    p.Parent = props.parent or workspace
    if props.rot then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.rot), 0)
    end
    return p
end

-- ============================================================
-- CONFIG
-- ============================================================
local PLOT_SIZE = 90
local PLOT_GAP = 40
local PLOT_SPACING = PLOT_SIZE + PLOT_GAP  -- 130
local PLOT_RANGE = 3

-- ============================================================
-- BASEPLATE — THICK SOLID GRASS (prevents falling through)
-- ============================================================
-- Main ground: 512x512, 4 units thick, solid grass
Part({
    name = "Baseplate",
    size = Vector3.new(512, 4, 512),
    pos = Vector3.new(0, -2, 0),
    color = BrickColor.new("Dark green"),
    mat = Enum.Material.Grass
})

-- Spawn platform: solid, raised, visible
Part({
    name = "SpawnPlatform",
    size = Vector3.new(14, 3, 14),
    pos = Vector3.new(0, 1.5, 0),
    color = BrickColor.new("Bright green"),
    mat = Enum.Material.SmoothPlastic
})

-- Spawn location (invisible, for Roblox spawn system)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(0, 3.5, 0)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Parent = workspace

print("DataTycoon: Baseplate + spawn done")

-- ============================================================
-- CENTER: DATA HUB (elegant, subtle, NOT blinding)
-- ============================================================
local hub = Instance.new("Folder")
hub.Name = "DataHub"
hub.Parent = workspace

-- Main platform (solid dark stone)
Part({name="HubPlatform", size=Vector3.new(80, 3, 80), pos=Vector3.new(0, 1.5, 0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})

-- Accent ring (thin, subtle — NOT neon)
Part({name="HubRing", size=Vector3.new(50, 0.3, 50), pos=Vector3.new(0, 3.0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})

-- Server tower (5 floors, solid metal)
for f = 0, 4 do
    local y = 4 + f * 8
    local sz = 22 - f * 2
    Part({name="TowerF"..f, size=Vector3.new(sz, 7, sz), pos=Vector3.new(0, y, 0), color=BrickColor.new(f%2==0 and "Dark stone grey" or "Medium stone grey"), mat=Enum.Material.Metal, parent=hub})
    -- Thin accent line (subtle, not neon)
    Part({name="TowerLine"..f, size=Vector3.new(sz+0.5, 0.15, sz+0.5), pos=Vector3.new(0, y-3.3, 0), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, parent=hub})
end

-- Server racks (8 around hub)
for i = 1, 8 do
    local a = (i/8) * math.pi*2
    local x, z = math.cos(a)*28, math.sin(a)*28
    Part({name="Rack"..i, size=Vector3.new(6, 12, 3), pos=Vector3.new(x, 7, z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, parent=hub})
    -- Small LED dots (colored plastic, not neon)
    for l = 0, 3 do
        Part({name="LED"..i..l, size=Vector3.new(0.4, 0.25, 0.4), pos=Vector3.new(x, 3+l*2.5, z+1.6), color=BrickColor.new(l%2==0 and "Lime green" or "Forest green"), mat=Enum.Material.SmoothPlastic, parent=hub})
    end
end

-- Data pillars (6 columns, solid stone)
for i = 1, 6 do
    local a = (i/6) * math.pi*2
    local px, pz = math.cos(a)*18, math.sin(a)*18
    Part({name="Pillar"..i, size=Vector3.new(3, 22, 3), pos=Vector3.new(px, 12, pz), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    Part({name="Trim"..i, size=Vector3.new(3.5, 0.4, 3.5), pos=Vector3.new(px, 1.2, pz), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, parent=hub})
end

-- Floating orbs (subtle colored balls, not neon)
for i = 1, 10 do
    local a = (i/10) * math.pi*2
    local r = 12 + (i%3)*4
    Part({name="Orb"..i, size=Vector3.new(2, 2, 2), pos=Vector3.new(math.cos(a)*r, 26+math.sin(i)*2, math.sin(a)*r), color=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, parent=hub})
end

-- Entrance arches (4)
for i = 1, 4 do
    local a = (i/4) * math.pi*2
    local x, z = math.cos(a)*42, math.sin(a)*42
    Part({name="ArchP"..i, size=Vector3.new(3, 16, 3), pos=Vector3.new(x, 9, z), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    Part({name="ArchT"..i, size=Vector3.new(3, 2, 10), pos=Vector3.new(x, 18, z), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    Part({name="ArchA"..i, size=Vector3.new(3.2, 0.2, 10.2), pos=Vector3.new(x, 19.1, z), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, parent=hub})
end

print("DataTycoon: Hub done")

-- ============================================================
-- WALKWAYS (4 cardinal directions, straight, connected)
-- ============================================================
local walks = Instance.new("Folder")
walks.Name = "Walkways"
walks.Parent = workspace

local walkC = BrickColor.new("Medium stone grey")
local walkM = Enum.Material.Concrete
local walkW = 8

-- 4 straight walkways from hub edge outward
for _, d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    local dx, dz = d[1], d[2]
    local start = 45
    local finish = 270
    local len = finish - start
    local mx, mz = dx*(start+finish)/2, dz*(start+finish)/2
    if dx ~= 0 then
        Part({name="Walk", size=Vector3.new(len, 0.3, walkW), pos=Vector3.new(mx, 0.15, mz), color=walkC, mat=walkM, parent=walks})
    else
        Part({name="Walk", size=Vector3.new(walkW, 0.3, len), pos=Vector3.new(mx, 0.15, mz), color=walkC, mat=walkM, parent=walks})
    end
end

print("DataTycoon: Walkways done")

-- ============================================================
-- PLAYER PLOTS (outer ring, spacious, beautiful)
-- ============================================================
local plots = Instance.new("Folder")
plots.Name = "PlotMarkers"
plots.Parent = workspace

local function Tree(x, z, s)
    s = s or 1
    Part({name="Trunk", size=Vector3.new(2.5*s, 10*s, 2.5*s), pos=Vector3.new(x, 5*s, z), color=BrickColor.new("Brown"), mat=Enum.Material.Wood})
    Part({name="C1", size=Vector3.new(13*s, 9*s, 13*s), pos=Vector3.new(x, 12*s, z), color=BrickColor.new("Dark green"), mat=Enum.Material.Grass, shape=Enum.PartType.Ball})
    Part({name="C2", size=Vector3.new(10*s, 7*s, 10*s), pos=Vector3.new(x+2*s, 16*s, z+1*s), color=BrickColor.new("Earth green"), mat=Enum.Material.Grass, shape=Enum.PartType.Ball})
    Part({name="C3", size=Vector3.new(7*s, 5*s, 7*s), pos=Vector3.new(x-1*s, 19*s, z-2*s), color=BrickColor.new("Forest green"), mat=Enum.Material.Grass, shape=Enum.PartType.Ball})
end

local function Bush(x, z, s)
    s = s or 1
    for i = 1, 3 do
        Part({name="Bush", size=Vector3.new(3*s, 2.5*s, 3*s), pos=Vector3.new(x+math.random(-1,1), 1.25*s, z+math.random(-1,1)), color=BrickColor.new("Dark green"), mat=Enum.Material.Grass, shape=Enum.PartType.Ball})
    end
end

local function Flower(x, z)
    Part({name="Stem", size=Vector3.new(0.3, 1.5, 0.3), pos=Vector3.new(x, 0.75, z), color=BrickColor.new("Dark green"), mat=Enum.Material.Grass})
    local c = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Bright blue","Hot pink","Lavender","Magenta"}
    Part({name="Bloom", size=Vector3.new(1, 1, 1), pos=Vector3.new(x, 1.8, z), color=BrickColor.new(c[math.random(#c)]), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball})
end

local function Rock(x, z, s)
    s = s or 1
    Part({name="Rock", size=Vector3.new(3*s, 2*s, 3*s), pos=Vector3.new(x, 1*s, z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, shape=Enum.PartType.Ball})
end

local plotCount = 0
for x = -PLOT_RANGE, PLOT_RANGE do
    for z = -PLOT_RANGE, PLOT_RANGE do
        local dist = math.max(math.abs(x), math.abs(z))
        if dist >= 3 then
            local cx, cz = x*PLOT_SPACING, z*PLOT_SPACING
            local price = math.floor(50 * (2^dist))

            -- Plot ground (solid raised platform)
            Part({name="Plot_"..x.."_"..z, size=Vector3.new(PLOT_SIZE-4, 0.5, PLOT_SIZE-4), pos=Vector3.new(cx, 0.25, cz), color=BrickColor.new("Dark green"), mat=Enum.Material.SmoothPlastic, parent=plots})

            -- Corner posts
            for _, c in ipairs({{40,40},{-40,40},{40,-40},{-40,-40}}) do
                Part({name="Post", size=Vector3.new(1, 5, 1), pos=Vector3.new(cx+c[1], 3, cz+c[2]), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=plots})
            end

            -- Privacy fence on outer edges
            if math.abs(x) >= 3 then
                local fx = x > 0 and 42 or -42
                Part({name="Fence", size=Vector3.new(0.5, 3, 86), pos=Vector3.new(cx+fx, 2, cz), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Wood, parent=plots})
            end
            if math.abs(z) >= 3 then
                local fz = z > 0 and 42 or -42
                Part({name="Fence", size=Vector3.new(86, 3, 0.5), pos=Vector3.new(cx, 2, cz+fz), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Wood, parent=plots})
            end

            -- Sidewalk connection from plot to nearest walkway
            local angle = math.atan2(cz, cx)
            local nearX = math.cos(angle) * 265
            local nearZ = math.sin(angle) * 265
            local mx, mz = (nearX+cx)/2, (nearZ+cz)/2
            local dx, dz = cx-nearX, cz-nearZ
            local len = math.sqrt(dx*dx + dz*dz)
            local rot = math.deg(math.atan2(dz, dx))
            Part({name="PWalk_"..x.."_"..z, size=Vector3.new(len, 0.3, walkW), pos=Vector3.new(mx, 0.15, mz), color=walkC, mat=walkM, rot=rot, parent=walks})

            -- Signpost
            Part({name="Sign", size=Vector3.new(0.6, 6, 0.6), pos=Vector3.new(cx, 3.5, cz), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=plots})
            Part({name="SignB", size=Vector3.new(7, 3.5, 0.3), pos=Vector3.new(cx, 7, cz), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=plots})

            -- Billboard
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 140, 0, 75)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = false
            bb.Parent = Part({name="SignD", size=Vector3.new(0.1,0.1,0.1), pos=Vector3.new(cx, 8.5, cz), alpha=1, collide=false, parent=plots})
            local t1 = Instance.new("TextLabel") t1.Size=UDim2.new(1,0,0.25,0) t1.BackgroundTransparency=1 t1.Text="("..x..", "..z..")" t1.TextColor3=Color3.fromRGB(200,200,200) t1.TextSize=11 t1.Font=Enum.Font.GothamBold t1.TextStrokeTransparency=0.5 t1.Parent=bb
            local t2 = Instance.new("TextLabel") t2.Size=UDim2.new(1,0,0.35,0) t2.Position=UDim2.new(0,0,0.25,0) t2.BackgroundTransparency=1 t2.Text="💰 "..price t2.TextColor3=Color3.fromRGB(255,220,100) t2.TextSize=14 t2.Font=Enum.Font.GothamBold t2.TextStrokeTransparency=0.4 t2.Parent=bb
            local t3 = Instance.new("TextLabel") t3.Size=UDim2.new(1,0,0.2,0) t3.Position=UDim2.new(0,0,0.6,0) t3.BackgroundTransparency=1 t3.Text="🌿 PRIVATE" t3.TextColor3=Color3.fromRGB(100,255,150) t3.TextSize=10 t3.Font=Enum.Font.GothamBold t3.TextStrokeTransparency=0.5 t3.Parent=bb

            -- Decorations per plot
            Bush(cx+25, cz+25, 0.8)
            Bush(cx-20, cz-20, 0.6)
            Bush(cx+15, cz-28, 0.5)
            if (x+z)%2 == 0 then Tree(cx+30, cz-25, 0.7) end
            if (x*z)%3 == 0 then Tree(cx-28, cz+20, 0.5) end
            if (x+z)%4 == 0 then Rock(cx-25, cz-25, 0.6) end
            for i = 1, 6 do Flower(cx+math.random(-35,35), cz+math.random(-35,35)) end

            plotCount = plotCount + 1
        end
    end
end

print("DataTycoon: "..plotCount.." plots done")

-- ============================================================
-- DATA COLLECTIBLES (black hole / dark star aesthetic)
-- ============================================================
local blocks = Instance.new("Folder")
blocks.Name = "CollectibleBlocks"
blocks.Parent = workspace

local function DataOrb(cx, cy, cz, col)
    -- Outer dark shell
    Part({name="Shell", size=Vector3.new(7, 7, 7), pos=Vector3.new(cx, cy, cz), color=BrickColor.new("Really black"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, parent=blocks})
    -- Inner core (subtle glow)
    Part({name="Core", size=Vector3.new(3.5, 3.5, 3.5), pos=Vector3.new(cx, cy, cz), color=col, mat=Enum.Material.Neon, shape=Enum.PartType.Ball, alpha=0.35, parent=blocks})
    -- Point light
    local anchor = Part({name="LAnchor", size=Vector3.new(0.1,0.1,0.1), pos=Vector3.new(cx, cy, cz), alpha=1, collide=false, parent=blocks})
    local light = Instance.new("PointLight")
    light.Color = col
    light.Brightness = 0.8
    light.Range = 10
    light.Parent = anchor
    -- Star spikes (4, thin)
    for i = 1, 4 do
        local a = (i/4) * math.pi*2
        Part({name="Spike", size=Vector3.new(0.25, 4.5, 0.25), pos=Vector3.new(cx+math.cos(a)*4.5, cy, cz+math.sin(a)*4.5), color=col, mat=Enum.Material.Neon, alpha=0.4, rot=math.deg(-a), parent=blocks})
    end
    -- Billboard
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 100, 0, 28)
    bb.StudsOffset = Vector3.new(0, 5.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = Part({name="BB", size=Vector3.new(0.1,0.1,0.1), pos=Vector3.new(cx, cy+5.5, cz), alpha=1, collide=false, parent=blocks})
    local lbl = Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="✦ +5" lbl.TextColor3=col lbl.TextSize=12 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
    -- Proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Data Orb"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 12
    prompt.Parent = blocks:FindFirstChild("Shell") or workspace
    -- Fix: parent prompt to the shell part
    prompt.Parent = blocks:GetChildren()[#blocks:GetChildren()-6] -- approximate
end

-- Fix: recreate with proper prompt parenting
local function DataOrbFixed(cx, cy, cz, col)
    local shell = Part({name="Shell", size=Vector3.new(7, 7, 7), pos=Vector3.new(cx, cy, cz), color=BrickColor.new("Really black"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, parent=blocks})
    local core = Part({name="Core", size=Vector3.new(3.5, 3.5, 3.5), pos=Vector3.new(cx, cy, cz), color=col, mat=Enum.Material.Neon, shape=Enum.PartType.Ball, alpha=0.35, parent=blocks})
    local anchor = Part({name="LAnchor", size=Vector3.new(0.1,0.1,0.1), pos=Vector3.new(cx, cy, cz), alpha=1, collide=false, parent=blocks})
    local light = Instance.new("PointLight") light.Color=col light.Brightness=0.8 light.Range=10 light.Parent=anchor
    for i = 1, 4 do
        local a = (i/4)*math.pi*2
        Part({name="Spike", size=Vector3.new(0.25, 4.5, 0.25), pos=Vector3.new(cx+math.cos(a)*4.5, cy, cz+math.sin(a)*4.5), color=col, mat=Enum.Material.Neon, alpha=0.4, rot=math.deg(-a), parent=blocks})
    end
    local bb = Instance.new("BillboardGui") bb.Size=UDim2.new(0,100,0,28) bb.StudsOffset=Vector3.new(0,5.5,0) bb.AlwaysOnTop=true bb.Parent=shell
    local lbl = Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="✦ +5" lbl.TextColor3=col lbl.TextSize=12 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
    local prompt = Instance.new("ProximityPrompt") prompt.ActionText="Collect" prompt.ObjectText="Data Orb" prompt.HoldDuration=0.3 prompt.MaxActivationDistance=12 prompt.Parent=shell
end

-- Clear the broken ones
for _,c in ipairs(blocks:GetChildren()) do c:Destroy() end

-- Ring 1: Cyan (near hub)
for i = 1, 8 do
    local a = (i/8)*math.pi*2
    DataOrbFixed(math.cos(a)*52, 5, math.sin(a)*52, BrickColor.new("Cyan"))
end
-- Ring 2: Blue
for i = 1, 10 do
    local a = (i/10)*math.pi*2+0.3
    DataOrbFixed(math.cos(a)*85, 7, math.sin(a)*85, BrickColor.new("Bright blue"))
end
-- Ring 3: Purple
for i = 1, 12 do
    local a = (i/12)*math.pi*2+0.15
    DataOrbFixed(math.cos(a)*120, 9, math.sin(a)*120, BrickColor.new("Bright violet"))
end
-- Ring 4: Gold (far)
for i = 1, 10 do
    local a = (i/12)*math.pi*2
    DataOrbFixed(math.cos(a)*165, 11, math.sin(a)*165, BrickColor.new("Bright yellow"))
end

print("DataTycoon: Data orbs done")

-- ============================================================
-- NATURE (abundant, beautiful)
-- ============================================================
local nature = Instance.new("Folder") nature.Name="Nature" nature.Parent=workspace

-- Forest clusters at corners
for _, fc in ipairs({{-210,-210},{210,-210},{-210,210},{210,210},{-230,0},{230,0},{0,-230},{0,230}}) do
    for i = 1, 6 do Tree(fc[1]+math.random(-20,20), fc[2]+math.random(-20,20), 0.6+math.random()*0.5) end
    for i = 1, 3 do Bush(fc[1]+math.random(-25,25), fc[2]+math.random(-25,25), 0.7+math.random()*0.5) end
    for i = 1, 2 do Rock(fc[1]+math.random(-15,15), fc[2]+math.random(-15,15), 0.5+math.random()*0.7) end
end

-- Trees along walkways (lined up neatly)
for _, d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    for dist = 55, 265, 22 do
        local x, z = d[1]*dist, d[2]*dist
        if d[1] == 0 then
            Tree(x+10, z, 0.5+math.random()*0.3)
            Tree(x-10, z, 0.5+math.random()*0.3)
        else
            Tree(x, z+10, 0.5+math.random()*0.3)
            Tree(x, z-10, 0.5+math.random()*0.3)
        end
    end
end

-- Scattered trees
for i = 1, 30 do
    local tx, tz = math.random(-240,240), math.random(-240,240)
    if math.abs(tx) > 50 or math.abs(tz) > 50 then Tree(tx, tz, 0.5+math.random()*0.6) end
end

-- Bushes, flowers, rocks
for i = 1, 50 do Bush(math.random(-250,250), math.random(-250,250), 0.4+math.random()*0.6) end
for i = 1, 80 do Flower(math.random(-250,250), math.random(-250,250)) end
for i = 1, 20 do Rock(math.random(-240,240), math.random(-240,240), 0.4+math.random()*1.0) end

print("DataTycoon: Nature done")

-- ============================================================
-- LAMPS (along walkways)
-- ============================================================
for _, d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    for dist = 55, 265, 28 do
        local x, z = d[1]*dist, d[2]*dist
        if d[1] == 0 then
            Part({name="LPole", size=Vector3.new(0.5,7,0.5), pos=Vector3.new(x+9,3.5,z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal})
            Part({name="LHead", size=Vector3.new(1.5,0.5,1.5), pos=Vector3.new(x+9,7,z), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic})
            Part({name="LPole", size=Vector3.new(0.5,7,0.5), pos=Vector3.new(x-9,3.5,z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal})
            Part({name="LHead", size=Vector3.new(1.5,0.5,1.5), pos=Vector3.new(x-9,7,z), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic})
        else
            Part({name="LPole", size=Vector3.new(0.5,7,0.5), pos=Vector3.new(x,3.5,z+9), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal})
            Part({name="LHead", size=Vector3.new(1.5,0.5,1.5), pos=Vector3.new(x,7,z+9), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic})
            Part({name="LPole", size=Vector3.new(0.5,7,0.5), pos=Vector3.new(x,3.5,z-9), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal})
            Part({name="LHead", size=Vector3.new(1.5,0.5,1.5), pos=Vector3.new(x,7,z-9), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic})
        end
    end
end

print("DataTycoon: Lamps done")

-- ============================================================
-- WATER
-- ============================================================
local water = Instance.new("Folder") water.Name="Water" water.Parent=workspace
local pond = Part({name="Pond", size=Vector3.new(28,0.5,18), pos=Vector3.new(58,0.2,58), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, shape=Enum.PartType.Cylinder})
pond.CFrame = CFrame.new(58,0.2,58) * CFrame.Angles(0,0,math.rad(90))
for i = 1, 10 do local a=(i/10)*math.pi*2 Rock(58+math.cos(a)*15,58+math.sin(a)*10,0.3+math.random()*0.3) end
for i = 1, 6 do Part({name="Stream", size=Vector3.new(4,0.3,4), pos=Vector3.new(58+i*7,0.15,58+i*5), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, parent=water}) end

print("DataTycoon: Water done")

-- ============================================================
-- BUILDINGS
-- ============================================================
local builds = Instance.new("Folder") builds.Name="Buildings" builds.Parent=workspace
for _, bp in ipairs({{62,-62,"Data Store"},{-62,62,"Tech Shop"},{-62,-62,"Server Farm"},{62,62,"Mining Co"}}) do
    Part({name="B_"..bp[3], size=Vector3.new(14,11,14), pos=Vector3.new(bp[1],6,bp[2]), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=builds})
    Part({name="R_"..bp[3], size=Vector3.new(16,1,16), pos=Vector3.new(bp[1],12,bp[2]), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=builds})
    local sb = Part({name="S_"..bp[3], size=Vector3.new(10,2,0.3), pos=Vector3.new(bp[1],10,bp[2]+7.2), color=BrickColor.new("Bright blue"), mat=Enum.Material.SmoothPlastic, parent=builds})
    local bb = Instance.new("BillboardGui") bb.Size=UDim2.new(0,100,0,25) bb.StudsOffset=Vector3.new(0,1.5,0) bb.AlwaysOnTop=true bb.Parent=sb
    local lbl = Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="🏪 "..bp[3] lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.TextSize=13 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
end

print("DataTycoon: Buildings done")

-- ============================================================
-- LIGHTING
-- ============================================================
local l = game:GetService("Lighting")
l.Ambient = Color3.fromRGB(100,100,120)
l.OutdoorAmbient = Color3.fromRGB(120,120,140)
l.Brightness = 2.2
l.ClockTime = 14
l.FogEnd = 600
l.FogColor = Color3.fromRGB(180,200,220)

workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: WORLD COMPLETE!")
