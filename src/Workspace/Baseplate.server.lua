--[[
    Baseplate.server.lua — DataTycoon World
    v0.10 — Toned down hub, straight sidewalks, black hole data orbs, more detail
]]

local function P(props)
    local p = Instance.new("Part")
    p.Name = props.N or "Part"
    p.Size = props.S or Vector3.new(4,4,4)
    p.Position = props.P or Vector3.new(0,0,0)
    p.Anchored = true
    p.BrickColor = props.C or BrickColor.new("Medium stone grey")
    p.Material = props.M or Enum.Material.SmoothPlastic
    p.Transparency = props.T or 0
    p.Shape = props.Sh or Enum.PartType.Block
    p.CanCollide = props.Co ~= nil and props.Co or true
    p.Parent = props.Pa or workspace
    if props.R then p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0,math.rad(props.R),0) end
    return p
end

local function Tree(x,z,s)
    s = s or 1
    P({N="Trunk",S=Vector3.new(2.5*s,10*s,2.5*s),P=Vector3.new(x,5*s,z),C=BrickColor.new("Brown"),M=Enum.Material.Wood})
    P({N="C1",S=Vector3.new(12*s,8*s,12*s),P=Vector3.new(x,12*s,z),C=BrickColor.new("Dark green"),M=Enum.Material.Grass,Sh=Enum.PartType.Ball})
    P({N="C2",S=Vector3.new(9*s,7*s,9*s),P=Vector3.new(x+2*s,15*s,z+1*s),C=BrickColor.new("Earth green"),M=Enum.Material.Grass,Sh=Enum.PartType.Ball})
    P({N="C3",S=Vector3.new(6*s,5*s,6*s),P=Vector3.new(x-1*s,18*s,z-2*s),C=BrickColor.new("Forest green"),M=Enum.Material.Grass,Sh=Enum.PartType.Ball})
end

local function Lamp(x,z)
    P({N="LPole",S=Vector3.new(0.7,9,0.7),P=Vector3.new(x,4.5,z),C=BrickColor.new("Dark stone grey"),M=Enum.Material.Metal})
    P({N="LHead",S=Vector3.new(2,0.8,2),P=Vector3.new(x,9.2,z),C=BrickColor.new("Institutional white"),M=Enum.Material.SmoothPlastic})
    local l = Instance.new("PointLight")
    l.Color = Color3.fromRGB(255,240,200)
    l.Brightness = 1.5
    l.Range = 24
    l.Parent = workspace
    -- Position the light
    l:GetPropertyChangedSignal("Parent") -- hack to keep reference
    -- Actually just parent to a part at the right position
    local anchor = P({N="LAnchor",S=Vector3.new(0.1,0.1,0.1),P=Vector3.new(x,9.2,z),T=1,Co=false})
    l.Parent = anchor
end

local function Bush(x,z,s)
    s = s or 1
    for i=1,3 do
        P({N="Bush",S=Vector3.new(3*s,2.5*s,3*s),P=Vector3.new(x+math.random(-1,1),1.25*s,z+math.random(-1,1)),C=BrickColor.new("Dark green"),M=Enum.Material.Grass,Sh=Enum.PartType.Ball})
    end
end

