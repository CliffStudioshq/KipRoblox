--[[
    Baseplate.server.lua — DataTycoon World
    v0.13 — Visual overhaul: lighting effects, terrain, neon noir aesthetic
]]

local F = math.floor
local R = math.random

local function Part(props)
    local p = Instance.new("Part")
    p.Name = props.name or "Part"
    p.Size = props.size or Vector3.new(4,4,4)
    p.Position = props.pos or Vector3.new(0,0,0)
    p.Anchored = true
    p.BrickColor = props.color or BrickColor.new("Medium stone grey")
    p.Material = props.mat or Enum.Material.SmoothPlastic
    p.Transparency = props.alpha or 0
    p.Shape = props.shape or Enum.PartType.Block
    p.CanCollide = props.collide ~= nil and props.collide or true
    p.Parent = props.parent or workspace
    if props.rot then p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0,math.rad(props.rot),0) end
    return p
end

local function Tree(x,z,s)
    s = s or 1
    Part({name="Trunk",size=Vector3.new(2.5*s,10*s,2.5*s),pos=Vector3.new(x,5*s,z),color=BrickColor.new("Brown"),mat=Enum.Material.Wood})
    Part({name="C1",size=Vector3.new(13*s,9*s,13*s),pos=Vector3.new(x,12*s,z),color=BrickColor.new("Dark green"),mat=Enum.Material.Grass,shape=Enum.PartType.Ball})
    Part({name="C2",size=Vector3.new(10*s,7*s,10*s),pos=Vector3.new(x+2*s,16*s,z+1*s),color=BrickColor.new("Earth green"),mat=Enum.Material.Grass,shape=Enum.PartType.Ball})
    Part({name="C3",size=Vector3.new(7*s,5*s,7*s),pos=Vector3.new(x-1*s,19*s,z-2*s),color=BrickColor.new("Forest green"),mat=Enum.Material.Grass,shape=Enum.PartType.Ball})
end

local function Lamp(x,z,col)
    col = col or Color3.fromRGB(255,240,200)
    Part({name="Pole",size=Vector3.new(0.5,8,0.5),pos=Vector3.new(x,4,z),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Metal})
    Part({name="Head",size=Vector3.new(1.5,0.5,1.5),pos=Vector3.new(x,8.2,z),color=BrickColor.new("Institutional white"),mat=Enum.Material.SmoothPlastic})
    local a = Part({name="LA",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(x,8.2,z),alpha=1,collide=false})
    local l = Instance.new("PointLight") l.Color=col l.Brightness=1.5 l.Range=22 l.Parent=a
end

local function Bush(x,z,s)
    s = s or 1
    for i=1,3 do Part({name="Bush",size=Vector3.new(3*s,2.5*s,3*s),pos=Vector3.new(x+R(-1,1),1.25*s,z+R(-1,1)),color=BrickColor.new("Dark green"),mat=Enum.Material.Grass,shape=Enum.PartType.Ball}) end
end

