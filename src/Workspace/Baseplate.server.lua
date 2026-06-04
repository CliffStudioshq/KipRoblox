--[[
    Baseplate.server.lua — DataTycoon World
    v0.14 — Fewer bigger plots, visible data orbs, lush walkways, terrain grass
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
    local lt = Instance.new("PointLight") lt.Color=col lt.Brightness=1.5 lt.Range=22 lt.Parent=a
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
-- CONFIG: 8 BIG PLOTS (corners + midpoints of each side)
-- ============================================================
local PLOT_SIZE = 120  -- Much bigger
local PLOT_GAP = 50    -- More space between
local PLOT_SPACING = PLOT_SIZE + PLOT_GAP  -- 170

-- Only 8 plots: 4 corners + 4 edge midpoints
local PLOT_POSITIONS = {
    {-3,-3},{-3,0},{-3,3},  -- Left column
    {0,-3},{0,3},            -- Top/bottom middle (skip center)
    {3,-3},{3,0},{3,3},      -- Right column
}
-- Actually let's do just 8: 4 corners + 4 cardinal midpoints
local PLOTS = {
    {-3,-3},{-3,3},{3,-3},{3,3},  -- 4 corners
    {0,-3},{0,3},{-3,0},{3,0},    -- 4 edge midpoints
}

-- ============================================================
-- TERRAIN (using Roblox Terrain for grass texture)
-- ============================================================
local terrain = workspace.Terrain
terrain.WaterWaveSize = 0
terrain.WaterWaveSpeed = 0
terrain.WaterReflectance = 0
terrain.WaterTransparency = 1

-- Fill the baseplate area with grass terrain
local region = Region3.new(Vector3.new(-256, -10, -256), Vector3.new(256, 5, 256))
terrain:FillRegion(region, 4, Enum.Material.Grass)

-- Add some terrain hills at corners
for _,hc in ipairs({{-180,-180},{180,-180},{-180,180},{180,180}}) do
    for i=1,8 do
        local a=(i/8)*math.pi*2
        local r=12+R(-5,5)
        terrain:FillBall(CFrame.new(hc[1]+math.cos(a)*r, 2, hc[2]+math.sin(a)*r), 8+R()*4, Enum.Material.Grass)
    end
end

-- Spawn platform
Part({name="Spawn",size=Vector3.new(14,3,14),pos=Vector3.new(0,1.5,0),color=BrickColor.new("Bright green"),mat=Enum.Material.SmoothPlastic})

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation" spawn.Size=Vector3.new(10,1,10) spawn.Position=Vector3.new(0,3.5,0)
spawn.Anchored=true spawn.CanCollide=false spawn.Transparency=1 spawn.Parent=workspace

print("DataTycoon: Terrain + spawn done")

-- ============================================================
-- CENTER: DATA HUB
-- ============================================================
local hub=Instance.new("Folder") hub.Name="DataHub" hub.Parent=workspace

Part({name="Platform",size=Vector3.new(80,3,80),pos=Vector3.new(0,1.5,0),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
Part({name="Ring",size=Vector3.new(50,0.3,50),pos=Vector3.new(0,3.0,0),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})

for f=0,4 do
    local y=4+f*8 local sz=22-f*2
    Part({name="TF"..f,size=Vector3.new(sz,7,sz),pos=Vector3.new(0,y,0),color=BrickColor.new(f%2==0 and "Dark stone grey" or "Medium stone grey"),mat=Enum.Material.Metal,parent=hub})
    Part({name="TL"..f,size=Vector3.new(sz+0.5,0.15,sz+0.5),pos=Vector3.new(0,y-3.3,0),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

for i=1,8 do
    local a=(i/8)*math.pi*2 local x,z=math.cos(a)*28,math.sin(a)*28
    Part({name="R"..i,size=Vector3.new(6,12,3),pos=Vector3.new(x,7,z),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Metal,parent=hub})
    for l=0,3 do Part({name="L"..i..l,size=Vector3.new(0.4,0.25,0.4),pos=Vector3.new(x,3+l*2.5,z+1.6),color=BrickColor.new(l%2==0 and "Lime green" or "Forest green"),mat=Enum.Material.SmoothPlastic,parent=hub}) end
end

for i=1,6 do
    local a=(i/6)*math.pi*2 local px,pz=math.cos(a)*18,math.sin(a)*18
    Part({name="P"..i,size=Vector3.new(3,22,3),pos=Vector3.new(px,12,pz),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="PT"..i,size=Vector3.new(3.5,0.4,3.5),pos=Vector3.new(px,1.2,pz),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

for i=1,10 do
    local a=(i/10)*math.pi*2 local r=12+(i%3)*4
    Part({name="O"..i,size=Vector3.new(2,2,2),pos=Vector3.new(math.cos(a)*r,26+math.sin(i)*2,math.sin(a)*r),color=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"),mat=Enum.Material.SmoothPlastic,shape=Enum.PartType.Ball,parent=hub})
end

for i=1,4 do
    local a=(i/4)*math.pi*2 local x,z=math.cos(a)*42,math.sin(a)*42
    Part({name="AP"..i,size=Vector3.new(3,16,3),pos=Vector3.new(x,9,z),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="AT"..i,size=Vector3.new(3,2,10),pos=Vector3.new(x,18,z),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=hub})
    Part({name="AA"..i,size=Vector3.new(3.2,0.2,10.2),pos=Vector3.new(x,19.1,z),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=hub})
end

-- Accent lamps on hub
for i=1,8 do
    local a=(i/8)*math.pi*2
    Lamp(math.cos(a)*35,math.sin(a)*35,Color3.fromRGB(100,200,255))
end

print("DataTycoon: Hub done")

-- ============================================================
-- WALKWAYS (4 cardinal, lush with trees)
-- ============================================================
local walks=Instance.new("Folder") walks.Name="Walkways" walks.Parent=workspace
local wC=BrickColor.new("Medium stone grey") local wM=Enum.Material.Concrete local wW=8

for _,d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    local dx,dz=d[1],d[2] local mx,mz=dx*157.5,dz*157.5
    if dx~=0 then Part({name="W",size=Vector3.new(230,0.3,wW),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,parent=walks})
    else Part({name="W",size=Vector3.new(wW,0.3,230),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,parent=walks}) end
    
    -- Trees along both sides of walkway
    for dist=50,260,18 do
        local tx,tz=dx*dist,dz*dist
        if dx==0 then
            Tree(tx+10,tz,0.5+R()*0.3) Tree(tx-10,tz,0.5+R()*0.3)
            if dist%36==0 then Bush(tx+15,tz,0.6) Bush(tx-15,tz,0.6) end
        else
            Tree(tx,tz+10,0.5+R()*0.3) Tree(tx,tz-10,0.5+R()*0.3)
            if dist%36==0 then Bush(tx,tz+15,0.6) Bush(tx,tz-15,0.6) end
        end
    end
    
    -- Lamps along walkway
    for dist=60,260,30 do
        local lx,lz=dx*dist,dz*dist
        if dx==0 then Lamp(lx+9,lz) Lamp(lx-9,lz)
        else Lamp(lx,lz+9) Lamp(lx,lz-9) end
    end
end

print("DataTycoon: Walkways + trees + lamps done")

-- ============================================================
-- PLAYER PLOTS (8 big plots)
-- ============================================================
local plots=Instance.new("Folder") plots.Name="PlotMarkers" plots.Parent=workspace
local plotCount=0

for _,pp in ipairs(PLOTS) do
    local x,z=pp[1],pp[2]
    local dist=math.max(math.abs(x),math.abs(z))
    local cx,cz=x*PLOT_SPACING,z*PLOT_SPACING
    local price=F(50*(2^dist))
    
    -- Plot ground (raised platform on terrain)
    Part({name="Plot_"..x.."_"..z,size=Vector3.new(PLOT_SIZE-4,0.6,PLOT_SIZE-4),pos=Vector3.new(cx,0.3,cz),color=BrickColor.new("Dark green"),mat=Enum.Material.SmoothPlastic,parent=plots})
    
    -- Corner posts
    for _,c in ipairs({{55,55},{-55,55},{55,-55},{-55,-55}}) do
        Part({name="Post",size=Vector3.new(1.2,5,1.2),pos=Vector3.new(cx+c[1],3,cz+c[2]),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
    end
    
    -- Privacy fences on outer edges
    local edge=PLOT_SIZE/2
    if math.abs(x)>=3 then
        Part({name="Fence",size=Vector3.new(0.5,3,PLOT_SIZE-6),pos=Vector3.new(cx+(x>0 and edge or -edge),2,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Wood,parent=plots})
    end
    if math.abs(z)>=3 then
        Part({name="Fence",size=Vector3.new(PLOT_SIZE-6,3,0.5),pos=Vector3.new(cx,2,cz+(z>0 and edge or -edge)),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Wood,parent=plots})
    end
    
    -- Sidewalk to nearest walkway
    local angle=math.atan2(cz,cx)
    local roadR=265
    local nx,nz=math.cos(angle)*roadR,math.sin(angle)*roadR
    local mx,mz=(nx+cx)/2,(nz+cz)/2
    local ddx,ddz=cx-nx,cz-nz
    local len=math.sqrt(ddx*ddx+ddz*ddz)
    local rot=math.deg(math.deg(math.atan2(ddz,ddx)))
    Part({name="PW_"..x.."_"..z,size=Vector3.new(len,0.3,wW),pos=Vector3.new(mx,0.15,mz),color=wC,mat=wM,rot=rot,parent=walks})
    
    -- Signpost
    Part({name="Sign",size=Vector3.new(0.6,6,0.6),pos=Vector3.new(cx,3.5,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
    Part({name="SignB",size=Vector3.new(8,4,0.3),pos=Vector3.new(cx,7.5,cz),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=plots})
    
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,150,0,80) bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=false
    bb.Parent=Part({name="SD",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,9.5,cz),alpha=1,collide=false,parent=plots})
    local t1=Instance.new("TextLabel") t1.Size=UDim2.new(1,0,0.22,0) t1.BackgroundTransparency=1 t1.Text="("..x..", "..z..")" t1.TextColor3=Color3.fromRGB(200,200,200) t1.TextSize=12 t1.Font=Enum.Font.GothamBold t1.TextStrokeTransparency=0.5 t1.Parent=bb
    local t2=Instance.new("TextLabel") t2.Size=UDim2.new(1,0,0.35,0) t2.Position=UDim2.new(0,0,0.22,0) t2.BackgroundTransparency=1 t2.Text="💰 "..price t2.TextColor3=Color3.fromRGB(255,220,100) t2.TextSize=15 t2.Font=Enum.Font.GothamBold t2.TextStrokeTransparency=0.4 t2.Parent=bb
    local t3=Instance.new("TextLabel") t3.Size=UDim2.new(1,0,0.23,0) t3.Position=UDim2.new(0,0,0.57,0) t3.BackgroundTransparency=1 t3.Text="🌿 PRIVATE" t3.TextColor3=Color3.fromRGB(100,255,150) t3.TextSize=11 t3.Font=Enum.Font.GothamBold t3.TextStrokeTransparency=0.5 t3.Parent=bb
    
    -- Rich decorations per plot
    Bush(cx+35,cz+35,0.9) Bush(cx-30,cz-30,0.7) Bush(cx+20,cz-40,0.6) Bush(cx-40,cz+20,0.5)
    Tree(cx+40,cz-35,0.8) Tree(cx-35,cz+30,0.6)
    if (x+z)%2==0 then Tree(cx+20,cz+40,0.5) end
    Rock(cx-40,cz-40,0.7) Rock(cx+35,cz-10,0.4)
    for i=1,12 do Flower(cx+R(-50,50),cz+R(-50,50)) end
    
    plotCount=plotCount+1
end

print("DataTycoon: "..plotCount.." big plots done")

-- ============================================================
-- DATA COLLECTIBLES (bright, visible, black hole style)
-- ============================================================
local blocks=Instance.new("Folder") blocks.Name="CollectibleBlocks" blocks.Parent=workspace

local function DataOrb(cx,cy,cz,col)
    -- Outer dark shell
    local shell=Part({name="Shell",size=Vector3.new(6,6,6),pos=Vector3.new(cx,cy,cz),color=BrickColor.new("Really black"),mat=Enum.Material.SmoothPlastic,shape=Enum.PartType.Ball,parent=blocks})
    -- Bright inner core
    local core=Part({name="Core",size=Vector3.new(3,3,3),pos=Vector3.new(cx,cy,cz),color=col,mat=Enum.Material.Neon,shape=Enum.PartType.Ball,alpha=0.2,parent=blocks})
    -- Light
    local a=Part({name="LA",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,cy,cz),alpha=1,collide=false,parent=blocks})
    local lt=Instance.new("PointLight") lt.Color=col lt.Brightness=1.5 lt.Range=14 lt.Parent=a
    -- 4 spikes
    for i=1,4 do
        local a2=(i/4)*math.pi*2
        Part({name="Spike",size=Vector3.new(0.3,5,0.3),pos=Vector3.new(cx+math.cos(a2)*4,cy,cz+math.sin(a2)*4),color=col,mat=Enum.Material.Neon,alpha=0.3,rot=math.deg(-a2),parent=blocks})
    end
    -- Billboard (bright, visible)
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,120,0,35) bb.StudsOffset=Vector3.new(0,5,0) bb.AlwaysOnTop=true bb.Parent=shell
    local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="✦ +5 Data" lbl.TextColor3=col lbl.TextSize=14 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.2 lbl.TextStrokeColor3=Color3.fromRGB(0,0,0) lbl.Parent=bb
    -- Prompt
    local p=Instance.new("ProximityPrompt") p.ActionText="Collect" p.ObjectText="Data Orb" p.HoldDuration=0.3 p.MaxActivationDistance=14 p.Parent=shell
end

-- 4 rings of data orbs
for i=1,8 do local a=(i/8)*math.pi*2 DataOrb(math.cos(a)*55,6,math.sin(a)*55,BrickColor.new("Cyan")) end
for i=1,10 do local a=(i/10)*math.pi*2+0.3 DataOrb(math.cos(a)*90,8,math.sin(a)*90,BrickColor.new("Bright blue")) end
for i=1,12 do local a=(i/12)*math.pi*2+0.15 DataOrb(math.cos(a)*130,10,math.sin(a)*130,BrickColor.new("Bright violet")) end
for i=1,10 do local a=(i/12)*math.pi*2 DataOrb(math.cos(a)*175,12,math.sin(a)*175,BrickColor.new("Bright yellow")) end

print("DataTycoon: Data orbs done")

-- ============================================================
-- EXTRA NATURE (fill the world)
-- ============================================================
local nature=Instance.new("Folder") nature.Name="Nature" nature.Parent=workspace

-- Forest clusters at far corners
for _,fc in ipairs({{-220,-220},{220,-220},{-220,220},{220,220}}) do
    for i=1,8 do Tree(fc[1]+R(-25,25),fc[2]+R(-25,25),0.6+R()*0.5) end
    for i=1,4 do Bush(fc[1]+R(-30,30),fc[2]+R(-30,30),0.7+R()*0.5) end
    for i=1,3 do Rock(fc[1]+R(-20,20),fc[2]+R(-20,20),0.5+R()*0.8) end
end

-- Scattered trees everywhere
for i=1,40 do
    local tx,tz=R(-250,250),R(-250,250)
    if math.abs(tx)>45 or math.abs(tz)>45 then Tree(tx,tz,0.5+R()*0.6) end
end

-- Bushes, flowers, rocks
for i=1,60 do Bush(R(-250,250),R(-250,250),0.4+R()*0.6) end
for i=1,120 do Flower(R(-250,250),R(-250,250)) end
for i=1,25 do Rock(R(-240,240),R(-240,240),0.4+R()*1.0) end

print("DataTycoon: Nature done")

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
-- LIGHTING
-- ============================================================
local lt=game:GetService("Lighting")
lt.Ambient=Color3.fromRGB(80,80,100)
lt.OutdoorAmbient=Color3.fromRGB(100,100,120)
lt.Brightness=2.5
lt.ClockTime=14
lt.FogEnd=800
lt.FogColor=Color3.fromRGB(160,180,210)
lt.GlobalShadows=true
lt.ShadowSoftness=0.3

local bloom=Instance.new("BloomEffect") bloom.Intensity=0.4 bloom.Size=30 bloom.Threshold=0.8 bloom.Parent=lt
local cc=Instance.new("ColorCorrectionEffect") cc.Brightness=0.02 cc.Contrast=0.05 cc.Saturation=0.15 cc.TintColor=Color3.fromRGB(220,230,255) cc.Parent=lt
local sunrays=Instance.new("SunRaysEffect") sunrays.Intensity=0.15 sunrays.Spread=0.8 sunrays.Parent=lt
local atmos=Instance.new("Atmosphere") atmos.Density=0.3 atmos.Offset=0.1 atmos.Color=Color3.fromRGB(180,200,230) atmos.Decay=0.95 atmos.Glare=0.2 atmos.Haze=2 atmos.Parent=lt

local sky=Instance.new("Sky")
sky.SkyboxBk="rbxassetid://1007059817" sky.SkyboxDn="rbxassetid://1007060023"
sky.SkyboxFt="rbxassetid://1007059817" sky.SkyboxLf="rbxassetid://1007059817"
sky.SkyboxRt="rbxassetid://1007059817" sky.SkyboxUp="rbxassetid://1007060023"
sky.Parent=lt

print("DataTycoon: Lighting done")

workspace.Gravity=196.2
workspace.FallenPartsDestroyHeight=-500

print("DataTycoon: WORLD COMPLETE!")
