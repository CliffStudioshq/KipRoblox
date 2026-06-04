--[[
    Baseplate.server.lua — DataTycoon World
    v0.9 — Fixed: solid hub, cohesive sidewalks, connected plots
]]

local function Part(props)
    local p = Instance.new("Part")
    p.Name = props.Name or "Part"
    p.Size = props.Size or Vector3.new(4, 4, 4)
    p.Position = props.Position or Vector3.new(0, 0, 0)
    p.Anchored = true
    p.BrickColor = props.Color or BrickColor.new("Medium stone grey")
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.Transparency = props.Transparency or 0
    p.Shape = props.Shape or Enum.PartType.Block
    p.CanCollide = props.CanCollide ~= nil and props.CanCollide or true
    p.Parent = props.Parent or workspace
    if props.Rotation then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.Rotation), 0)
    end
    return p
end

local function Tree(x, z, s)
    s = s or 1
    Part({Name="Trunk", Size=Vector3.new(2.5*s,10*s,2.5*s), Position=Vector3.new(x,5*s,z), Color=BrickColor.new("Brown"), Material=Enum.Material.Wood})
    Part({Name="Canopy1", Size=Vector3.new(12*s,8*s,12*s), Position=Vector3.new(x,12*s,z), Color=BrickColor.new("Dark green"), Material=Enum.Material.Grass, Shape=Enum.PartType.Ball})
    Part({Name="Canopy2", Size=Vector3.new(9*s,7*s,9*s), Position=Vector3.new(x+2*s,15*s,z+1*s), Color=BrickColor.new("Earth green"), Material=Enum.Material.Grass, Shape=Enum.PartType.Ball})
end

local function Lamp(x, z)
    Part({Name="LampPole", Size=Vector3.new(0.8,10,0.8), Position=Vector3.new(x,5,z), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.Metal})
    Part({Name="LampHead", Size=Vector3.new(2.5,1,2.5), Position=Vector3.new(x,10.5,z), Color=BrickColor.new("Institutional white"), Material=Enum.Material.Neon})
    local l = Instance.new("PointLight")
    l.Color = Color3.fromRGB(255,240,200)
    l.Brightness = 2
    l.Range = 28
    l.Parent = workspace
    -- Attach light to lamp via attachment
    local a = Instance.new("Attachment")
    a.Position = Vector3.new(x, 10.5, z)
    -- We'll just put the light in the part above
    l.Parent = workspace
end

local function Bush(x, z, s)
    s = s or 1
    for i=1,3 do
        Part({Name="Bush", Size=Vector3.new(3*s,2.5*s,3*s), Position=Vector3.new(x+math.random(-1,1),1.25*s,z+math.random(-1,1)), Color=BrickColor.new("Dark green"), Material=Enum.Material.Grass, Shape=Enum.PartType.Ball})
    end
end