local function Flower(x,z)
    Part({name="Stem",size=Vector3.new(0.3,1.5,0.3),pos=Vector3.new(x,0.75,z),color=BrickColor.new("Dark green"),mat=Enum.Material.Grass})
    local c={"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Bright blue","Hot pink","Lavender","Magenta"}
    Part({name="Bloom",size=Vector3.new(1,1,1),pos=Vector3.new(x,1.8,z),color=BrickColor.new(c[R(#c)]),mat=Enum.Material.SmoothPlastic,shape=Enum.PartType.Ball})
end

local function Rock(x,z,s)
    s = s or 1
    Part({name="Rock",size=Vector3.new(3*s,2*s,3*s),pos=Vector3.new(x,1*s,z),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Slate,shape=Enum.PartType.Ball})
end

-- ============================================================
-- CONFIG
-- ============================================================
local PLOT_SIZE = 90
local PLOT_GAP = 40
local PLOT_SPACING = PLOT_SIZE + PLOT_GAP  -- 130
local PLOT_RANGE = 3

-- ============================================================
-- BASEPLATE (thick solid ground)
-- ============================================================
Part({name="Baseplate",size=Vector3.new(512,4,512),pos=Vector3.new(0,-2,0),color=BrickColor.new("Dark green"),mat=Enum.Material.Grass})
Part({name="Spawn",size=Vector3.new(14,3,14),pos=Vector3.new(0,1.5,0),color=BrickColor.new("Bright green"),mat=Enum.Material.SmoothPlastic})

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation" spawn.Size = Vector3.new(10,1,10) spawn.Position = Vector3.new(0,3.5,0)
spawn.Anchored = true spawn.CanCollide = false spawn.Transparency = 1 spawn.Parent = workspace

-- ============================================================
-- TERRAIN VARIATION (hills, elevation changes)
-- ============================================================
-- Gentle hills at the corners
for _,hc in ipairs({{-200,-200,30},{200,-200,25},{-200,200,20},{200,200,35}}) do
    for i=1,5 do
        local angle = (i/5)*math.pi*2
        local r = 15 + R(-5,5)
        Part({name="Hill",size=Vector3.new(r*2,3+R()*2,r*2),pos=Vector3.new(hc[1]+math.cos(angle)*r,1,hc[2]+math.sin(angle)*r),color=BrickColor.new("Dark green"),mat=Enum.Material.Grass,shape=Enum.PartType.Ball})
    end
end

-- ============================================================
-- CENTER: DATA HUB (neon noir aesthetic — dark + cyan accents)
-- ============================================================
local hub = Instance.new("Folder") hub.Name = "DataHub" hub.Parent = workspace

Part({name="Platform",size=Vector3.new(80,3,80),pos=Vector3.new(0,1.5,0),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
Part({name="Ring",size=Vector3.new(50,0.3,50),pos=Vector3.new(0,3.0,0),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})

-- Tower
for f=0,4 do
    local y=4+f*8 local sz=22-f*2
    Part({name="TF"..f,size=Vector3.new(sz,7,sz),pos=Vector3.new(0,y,0),color=BrickColor.new(f%2==0 and "Dark stone grey" or "Medium stone grey"),mat=Enum.Material.Metal,parent=hub})
    Part({name="TL"..f,size=Vector3.new(sz+0.5,0.15,sz+0.5),pos=Vector3.new(0,y-3.3,0),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

-- Racks
for i=1,8 do
    local a=(i/8)*math.pi*2 local x,z=math.cos(a)*28,math.sin(a)*28
    Part({name="R"..i,size=Vector3.new(6,12,3),pos=Vector3.new(x,7,z),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Metal,parent=hub})
    for l=0,3 do Part({name="L"..i..l,size=Vector3.new(0.4,0.25,0.4),pos=Vector3.new(x,3+l*2.5,z+1.6),color=BrickColor.new(l%2==0 and "Lime green" or "Forest green"),mat=Enum.Material.SmoothPlastic,parent=hub}) end
end

-- Pillars
for i=1,6 do
    local a=(i/6)*math.pi*2 local px,pz=math.cos(a)*18,math.sin(a)*18
    Part({name="P"..i,size=Vector3.new(3,22,3),pos=Vector3.new(px,12,pz),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="PT"..i,size=Vector3.new(3.5,0.4,3.5),pos=Vector3.new(px,1.2,pz),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

-- Orbs
for i=1,10 do
    local a=(i/10)*math.pi*2 local r=12+(i%3)*4
    Part({name="O"..i,size=Vector3.new(2,2,2),pos=Vector3.new(math.cos(a)*r,26+math.sin(i)*2,math.sin(a)*r),color=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"),mat=Enum.Material.SmoothPlastic,shape=Enum.PartType.Ball,parent=hub})
end

-- Arches
for i=1,4 do
    local a=(i/4)*math.pi*2 local x,z=math.cos(a)*42,math.sin(a)*42
    Part({name="AP"..i,size=Vector3.new(3,16,3),pos=Vector3.new(x,9,z),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="AT"..i,size=Vector3.new(3,2,10),pos=Vector3.new(x,18,z),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="AA"..i,size=Vector3.new(3.2,0.2,10.2),pos=Vector3.new(x,19.1,z),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

print("DataTycoon: Hub done")

-- ============================================================
-- WALKWAYS (4 cardinal, clean)
-- ============================================================
local walks = Instance.new("Folder") walks.Name = "Walkways" walks.Parent = workspace
local wC = BrickColor.new("Medium stone grey") local wM = Enum.Material.Concrete local wW = 8

for _,d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    local dx,dz=d[1],d[2] local mx,mz=dx*157.5,dz*157.5
    if dx~=0 then Part({name="W",size=Vector3.new(230,0.3,wW),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,parent=walks})
    else Part({name="W",size=Vector3.new(wW,0.3,230),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,parent=walks}) end
end

print("DataTycoon: Walkways done")

-- ============================================================
-- PLAYER PLOTS (outer ring, beautiful)
-- ============================================================
local plots = Instance.new("Folder") plots.Name = "PlotMarkers" plots.Parent = workspace
local plotCount = 0

for x=-PLOT_RANGE,PLOT_RANGE do
    for z=-PLOT_RANGE,PLOT_RANGE do
        local dist=math.max(math.abs(x),math.abs(z))
        if dist>=3 then
            local cx,cz=x*PLOT_SPACING,z*PLOT_SPACING
            local price=F(50*(2^dist))
            
            Part({name="Plot_"..x.."_"..z,size=Vector3.new(PLOT_SIZE-4,0.5,PLOT_SIZE-4),pos=Vector3.new(cx,0.25,cz),color=BrickColor.new("Dark green"),mat=Enum.Material.SmoothPlastic,parent=plots})
            
            for _,c in ipairs({{40,40},{-40,40},{40,-40},{-40,-40}}) do
                Part({name="Post",size=Vector3.new(1,5,1),pos=Vector3.new(cx+c[1],3,cz+c[2]),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
            end
            
            if math.abs(x)>=3 then Part({name="Fence",size=Vector3.new(0.5,3,86),pos=Vector3.new(cx+(x>0 and 42 or -42),2,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Wood,parent=plots}) end
            if math.abs(z)>=3 then Part({name="Fence",size=Vector3.new(86,3,0.5),pos=Vector3.new(cx,2,cz+(z>0 and 42 or -42)),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Wood,parent=plots}) end
            
            -- Sidewalk to nearest walkway
            local angle=math.atan2(cz,cx) local nx,nz=math.cos(angle)*265,math.sin(angle)*265
            local mx,mz=(nx+cx)/2,(nz+cz)/2 local dx,dz=cx-nx,cz-nz
            local len=math.sqrt(dx*dx+dz*dz) local rot=math.deg(math.atan2(dz,dx))
            Part({name="PW_"..x.."_"..z,size=Vector3.new(len,0.3,wW),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,rot=rot,parent=walks})
            
            Part({name="Sign",size=Vector3.new(0.6,6,0.6),pos=Vector3.new(cx,3.5,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
            Part({name="SignB",size=Vector3.new(7,3.5,0.3),pos=Vector3.new(cx,7,cz),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
            
            local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,140,0,75) bb.StudsOffset=Vector3.new(0,2.5,0) bb.AlwaysOnTop=false
            bb.Parent=Part({name="SD",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,8.5,cz),alpha=1,collide=false,parent=plots})
            local t1=Instance.new("TextLabel") t1.Size=UDim2.new(1,0,0.25,0) t1.BackgroundTransparency=1 t1.Text="("..x..", "..z..")" t1.TextColor3=Color3.fromRGB(200,200,200) t1.TextSize=11 t1.Font=Enum.Font.GothamBold t1.TextStrokeTransparency=0.5 t1.Parent=bb
            local t2=Instance.new("TextLabel") t2.Size=UDim2.new(1,0,0.35,0) t2.Position=UDim2.new(0,0,0.25,0) t2.BackgroundTransparency=1 t2.Text="💰 "..price t2.TextColor3=Color3.fromRGB(255,220,100) t2.TextSize=14 t2.Font=Enum.Font.GothamBold t2.TextStrokeTransparency=0.4 t2.Parent=bb
            local t3=Instance.new("TextLabel") t3.Size=UDim2.new(1,0,0.2,0) t3.Position=UDim2.new(0,0,0.6,0) t3.BackgroundTransparency=1 t3.Text="🌿 PRIVATE" t3.TextColor3=Color3.fromRGB(100,255,150) t3.TextSize=10 t3.Font=Enum.Font.GothamBold t3.TextStrokeTransparency=0.5 t3.Parent=bb
            
            Bush(cx+25,cz+25,0.8) Bush(cx-20,cz-20,0.6) Bush(cx+15,cz-28,0.5)
            if (x+z)%2==0 then Tree(cx+30,cz-25,0.7) end
            if (x*z)%3==0 then Tree(cx-28,cz+20,0.5) end
            if (x+z)%4==0 then Rock(cx-25,cz-25,0.6) end
            for i=1,8 do Flower(cx+R(-35,35),cz+R(-35,35)) end
            
            plotCount=plotCount+1
        end
    end
end

print("DataTycoon: "..plotCount.." plots done")

-- ============================================================
-- DATA COLLECTIBLES (black hole orbs)
-- ============================================================
local blocks = Instance.new("Folder") blocks.Name = "CollectibleBlocks" blocks.Parent = workspace

local function DataOrb(cx,cy,cz,col)
    local shell=Part({name="Shell",size=Vector3.new(7,7,7),pos=Vector3.new(cx,cy,cz),color=BrickColor.new("Really black"),mat=Enum.Material.SmoothPlastic,shape=Enum.PartType.Ball,parent=blocks})
    local core=Part({name="Core",size=Vector3.new(3.5,3.5,3.5),pos=Vector3.new(cx,cy,cz),color=col,mat=Enum.Material.Neon,shape=Enum.PartType.Ball,alpha=0.35,parent=blocks})
    local a=Part({name="LA",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,cy,cz),alpha=1,collide=false,parent=blocks})
    local l=Instance.new("PointLight") l.Color=col l.Brightness=0.8 l.Range=10 l.Parent=a
    for i=1,4 do local a2=(i/4)*math.pi*2 Part({name="Spike",size=Vector3.new(0.25,4.5,0.25),pos=Vector3.new(cx+math.cos(a2)*4.5,cy,cz+math.sin(a2)*4.5),color=col,mat=Enum.Material.Neon,alpha=0.4,rot=math.deg(-a2),parent=blocks}) end
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,100,0,28) bb.StudsOffset=Vector3.new(0,5.5,0) bb.AlwaysOnTop=true bb.Parent=shell
    local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="✦ +5" lbl.TextColor3=col lbl.TextSize=12 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
    local p=Instance.new("ProximityPrompt") p.ActionText="Collect" p.ObjectText="Data Orb" p.HoldDuration=0.3 p.MaxActivationDistance=12 p.Parent=shell
end

for i=1,8 do local a=(i/8)*math.pi*2 DataOrb(math.cos(a)*52,5,math.sin(a)*52,BrickColor.new("Cyan")) end
for i=1,10 do local a=(i/10)*math.pi*2+0.3 DataOrb(math.cos(a)*85,7,math.sin(a)*85,BrickColor.new("Bright blue")) end
for i=1,12 do local a=(i/12)*math.pi*2+0.15 DataOrb(math.cos(a)*120,9,math.sin(a)*120,BrickColor.new("Bright violet")) end
for i=1,10 do local a=(i/12)*math.pi*2 DataOrb(math.cos(a)*165,11,math.sin(a)*165,BrickColor.new("Bright yellow")) end

print("DataTycoon: Data orbs done")

-- ============================================================
-- NATURE (abundant, varied, pretty)
-- ============================================================
local nature=Instance.new("Folder") nature.Name="Nature" nature.Parent=workspace

-- Forest clusters
for _,fc in ipairs({{-210,-210},{210,-210},{-210,210},{210,210},{-230,0},{230,0},{0,-230},{0,230}}) do
    for i=1,6 do Tree(fc[1]+R(-20,20),fc[2]+R(-20,20),0.6+R()*0.5) end
    for i=1,3 do Bush(fc[1]+R(-25,25),fc[2]+R(-25,25),0.7+R()*0.5) end
    for i=1,2 do Rock(fc[1]+R(-15,15),fc[2]+R(-15,15),0.5+R()*0.7) end
end

-- Trees along walkways
for _,d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    for dist=55,265,20 do
        local x,z=d[1]*dist,d[2]*dist
        if d[1]==0 then Tree(x+10,z,0.5+R()*0.3) Tree(x-10,z,0.5+R()*0.3)
        else Tree(x,z+10,0.5+R()*0.3) Tree(x,z-10,0.5+R()*0.3) end
    end
end

-- Scattered trees
for i=1,30 do local tx,tz=R(-240,240),R(-240,240) if math.abs(tx)>50 or math.abs(tz)>50 then Tree(tx,tz,0.5+R()*0.6) end end

-- Bushes, flowers, rocks
for i=1,50 do Bush(R(-250,250),R(-250,250),0.4+R()*0.6) end
for i=1,100 do Flower(R(-250,250),R(-250,250)) end
for i=1,20 do Rock(R(-240,240),R(-240,240),0.4+R()*1.0) end

print("DataTycoon: Nature done")

-- ============================================================
-- LAMPS (along walkways)
-- ============================================================
for _,d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    for dist=55,265,25 do
        local x,z=d[1]*dist,d[2]*dist
        if d[1]==0 then Lamp(x+9,z,Color3.fromRGB(255,240,200)) Lamp(x-9,z,Color3.fromRGB(255,240,200))
        else Lamp(x,z+9,Color3.fromRGB(255,240,200)) Lamp(x,z-9,Color3.fromRGB(255,240,200)) end
    end
end

-- Accent lamps on hub
for i=1,8 do
    local a=(i/8)*math.pi*2
    Lamp(math.cos(a)*35,math.sin(a)*35,Color3.fromRGB(100,200,255))
end

print("DataTycoon: Lamps done")

-- ============================================================
-- WATER
-- ============================================================
local water=Instance.new("Folder") water.Name="Water" water.Parent=workspace
local pond=Part({name="Pond",size=Vector3.new(28,0.5,18),pos=Vector3.new(58,0.2,58),color=BrickColor.new("Bright blue"),mat=Enum.Material.Glass,shape=Enum.PartType.Cylinder})
pond.CFrame=CFrame.new(58,0.2,58)*CFrame.Angles(0,0,math.rad(90))
for i=1,10 do local a=(i/10)*math.pi*2 Rock(58+math.cos(a)*15,58+math.sin(a)*10,0.3+R()*0.3) end
for i=1,6 do Part({name="Stream",size=Vector3.new(4,0.3,4),pos=Vector3.new(58+i*7,0.15,58+i*5),color=BrickColor.new("Bright blue"),mat=Enum.Material.Glass,parent=water}) end

local pond2=Part({name="Pond2",size=Vector3.new(16,0.5,12),pos=Vector3.new(-55,0.2,-55),color=BrickColor.new("Bright blue"),mat=Enum.Material.Glass,shape=Enum.PartType.Cylinder})
pond2.CFrame=CFrame.new(-55,0.2,-55)*CFrame.Angles(0,0,math.rad(90))
for i=1,6 do Rock(-55+math.cos((i/6)*math.pi*2)*9,-55+math.sin((i/6)*math.pi*2)*7,0.3) end

print("DataTycoon: Water done")

-- ============================================================
-- BUILDINGS
-- ============================================================
local builds=Instance.new("Folder") builds.Name="Buildings" builds.Parent=workspace
for _,bp in ipairs({{62,-62,"Data Store"},{-62,62,"Tech Shop"},{-62,-62,"Server Farm"},{62,62,"Mining Co"}}) do
    Part({name="B_"..bp[3],size=Vector3.new(14,11,14),pos=Vector3.new(bp[1],6,bp[2]),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=builds})
    Part({name="R_"..bp[3],size=Vector3.new(16,1,16),pos=Vector3.new(bp[1],12,bp[2]),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=builds})
    local sb=Part({name="S_"..bp[3],size=Vector3.new(10,2,0.3),pos=Vector3.new(bp[1],10,bp[2]+7.2),color=BrickColor.new("Bright blue"),mat=Enum.Material.SmoothPlastic,parent=builds})
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,100,0,25) bb.StudsOffset=Vector3.new(0,1.5,0) bb.AlwaysOnTop=true bb.Parent=sb
    local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="🏪 "..bp[3] lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.TextSize=13 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
end

print("DataTycoon: Buildings done")

-- ============================================================
-- LIGHTING EFFECTS (the magic that makes it look amazing)
-- ============================================================
local l = game:GetService("Lighting")

-- Core lighting
l.Ambient = Color3.fromRGB(80,80,100)
l.OutdoorAmbient = Color3.fromRGB(100,100,120)
l.Brightness = 2.5
l.ClockTime = 14
l.FogEnd = 800
l.FogColor = Color3.fromRGB(160,180,210)
l.GlobalShadows = true
l.ShadowSoftness = 0.3

-- Bloom (soft glow on bright areas)
local bloom = Instance.new("BloomEffect")
bloom.Name = "Bloom"
bloom.Intensity = 0.4
bloom.Size = 30
bloom.Threshold = 0.8
bloom.Parent = l

-- ColorCorrection (warm, vibrant tones)
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ColorCorrection"
cc.Brightness = 0.02
cc.Contrast = 0.05
cc.Saturation = 0.15
cc.TintColor = Color3.fromRGB(220,230,255)
cc.Parent = l

-- SunRays (god rays from the sun)
local sunrays = Instance.new("SunRaysEffect")
sunrays.Name = "SunRays"
sunrays.Intensity = 0.15
sunrays.Spread = 0.8
sunrays.Parent = l

-- Atmosphere (haze, depth)
local atmos = Instance.new("Atmosphere")
atmos.Name = "Atmosphere"
atmos.Density = 0.3
atmos.Offset = 0.1
atmos.Color = Color3.fromRGB(180,200,230)
atmos.Decay = 0.95
atmos.Glare = 0.2
atmos.Haze = 2
atmos.Parent = l

-- Skybox
local sky = Instance.new("Sky")
sky.Name = "Sky"
sky.SkyboxBk = "rbxassetid://1007059817"
sky.SkyboxDn = "rbxassetid://1007060023"
sky.SkyboxFt = "rbxassetid://1007059817"
sky.SkyboxLf = "rbxassetid://1007059817"
sky.SkyboxRt = "rbxassetid://1007059817"
sky.SkyboxUp = "rbxassetid://1007060023"
sky.Parent = l

print("DataTycoon: Lighting effects done")

workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: WORLD COMPLETE!")