local function Flower(x,z)
    P({N="FStem",S=Vector3.new(0.3,1.5,0.3),P=Vector3.new(x,0.75,z),C=BrickColor.new("Dark green"),M=Enum.Material.Grass})
    local colors = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Bright blue","Hot pink"}
    P({N="FBloom",S=Vector3.new(1,1,1),P=Vector3.new(x,1.8,z),C=BrickColor.new(colors[math.random(#colors)]),M=Enum.Material.SmoothPlastic,Sh=Enum.PartType.Ball})
end

local function Rock(x,z,s)
    s = s or 1
    P({N="Rock",S=Vector3.new(3*s,2*s,3*s),P=Vector3.new(x,1*s,z),C=BrickColor.new("Dark stone grey"),M=Enum.Material.Slate,Sh=Enum.PartType.Ball})
end

-- ============================================================
-- CONFIG
-- ============================================================
local PLOT_SIZE = 80
local PLOT_GAP = 30
local PLOT_SPACING = PLOT_SIZE + PLOT_GAP  -- 110
local PLOT_RANGE = 3
local SIDEWALK_W = 6

-- ============================================================
-- BASEPLATE (solid)
-- ============================================================
P({N="Baseplate",S=Vector3.new(512,2,512),P=Vector3.new(0,-1,0),C=BrickColor.new("Dark green"),M=Enum.Material.Grass})
P({N="Spawn",S=Vector3.new(10,2,10),P=Vector3.new(0,1,0),C=BrickColor.new("Bright green"),M=Enum.Material.SmoothPlastic})

-- ============================================================
-- CENTER: DATA HUB (TONED DOWN — subtle glow, not blinding)
-- ============================================================
local hub = Instance.new("Folder") hub.Name = "DataHub" hub.Parent = workspace

-- Platform (solid dark stone, no glow)
P({N="HubPlatform",S=Vector3.new(80,3,80),P=Vector3.new(0,1.5,0),C=BrickColor.new("Dark stone grey"),M=Enum.Material.SmoothPlastic,Pa=hub})

-- Subtle accent ring (thin, not glowing bright)
P({N="HubRing",S=Vector3.new(50,0.4,50),P=Vector3.new(0,3.05,0),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=hub})

-- Server tower (5 floors, solid metal, subtle accent strips)
for floor=0,4 do
    local y = 4 + floor*8
    local sz = 22 - floor*2
    P({N="TowerF"..floor,S=Vector3.new(sz,7,sz),P=Vector3.new(0,y,0),C=BrickColor.new(floor%2==0 and "Dark stone grey" or "Medium stone grey"),M=Enum.Material.Metal,Pa=hub})
    -- Thin accent line (not neon glow)
    P({N="TowerLine"..floor,S=Vector3.new(sz+0.5,0.2,sz+0.5),P=Vector3.new(0,y-3.3,0),C=BrickColor.new("Cyan"),M=Enum.Material.SmoothPlastic,Pa=hub})
end

-- Server racks (8 around hub, solid, subtle LED dots)
for i=1,8 do
    local a = (i/8)*math.pi*2
    local x,z = math.cos(a)*28, math.sin(a)*28
    P({N="Rack"..i,S=Vector3.new(6,12,3),P=Vector3.new(x,7,z),C=BrickColor.new("Dark stone grey"),M=Enum.Material.Metal,Pa=hub})
    -- Small LED dots (not neon, just colored plastic)
    for light=0,3 do
        P({N="RackLED"..i.."_"..light,S=Vector3.new(0.5,0.3,0.5),P=Vector3.new(x,3+light*2.5,z+1.6),C=BrickColor.new(light%2==0 and "Lime green" or "Forest green"),M=Enum.Material.SmoothPlastic,Pa=hub})
    end
end

-- Data pillars (6 columns, solid stone with subtle cyan trim)
for i=1,6 do
    local a = (i/6)*math.pi*2
    local px,pz = math.cos(a)*18, math.sin(a)*18
    P({N="Pillar"..i,S=Vector3.new(3,22,3),P=Vector3.new(px,12,pz),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=hub})
    -- Cyan trim ring at base
    P({N="PillarTrim"..i,S=Vector3.new(3.5,0.5,3.5),P=Vector3.new(px,1.25,pz),C=BrickColor.new("Cyan"),M=Enum.Material.SmoothPlastic,Pa=hub})
end

-- Floating data orbs (subtle, not blinding)
for i=1,10 do
    local a = (i/10)*math.pi*2
    local r = 12 + (i%3)*4
    P({N="Orb"..i,S=Vector3.new(2,2,2),P=Vector3.new(math.cos(a)*r,26+math.sin(i)*2,math.sin(a)*r),C=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"),M=Enum.Material.SmoothPlastic,Sh=Enum.PartType.Ball,Pa=hub})
end

-- Entrance arches (4, solid stone)
for i=1,4 do
    local a = (i/4)*math.pi*2
    local x,z = math.cos(a)*42, math.sin(a)*42
    P({N="ArchP"..i,S=Vector3.new(3,16,3),P=Vector3.new(x,9,z),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=hub})
    P({N="ArchT"..i,S=Vector3.new(3,2,10),P=Vector3.new(x,18,z),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=hub})
    -- Cyan accent on arch top
    P({N="ArchAccent"..i,S=Vector3.new(3.2,0.3,10.2),P=Vector3.new(x,19.1,z),C=BrickColor.new("Cyan"),M=Enum.Material.SmoothPlastic,Pa=hub})
end

print("DataTycoon: Hub done (toned down)")

-- ============================================================
-- ROAD SYSTEM (straight, cohesive, grid-based)
-- ============================================================
local roads = Instance.new("Folder") roads.Name = "Roads" roads.Parent = workspace

local roadC = BrickColor.new("Dark stone grey")
local roadM = Enum.Material.Asphalt
local walkC = BrickColor.new("Medium stone grey")
local walkM = Enum.Material.Concrete

-- Main cross roads (straight through center)
P({N="RoadH",S=Vector3.new(512,0.3,18),P=Vector3.new(0,0.15,0),C=roadC,M=roadM,Pa=roads})
P({N="RoadV",S=Vector3.new(18,0.3,512),P=Vector3.new(0,0.15,0),C=roadC,M=roadM,Pa=roads})

-- Ring roads (3 rings)
for _,radius in ipairs({120,200,280}) do
    local segs = radius<=120 and 16 or 24
    for i=1,segs do
        local ang=(i/segs)*math.pi*2
        local nang=((i+1)/segs)*math.pi*2
        local mid=(ang+nang)/2
        local len=2*math.pi*radius/segs+4
        P({N="RingRoad_"..radius.."_"..i,S=Vector3.new(len,0.25,14),P=Vector3.new(math.cos(mid)*radius,0.12,math.sin(mid)*radius),C=roadC,M=roadM,R=math.deg(-mid),Pa=roads})
    end
end

-- Sidewalks along main roads (both sides, straight)
for _,off in ipairs({13,-13}) do
    P({N="WalkH_"..off,S=Vector3.new(512,0.35,SIDEWALK_W),P=Vector3.new(0,0.18,off),C=walkC,M=walkM,Pa=roads})
    P({N="WalkV_"..off,S=Vector3.new(SIDEWALK_W,0.35,512),P=Vector3.new(off,0.18,0),C=walkC,M=walkM,Pa=roads})
end

-- Sidewalks along ring roads (outer side)
for _,radius in ipairs({120,200,280}) do
    local segs = radius<=120 and 16 or 24
    for i=1,segs do
        local ang=(i/segs)*math.pi*2
        local nang=((i+1)/segs)*math.pi*2
        local mid=(ang+nang)/2
        local len=2*math.pi*radius/segs+4
        local r=radius+10
        P({N="RingWalk_"..radius.."_"..i,S=Vector3.new(len,0.3,SIDEWALK_W),P=Vector3.new(math.cos(mid)*r,0.15,math.sin(mid)*r),C=walkC,M=walkM,R=math.deg(-mid),Pa=roads})
    end
end

print("DataTycoon: Roads + sidewalks done")

-- ============================================================
-- PLAYER PLOTS (outer ring, connected by straight sidewalks)
-- ============================================================
local plots = Instance.new("Folder") plots.Name = "PlotMarkers" plots.Parent = workspace

local plotCount = 0
for x=-PLOT_RANGE,PLOT_RANGE do
    for z=-PLOT_RANGE,PLOT_RANGE do
        local dist = math.max(math.abs(x),math.abs(z))
        if dist >= 3 then
            local cx, cz = x*PLOT_SPACING, z*PLOT_SPACING
            local price = math.floor(40*(1.8^dist))
            
            -- Plot ground (solid raised platform)
            local plot = P({N="Plot_"..x.."_"..z,S=Vector3.new(PLOT_SIZE-4,0.5,PLOT_SIZE-4),P=Vector3.new(cx,0.25,cz),M=Enum.Material.SmoothPlastic,Pa=plots})
            plot.C = BrickColor.new("Dark green")
            
            -- Corner posts
            for _,c in ipairs({{PLOT_SIZE/2-2,PLOT_SIZE/2-2},{-PLOT_SIZE/2+2,PLOT_SIZE/2-2},{PLOT_SIZE/2-2,-PLOT_SIZE/2+2},{-PLOT_SIZE/2+2,-PLOT_SIZE/2+2}}) do
                P({N="Post",S=Vector3.new(1,5,1),P=Vector3.new(cx+c[1],3,cz+c[2]),C=BrickColor.new("Dark stone grey"),M=Enum.Material.SmoothPlastic,Pa=plot})
            end
            
            -- Privacy fence on outer edges
            local edge = PLOT_SIZE/2
            if math.abs(x)>=3 then
                local fx=x>0 and edge or -edge
                P({N="Fence",S=Vector3.new(0.6,3,PLOT_SIZE-6),P=Vector3.new(cx+fx,2,cz),C=BrickColor.new("Dark stone grey"),M=Enum.Material.Wood,Pa=plot})
            end
            if math.abs(z)>=3 then
                local fz=z>0 and edge or -edge
                P({N="Fence",S=Vector3.new(PLOT_SIZE-6,3,0.6),P=Vector3.new(cx,2,cz+fz),C=BrickColor.new("Dark stone grey"),M=Enum.Material.Wood,Pa=plot})
            end
            
            -- === STRAIGHT SIDEWALK from plot to nearest road ===
            -- Connect plot to the nearest point on the outer ring road (radius 280)
            local plotAngle = math.atan2(cz, cx)
            local roadR = 280
            local roadX = math.cos(plotAngle)*roadR
            local roadZ = math.sin(plotAngle)*roadR
            
            -- Straight sidewalk strip
            local mx,mz = (roadX+cx)/2, (roadZ+cz)/2
            local dx,dz = cx-roadX, cz-roadZ
            local len = math.sqrt(dx*dx+dz*dz)
            local rot = math.deg(math.atan2(dz,dx))
            P({N="PlotWalk_"..x.."_"..z,S=Vector3.new(len,0.35,SIDEWALK_W),P=Vector3.new(mx,0.18,mz),C=walkC,M=walkM,R=rot,Pa=roads})
            
            -- Signpost
            P({N="Sign",S=Vector3.new(0.7,6,0.7),P=Vector3.new(cx,3.5,cz),C=BrickColor.new("Dark stone grey"),M=Enum.Material.SmoothPlastic,Pa=plot})
            P({N="SignB",S=Vector3.new(7,3.5,0.3),P=Vector3.new(cx,7,cz),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=plot})
            
            -- Billboard on sign
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0,150,0,80)
            bb.StudsOffset = Vector3.new(0,2.5,0)
            bb.AlwaysOnTop = false
            bb.Parent = P({N="SignD",S=Vector3.new(0.1,0.1,0.1),P=Vector3.new(cx,8.5,cz),T=1,Co=false,Pa=plot})
            
            local l1 = Instance.new("TextLabel") l1.Size=UDim2.new(1,0,0.25,0) l1.BackgroundTransparency=1
            l1.Text="("..x..", "..z..")" l1.TextColor3=Color3.fromRGB(200,200,200) l1.TextSize=11 l1.Font=Enum.Font.GothamBold l1.TextStrokeTransparency=0.5 l1.Parent=bb
            local l2 = Instance.new("TextLabel") l2.Size=UDim2.new(1,0,0.35,0) l2.Position=UDim2.new(0,0,0.25,0) l2.BackgroundTransparency=1
            l2.Text="💰 "..price.." Data" l2.TextColor3=Color3.fromRGB(255,220,100) l2.TextSize=14 l2.Font=Enum.Font.GothamBold l2.TextStrokeTransparency=0.4 l2.Parent=bb
            local l3 = Instance.new("TextLabel") l3.Size=UDim2.new(1,0,0.2,0) l3.Position=UDim2.new(0,0,0.6,0) l3.BackgroundTransparency=1
            l3.Text="🌿 PRIVATE" l3.TextColor3=Color3.fromRGB(100,255,150) l3.TextSize=10 l3.Font=Enum.Font.GothamBold l3.TextStrokeTransparency=0.5 l3.Parent=bb
            
            -- Decorations
            Bush(cx+20,cz+20,0.7) Bush(cx-18,cz-18,0.5)
            if (x+z)%2==0 then Tree(cx+25,cz-22,0.6) end
            if (x*z)%3==0 then Rock(cx-22,cz+20,0.5) end
            
            plotCount = plotCount + 1
        end
    end
end

print("DataTycoon: "..plotCount.." plots done")

-- ============================================================
-- DATA COLLECTIBLES (black hole / star / dark energy orbs)
-- ============================================================
local blocks = Instance.new("Folder") blocks.Name = "CollectibleBlocks" blocks.Parent = workspace

local function MakeDataOrb(cx,cy,cz, ringColor)
    -- Outer dark shell (black with colored tint)
    local outer = P({N="DataOrb",S=Vector3.new(6,6,6),P=Vector3.new(cx,cy,cz),C=BrickColor.new("Really black"),M=Enum.Material.SmoothPlastic,Sh=Enum.PartType.Ball,Pa=blocks})
    
    -- Inner colored core (glowing)
    local core = P({N="DataCore",S=Vector3.new(3,3,3),P=Vector3.new(cx,cy,cz),C=ringColor,M=Enum.Material.Neon,Sh=Enum.PartType.Ball,T=0.3,Pa=blocks})
    
    -- Point light for glow effect
    local light = Instance.new("PointLight")
    light.Color = ringColor.Color
    light.Brightness = 1
    light.Range = 12
    light.Parent = core
    
    -- Star spikes (4 thin spikes sticking out)
    for i=1,4 do
        local a = (i/4)*math.pi*2
        P({N="Spike",S=Vector3.new(0.3,4,0.3),P=Vector3.new(cx+math.cos(a)*4,cy,cz+math.sin(a)*4),C=ringColor,M=Enum.Material.Neon,T=0.4,R=math.deg(-a),Pa=blocks})
    end
    
    -- Billboard label
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,100,0,30)
    bb.StudsOffset = Vector3.new(0,5,0)
    bb.AlwaysOnTop = true
    bb.Parent = outer
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0) lbl.BackgroundTransparency = 1
    lbl.Text = "✦ +5 Data" lbl.TextColor3 = ringColor.Color
    lbl.TextSize = 12 lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3 lbl.Parent = bb
    
    -- Proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = "Data Orb"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 12
    prompt.Parent = outer
end

-- Ring 1: Cyan orbs near hub
for i=1,8 do
    local a=(i/8)*math.pi*2
    MakeDataOrb(math.cos(a)*50, 5, math.sin(a)*50, BrickColor.new("Cyan"))
end
-- Ring 2: Blue orbs
for i=1,10 do
    local a=(i/10)*math.pi*2+0.3
    MakeDataOrb(math.cos(a)*80, 7, math.sin(a)*80, BrickColor.new("Bright blue"))
end
-- Ring 3: Purple orbs
for i=1,12 do
    local a=(i/12)*math.pi*2+0.15
    MakeDataOrb(math.cos(a)*115, 9, math.sin(a)*115, BrickColor.new("Bright violet"))
end
-- Ring 4: Yellow/gold orbs far out
for i=1,10 do
    local a=(i/12)*math.pi*2
    MakeDataOrb(math.cos(a)*160, 11, math.sin(a)*160, BrickColor.new("Bright yellow"))
end

print("DataTycoon: Data orbs done (black hole style)")

-- ============================================================
-- NATURE (abundant)
-- ============================================================
local nature = Instance.new("Folder") nature.Name = "Nature" nature.Parent = workspace

-- Forest clusters at corners
for _,fc in ipairs({{-200,-200},{200,-200},{-200,200},{200,200},{-220,0},{220,0},{0,-220},{0,220}}) do
    for i=1,5 do Tree(fc[1]+math.random(-25,25),fc[2]+math.random(-25,25),0.7+math.random()*0.5) end
end

-- Trees along roads
for _,off in ipairs({-260,-220,-160,160,220,260}) do
    for i=1,4 do Tree(off+math.random(-3,3),(i-2.5)*30+math.random(-3,3),0.6+math.random()*0.4) end
    for i=1,4 do Tree((i-2.5)*30+math.random(-3,3),off+math.random(-3,3),0.6+math.random()*0.4) end
end

-- Scattered trees
for i=1,25 do
    local tx,tz=math.random(-230,230),math.random(-230,230)
    if math.abs(tx)>55 or math.abs(tz)>55 then Tree(tx,tz,0.5+math.random()*0.7) end
end

-- Bushes, flowers, rocks
for i=1,40 do Bush(math.random(-240,240),math.random(-240,240),0.5+math.random()*0.7) end
for i=1,50 do Flower(math.random(-240,240),math.random(-240,240)) end
for i=1,15 do Rock(math.random(-230,230),math.random(-230,230),0.5+math.random()*1.2) end

print("DataTycoon: Nature done")

-- ============================================================
-- LAMPS
-- ============================================================
for _,off in ipairs({-240,-180,-120,120,180,240}) do
    Lamp(off,13) Lamp(off,-13) Lamp(13,off) Lamp(-13,off)
end
for _,radius in ipairs({120,200,280}) do
    local count=radius<=120 and 8 or 12
    for i=1,count do
        local a=(i/count)*math.pi*2
        Lamp(math.cos(a)*(radius+13),math.sin(a)*(radius+13))
    end
end

print("DataTycoon: Lamps done")

-- ============================================================
-- WATER
-- ============================================================
local water=Instance.new("Folder") water.Name="Water" water.Parent=workspace
local pond=P({N="Pond",S=Vector3.new(30,0.6,20),P=Vector3.new(55,0.2,55),C=BrickColor.new("Bright blue"),M=Enum.Material.Glass,Sh=Enum.PartType.Cylinder})
pond.CFrame=CFrame.new(55,0.2,55)*CFrame.Angles(0,0,math.rad(90))
for i=1,12 do local a=(i/12)*math.pi*2 Rock(55+math.cos(a)*16,55+math.sin(a)*11,0.4+math.random()*0.3) end
for i=1,8 do P({N="Stream",S=Vector3.new(4,0.4,4),P=Vector3.new(55+i*6,0.15,55+i*4),C=BrickColor.new("Bright blue"),M=Enum.Material.Glass,Pa=water}) end

print("DataTycoon: Water done")

-- ============================================================
-- BUILDINGS
-- ============================================================
local builds=Instance.new("Folder") builds.Name="Buildings" builds.Parent=workspace
for _,bp in ipairs({{60,-60,"Data Store"},{-60,60,"Tech Shop"},{-60,-60,"Server Farm"},{60,60,"Mining Co"}}) do
    P({N="Bldg_"..bp[3],S=Vector3.new(16,12,16),P=Vector3.new(bp[1],6,bp[2]),C=BrickColor.new("Medium stone grey"),M=Enum.Material.SmoothPlastic,Pa=builds})
    P({N="Roof_"..bp[3],S=Vector3.new(18,1,18),P=Vector3.new(bp[1],12.5,bp[2]),C=BrickColor.new("Dark stone grey"),M=Enum.Material.SmoothPlastic,Pa=builds})
    local sb=P({N="BldgSign_"..bp[3],S=Vector3.new(12,2,0.3),P=Vector3.new(bp[1],10,bp[2]+8.2),C=BrickColor.new("Bright blue"),M=Enum.Material.SmoothPlastic,Pa=builds})
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,120,0,30) bb.StudsOffset=Vector3.new(0,2,0) bb.AlwaysOnTop=true bb.Parent=sb
    local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="🏪 "..bp[3] lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.TextSize=14 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
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