local function Flower(x, z)
    Part({Name="FlowerStem", Size=Vector3.new(0.3,1.5,0.3), Position=Vector3.new(x,0.75,z), Color=BrickColor.new("Dark green"), Material=Enum.Material.Grass})
    local colors = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan"}
    Part({Name="FlowerBloom", Size=Vector3.new(1,1,1), Position=Vector3.new(x,1.8,z), Color=BrickColor.new(colors[math.random(#colors)]), Material=Enum.Material.SmoothPlastic, Shape=Enum.PartType.Ball})
end

local function Rock(x, z, s)
    s = s or 1
    Part({Name="Rock", Size=Vector3.new(3*s,2*s,3*s), Position=Vector3.new(x,1*s,z), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.Slate, Shape=Enum.PartType.Ball})
end

-- ============================================================
-- CONFIG
-- ============================================================
local PLOT_SIZE = 80
local PLOT_GAP = 30
local PLOT_SPACING = PLOT_SIZE + PLOT_GAP  -- 110
local PLOT_RANGE = 3
local SIDEWALK_W = 6  -- Width of sidewalks connecting everything

-- ============================================================
-- BASEPLATE (solid grass, covers everything)
-- ============================================================
Part({Name="Baseplate", Size=Vector3.new(512,2,512), Position=Vector3.new(0,-1,0), Color=BrickColor.new("Dark green"), Material=Enum.Material.Grass})

-- Spawn platform (solid)
Part({Name="Spawn", Size=Vector3.new(10,2,10), Position=Vector3.new(0,1,0), Color=BrickColor.new("Bright green"), Material=Enum.Material.SmoothPlastic})

-- ============================================================
-- CENTER: DATA HARVESTING HUB (ALL SOLID)
-- ============================================================
local hub = Instance.new("Folder")
hub.Name = "DataHub"
hub.Parent = workspace

-- Main platform (solid dark stone)
Part({Name="HubPlatform", Size=Vector3.new(80,3,80), Position=Vector3.new(0,1.5,0), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.SmoothPlastic, Parent=hub})

-- Glow ring on top (solid neon)
Part({Name="HubRing", Size=Vector3.new(50,0.6,50), Position=Vector3.new(0,3.1,0), Color=BrickColor.new("Cyan"), Material=Enum.Material.Neon, Parent=hub})

-- Server tower (5 floors, all solid)
for floor=0,4 do
    local y = 4 + floor * 8
    local sz = 22 - floor * 2
    Part({Name="TowerF"..floor, Size=Vector3.new(sz,7,sz), Position=Vector3.new(0,y,0), Color=BrickColor.new(floor%2==0 and "Dark stone grey" or "Medium stone grey"), Material=Enum.Material.Metal, Parent=hub})
    -- Glow strip (solid)
    Part({Name="TowerGlow"..floor, Size=Vector3.new(sz+1,0.4,sz+1), Position=Vector3.new(0,y-3.2,0), Color=BrickColor.new("Cyan"), Material=Enum.Material.Neon, Parent=hub})
end

-- Server racks (8 around hub, solid)
for i=1,8 do
    local a = (i/8)*math.pi*2
    local x,z = math.cos(a)*28, math.sin(a)*28
    Part({Name="Rack"..i, Size=Vector3.new(6,12,3), Position=Vector3.new(x,7,z), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.Metal, Parent=hub})
    for light=0,3 do
        Part({Name="RackLight"..i.."_"..light, Size=Vector3.new(0.8,0.4,0.8), Position=Vector3.new(x,3+light*2.5,z+1.6), Color=BrickColor.new(light%2==0 and "Lime green" or "Bright green"), Material=Enum.Material.Neon, Parent=hub})
    end
end

-- Data pillars (6 tall columns, solid)
for i=1,6 do
    local a = (i/6)*math.pi*2
    Part({Name="DataPillar"..i, Size=Vector3.new(2,22,2), Position=Vector3.new(math.cos(a)*18,12,math.sin(a)*18), Color=BrickColor.new("Cyan"), Material=Enum.Material.Neon, Parent=hub})
end

-- Floating orbs (solid)
for i=1,12 do
    local a = (i/12)*math.pi*2
    local r = 10 + (i%3)*5
    Part({Name="Orb"..i, Size=Vector3.new(2.5,2.5,2.5), Position=Vector3.new(math.cos(a)*r,26+math.sin(i)*3,math.sin(a)*r), Color=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"), Material=Enum.Material.Neon, Shape=Enum.PartType.Ball, Parent=hub})
end

-- Entrance arches (4, solid)
for i=1,4 do
    local a = (i/4)*math.pi*2
    local x,z = math.cos(a)*42, math.sin(a)*42
    Part({Name="ArchPillar"..i, Size=Vector3.new(3,16,3), Position=Vector3.new(x,9,z), Color=BrickColor.new("Medium stone grey"), Material=Enum.Material.Metal, Parent=hub})
    Part({Name="ArchTop"..i, Size=Vector3.new(3,2,10), Position=Vector3.new(x,18,z), Color=BrickColor.new("Cyan"), Material=Enum.Material.Neon, Parent=hub})
end

print("DataTycoon: Hub done (all solid)")

-- ============================================================
-- ROAD SYSTEM (cohesive, connected)
-- ============================================================
local roads = Instance.new("Folder")
roads.Name = "Roads"
roads.Parent = workspace

local roadColor = BrickColor.new("Dark stone grey")
local roadMat = Enum.Material.Asphalt
local sidewalkColor = BrickColor.new("Medium stone grey")
local sidewalkMat = Enum.Material.Concrete

-- Main cross roads (through center, wide)
Part({Name="RoadH", Size=Vector3.new(512,0.3,20), Position=Vector3.new(0,0.15,0), Color=roadColor, Material=roadMat, Parent=roads})
Part({Name="RoadV", Size=Vector3.new(20,0.3,512), Position=Vector3.new(0,0.15,0), Color=roadColor, Material=roadMat, Parent=roads})

-- Ring roads at 3 distances
for _,radius in ipairs({120,200,280}) do
    local segments = radius <= 120 and 16 or 24
    for i=1,segments do
        local angle = (i/segments)*math.pi*2
        local nextAngle = ((i+1)/segments)*math.pi*2
        local midAngle = (angle+nextAngle)/2
        local segLen = 2*math.pi*radius/segments + 4
        Part({Name="RingRoad_"..radius.."_"..i, Size=Vector3.new(segLen,0.25,14), Position=Vector3.new(math.cos(midAngle)*radius,0.12,math.sin(midAngle)*radius), Color=roadColor, Material=roadMat, Rotation=math.deg(-midAngle), Parent=roads})
    end
end

-- Sidewalks along main roads (both sides)
for _,offset in ipairs({14,-14}) do
    Part({Name="SidewalkH_"..offset, Size=Vector3.new(512,0.4,SIDEWALK_W), Position=Vector3.new(0,0.2,offset), Color=sidewalkColor, Material=sidewalkMat, Parent=roads})
    Part({Name="SidewalkV_"..offset, Size=Vector3.new(SIDEWALK_W,0.4,512), Position=Vector3.new(offset,0.2,0), Color=sidewalkColor, Material=sidewalkMat, Parent=roads})
end

-- Sidewalks along ring roads (outer side)
for _,radius in ipairs({120,200,280}) do
    local segments = radius <= 120 and 16 or 24
    for i=1,segments do
        local angle = (i/segments)*math.pi*2
        local nextAngle = ((i+1)/segments)*math.pi*2
        local midAngle = (angle+nextAngle)/2
        local segLen = 2*math.pi*radius/segments + 4
        local r = radius + 10
        Part({Name="RingSidewalk_"..radius.."_"..i, Size=Vector3.new(segLen,0.35,SIDEWALK_W), Position=Vector3.new(math.cos(midAngle)*r,0.18,math.sin(midAngle)*r), Color=sidewalkColor, Material=sidewalkMat, Rotation=math.deg(-midAngle), Parent=roads})
    end
end

print("DataTycoon: Roads + sidewalks done")

-- ============================================================
-- PLAYER PLOTS (outer ring only, connected by sidewalks)
-- ============================================================
local plots = Instance.new("Folder")
plots.Name = "PlotMarkers"
plots.Parent = workspace

local plotCount = 0
for x=-PLOT_RANGE,PLOT_RANGE do
    for z=-PLOT_RANGE,PLOT_RANGE do
        local dist = math.max(math.abs(x),math.abs(z))
        if dist >= 3 then
            local cx, cz = x*PLOT_SPACING, z*PLOT_SPACING
            local price = math.floor(40 * (1.8^dist))
            
            -- Plot ground (solid, raised slightly)
            local plot = Part({Name="Plot_"..x.."_"..z, Size=Vector3.new(PLOT_SIZE-4,0.5,PLOT_SIZE-4), Position=Vector3.new(cx,0.25,cz), Material=Enum.Material.SmoothPlastic, Transparency=0, Parent=plots})
            plot.BrickColor = BrickColor.new(dist>=3 and "Dark green" or "Forest green")
            
            -- Corner posts (solid)
            local postH = 5
            for _,c in ipairs({{PLOT_SIZE/2-2,PLOT_SIZE/2-2},{-PLOT_SIZE/2+2,PLOT_SIZE/2-2},{PLOT_SIZE/2-2,-PLOT_SIZE/2+2},{-PLOT_SIZE/2+2,-PLOT_SIZE/2+2}}) do
                Part({Name="Post", Size=Vector3.new(1.2,postH,1.2), Position=Vector3.new(cx+c[1],postH/2+0.5,cz+c[2]), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.SmoothPlastic, Parent=plot})
                Part({Name="PostBall", Size=Vector3.new(1.8,1.8,1.8), Position=Vector3.new(cx+c[1],postH+0.9,cz+c[2]), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.SmoothPlastic, Shape=Enum.PartType.Ball, Parent=plot})
            end
            
            -- Privacy fence on outer edges
            local edge = PLOT_SIZE/2
            if math.abs(x) >= 3 then
                local fx = x > 0 and edge or -edge
                Part({Name="Fence", Size=Vector3.new(0.8,3,PLOT_SIZE-6), Position=Vector3.new(cx+fx,2,cz), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.Wood, Parent=plot})
            end
            if math.abs(z) >= 3 then
                local fz = z > 0 and edge or -edge
                Part({Name="Fence", Size=Vector3.new(PLOT_SIZE-6,3,0.8), Position=Vector3.new(cx,2,cz+fz), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.Wood, Parent=plot})
            end
            
            -- === SIDEWALK CONNECTION from nearest road to this plot ===
            -- Find the nearest point on the ring road and connect
            local angle = math.atan2(z, x)
            local roadRadius = 280  -- Outer ring road
            local roadX = math.cos(angle) * roadRadius
            local roadZ = math.sin(angle) * roadRadius
            
            -- Create a sidewalk strip from road to plot
            local midX = (roadX + cx) / 2
            local midZ = (roadZ + cz) / 2
            local dx, dz = cx-roadX, cz-roadZ
            local len = math.sqrt(dx*dx + dz*dz)
            local rot = math.deg(math.atan2(dz, dx))
            
            Part({Name="PlotWalk_"..x.."_"..z, Size=Vector3.new(len,0.35,SIDEWALK_W), Position=Vector3.new(midX,0.18,midZ), Color=sidewalkColor, Material=sidewalkMat, Rotation=rot, Parent=roads})
            
            -- Signpost
            Part({Name="Sign", Size=Vector3.new(0.8,7,0.8), Position=Vector3.new(cx,4,cz), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.SmoothPlastic, Parent=plot})
            Part({Name="SignBoard", Size=Vector3.new(8,4,0.3), Position=Vector3.new(cx,8,cz), Color=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic, Parent=plot})
            
            -- Billboard
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0,160,0,90)
            bb.StudsOffset = Vector3.new(0,3,0)
            bb.AlwaysOnTop = false
            bb.Parent = Part({Name="SignDummy", Size=Vector3.new(0.1,0.1,0.1), Position=Vector3.new(cx,10,cz), Transparency=1, Parent=plot})
            
            local l1 = Instance.new("TextLabel")
            l1.Size = UDim2.new(1,0,0.25,0) l1.BackgroundTransparency = 1
            l1.Text = "("..x..", "..z..")" l1.TextColor3 = Color3.fromRGB(220,220,220) l1.TextSize = 12 l1.Font = Enum.Font.GothamBold l1.TextStrokeTransparency = 0.5 l1.Parent = bb
            
            local l2 = Instance.new("TextLabel")
            l2.Size = UDim2.new(1,0,0.35,0) l2.Position = UDim2.new(0,0,0.25,0) l2.BackgroundTransparency = 1
            l2.Text = "💰 "..price.." Data" l2.TextColor3 = Color3.fromRGB(255,220,100) l2.TextSize = 16 l2.Font = Enum.Font.GothamBold l2.TextStrokeTransparency = 0.4 l2.Parent = bb
            
            local l3 = Instance.new("TextLabel")
            l3.Size = UDim2.new(1,0,0.2,0) l3.Position = UDim2.new(0,0,0.6,0) l3.BackgroundTransparency = 1
            l3.Text = "🌿 PRIVATE" l3.TextColor3 = Color3.fromRGB(100,255,150) l3.TextSize = 10 l3.Font = Enum.Font.GothamBold l3.TextStrokeTransparency = 0.5 l3.Parent = bb
            
            -- Decorations
            Bush(cx+20,cz+20,0.8)
            Bush(cx-20,cz-20,0.6)
            if (x+z)%2==0 then Tree(cx+25,cz-25,0.7) end
            
            plotCount = plotCount + 1
        end
    end
end

print("DataTycoon: "..plotCount.." plots done (with sidewalk connections)")

-- ============================================================
-- COLLECTIBLE BLOCKS (in the gaps between hub and plots)
-- ============================================================
local blocks = Instance.new("Folder")
blocks.Name = "CollectibleBlocks"
blocks.Parent = workspace

local blockConfigs = {}
for i=1,8 do local a=(i/8)*math.pi*2 table.insert(blockConfigs,{x=math.cos(a)*50,y=4,z=math.sin(a)*50,c=BrickColor.new("Cyan"),sz=5}) end
for i=1,12 do local a=(i/12)*math.pi*2+0.3 table.insert(blockConfigs,{x=math.cos(a)*80,y=6,z=math.sin(a)*80,c=BrickColor.new("Bright blue"),sz=5}) end
for i=1,16 do local a=(i/16)*math.pi*2+0.15 table.insert(blockConfigs,{x=math.cos(a)*115,y=8,z=math.sin(a)*115,c=BrickColor.new("Bright violet"),sz=6}) end
for i=1,12 do local a=(i/12)*math.pi*2 table.insert(blockConfigs,{x=math.cos(a)*160,y=10,z=math.sin(a)*160,c=BrickColor.new("Bright yellow"),sz=7}) end

local bCount = 0
for _,bp in ipairs(blockConfigs) do
    local b = Part({Name="Block_"..bCount, Size=Vector3.new(bp.sz,bp.sz,bp.sz), Position=Vector3.new(bp.x,bp.y,bp.z), Color=bp.c, Material=Enum.Material.Neon, Parent=blocks})
    local bb = Instance.new("BillboardGui") bb.Size = UDim2.new(0,120,0,40) bb.StudsOffset = Vector3.new(0,bp.sz*0.8+2,0) bb.AlwaysOnTop = true bb.Parent = b
    local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(1,0,1,0) lbl.BackgroundTransparency = 1 lbl.Text = "⛏️  +5 Data" lbl.TextColor3 = Color3.fromRGB(255,255,255) lbl.TextSize = 13 lbl.Font = Enum.Font.GothamBold lbl.TextStrokeTransparency = 0.3 lbl.Parent = bb
    local p = Instance.new("ProximityPrompt") p.ActionText = "Collect" p.ObjectText = "Data Block" p.HoldDuration = 0.3 p.MaxActivationDistance = 14 p.Parent = b
    bCount = bCount + 1
end

print("DataTycoon: "..bCount.." blocks done")

-- ============================================================
-- TREES & NATURE
-- ============================================================
local nature = Instance.new("Folder") nature.Name = "Nature" nature.Parent = workspace

-- Forest clusters at corners
for _,fc in ipairs({{-200,-200},{200,-200},{-200,200},{200,200},{-220,0},{220,0},{0,-220},{0,220}}) do
    for i=1,5 do Tree(fc[1]+math.random(-25,25), fc[2]+math.random(-25,25), 0.7+math.random()*0.5) end
end

-- Trees along roads
for _,off in ipairs({-260,-220,-160,160,220,260}) do
    for i=1,4 do Tree(off+math.random(-3,3),(i-2.5)*30+math.random(-3,3),0.6+math.random()*0.4) end
    for i=1,4 do Tree((i-2.5)*30+math.random(-3,3),off+math.random(-3,3),0.6+math.random()*0.4) end
end

-- Scattered trees
for i=1,30 do
    local tx,tz = math.random(-230,230),math.random(-230,230)
    if math.abs(tx)>55 or math.abs(tz)>55 then Tree(tx,tz,0.5+math.random()*0.7) end
end

-- Bushes
for i=1,50 do Bush(math.random(-240,240),math.random(-240,240),0.5+math.random()*0.7) end

-- Flowers
for i=1,60 do Flower(math.random(-240,240),math.random(-240,240)) end

-- Rocks
for i=1,20 do Rock(math.random(-230,230),math.random(-230,230),0.5+math.random()*1.2) end

print("DataTycoon: Nature done")

-- ============================================================
-- LAMPS (along sidewalks)
-- ============================================================
for _,off in ipairs({-240,-180,-120,120,180,240}) do
    Lamp(off, 14) Lamp(off, -14) Lamp(14, off) Lamp(-14, off)
end
for _,radius in ipairs({120,200,280}) do
    local count = radius<=120 and 8 or 12
    for i=1,count do
        local a = (i/count)*math.pi*2
        Lamp(math.cos(a)*(radius+14), math.sin(a)*(radius+14))
    end
end

print("DataTycoon: Lamps done")

-- ============================================================
-- WATER
-- ============================================================
local water = Instance.new("Folder") water.Name = "Water" water.Parent = workspace
local pond = Part({Name="Pond", Size=Vector3.new(30,0.6,20), Position=Vector3.new(55,0.2,55), Color=BrickColor.new("Bright blue"), Material=Enum.Material.Glass, Shape=Enum.PartType.Cylinder})
pond.CFrame = CFrame.new(55,0.2,55) * CFrame.Angles(0,0,math.rad(90))
for i=1,12 do local a=(i/12)*math.pi*2 Rock(55+math.cos(a)*16,55+math.sin(a)*11,0.4+math.random()*0.3) end
for i=1,8 do Part({Name="Stream", Size=Vector3.new(4,0.4,4), Position=Vector3.new(55+i*6,0.15,55+i*4), Color=BrickColor.new("Bright blue"), Material=Enum.Material.Glass, Parent=water}) end

print("DataTycoon: Water done")

-- ============================================================
-- BUILDINGS (around hub)
-- ============================================================
local builds = Instance.new("Folder") builds.Name = "Buildings" builds.Parent = workspace
for _,bp in ipairs({{60,-60,"Data Store"},{-60,60,"Tech Shop"},{-60,-60,"Server Farm"},{60,60,"Mining Co"}}) do
    Part({Name="Bldg_"..bp[3], Size=Vector3.new(16,12,16), Position=Vector3.new(bp[1],6,bp[2]), Color=BrickColor.new("Medium stone grey"), Material=Enum.Material.SmoothPlastic, Parent=builds})
    Part({Name="Roof_"..bp[3], Size=Vector3.new(18,1,18), Position=Vector3.new(bp[1],12.5,bp[2]), Color=BrickColor.new("Dark stone grey"), Material=Enum.Material.SmoothPlastic, Parent=builds})
    local sb = Part({Name="BldgSign_"..bp[3], Size=Vector3.new(12,2,0.3), Position=Vector3.new(bp[1],10,bp[2]+8.2), Color=BrickColor.new("Bright blue"), Material=Enum.Material.SmoothPlastic, Parent=builds})
    local bb = Instance.new("BillboardGui") bb.Size = UDim2.new(0,120,0,30) bb.StudsOffset = Vector3.new(0,2,0) bb.AlwaysOnTop = true bb.Parent = sb
    local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(1,0,1,0) lbl.BackgroundTransparency = 1 lbl.Text = "🏪 "..bp[3] lbl.TextColor3 = Color3.fromRGB(255,255,255) lbl.TextSize = 14 lbl.Font = Enum.Font.GothamBold lbl.TextStrokeTransparency = 0.3 lbl.Parent = bb
end

print("DataTycoon: Buildings done")

-- ============================================================
-- LIGHTING
-- ============================================================
local lighting = game:GetService("Lighting")
lighting.Ambient = Color3.fromRGB(100,100,120)
lighting.OutdoorAmbient = Color3.fromRGB(120,120,140)
lighting.Brightness = 2
lighting.ClockTime = 14
lighting.FogEnd = 500
lighting.FogColor = Color3.fromRGB(180,200,220)

workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: WORLD COMPLETE!")
