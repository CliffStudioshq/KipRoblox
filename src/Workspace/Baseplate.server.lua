--[[
    Baseplate.server.lua — DataTycoon World
    v0.16 — Touch-to-collect data orbs, lush nature, better flowers, fauna
]]

local R = math.random

local function P(props)
    local p = Instance.new("Part")
    p.Name = props.n or "Part"
    p.Size = props.s or Vector3.new(4,4,4)
    p.Position = props.p or Vector3.new(0,0,0)
    p.Anchored = true
    p.BrickColor = props.c or BrickColor.new("Medium stone grey")
    p.Material = props.m or Enum.Material.SmoothPlastic
    p.Transparency = props.a or 0
    p.Shape = props.sh or Enum.PartType.Block
    p.CanCollide = props.co ~= nil and props.co or true
    p.Parent = props.pa or workspace
    if props.r then p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0,math.rad(props.r),0) end
    return p
end

local function Tree(x,z,s)
    s = s or 1
    P({n="Trunk",s=Vector3.new(2.5*s,10*s,2.5*s),p=Vector3.new(x,5*s,z),c=BrickColor.new("Brown"),m=Enum.Material.Wood})
    P({n="C1",s=Vector3.new(14*s,10*s,14*s),p=Vector3.new(x,13*s,z),c=BrickColor.new("Dark green"),m=Enum.Material.Grass,sh=Enum.PartType.Ball})
    P({n="C2",s=Vector3.new(10*s,7*s,10*s),p=Vector3.new(x+2*s,17*s,z+1*s),c=BrickColor.new("Earth green"),m=Enum.Material.Grass,sh=Enum.PartType.Ball})
    P({n="C3",s=Vector3.new(7*s,5*s,7*s),p=Vector3.new(x-1*s,20*s,z-2*s),c=BrickColor.new("Forest green"),m=Enum.Material.Grass,sh=Enum.PartType.Ball})
end

local function Lamp(x,z,col)
    col = col or Color3.fromRGB(255,240,200)
    P({n="LPole",s=Vector3.new(0.5,8,0.5),p=Vector3.new(x,4,z),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Metal})
    P({n="LHead",s=Vector3.new(1.5,0.5,1.5),p=Vector3.new(x,8.2,z),c=BrickColor.new("Institutional white"),m=Enum.Material.SmoothPlastic})
    local a = P({n="LA",s=Vector3.new(0.1,0.1,0.1),p=Vector3.new(x,8.2,z),a=1,co=false})
    local l = Instance.new("PointLight") l.Color=col l.Brightness=1.5 l.Range=20 l.Parent=a
end

local function Bush(x,z,s)
    s = s or 1
    for i=1,4 do P({n="Bush",s=Vector3.new(3*s,2.5*s,3*s),p=Vector3.new(x+R(-2,2),1.25*s,z+R(-2,2)),c=BrickColor.new("Dark green"),m=Enum.Material.Grass,sh=Enum.PartType.Ball}) end
end

-- Better flower: multi-petal sphere cluster instead of lollipop
local function Flower(x,z)
    local colors = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Bright blue","Hot pink","Lavender","Magenta","Pastel yellow","Pastel blue"}
    local col = BrickColor.new(colors[R(#colors)])
    -- Small stem
    P({n="Stem",s=Vector3.new(0.2,1,0.2),p=Vector3.new(x,0.5,z),c=BrickColor.new("Dark green"),m=Enum.Material.Grass})
    -- Petal cluster (multiple small spheres around center)
    P({n="Center",s=Vector3.new(0.6,0.6,0.6),p=Vector3.new(x,1.3,z),c=col,m=Enum.Material.SmoothPlastic,sh=Enum.PartType.Ball})
    for i=1,5 do
        local a=(i/5)*math.pi*2
        P({n="Petal",s=Vector3.new(0.4,0.3,0.4),p=Vector3.new(x+math.cos(a)*0.4,1.2,z+math.sin(a)*0.4),c=col,m=Enum.Material.SmoothPlastic,sh=Enum.PartType.Ball})
    end
end

local function Rock(x,z,s)
    s = s or 1
    P({n="Rock",s=Vector3.new(3*s,2*s,3*s),p=Vector3.new(x,1*s,z),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Slate,sh=Enum.PartType.Ball})
end

local function Bench(x,z,rot)
    P({n="BenchSeat",s=Vector3.new(6,0.5,2),p=Vector3.new(x,2.5,z),c=BrickColor.new("Brown"),m=Enum.Material.Wood,r=rot})
    P({n="BenchBack",s=Vector3.new(6,3,0.5),p=Vector3.new(x,4.5,z+0.75),c=BrickColor.new("Brown"),m=Enum.Material.Wood,r=rot})
    P({n="BenchLeg",s=Vector3.new(0.5,2,0.5),p=Vector3.new(x-2.2,1,z),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Metal})
    P({n="BenchLeg",s=Vector3.new(0.5,2,0.5),p=Vector3.new(x+2.2,1,z),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Metal})
end

-- Data Orb: bright, glowing, touch-to-collect
local function DataOrb(cx,cy,cz,col)
    -- Outer glow ring (collidable, on ground)
    local ring = P({n="DataRing",s=Vector3.new(10,1,10),p=Vector3.new(cx,cy-0.5,cz),c=col,m=Enum.Material.Neon,a=0.3,sh=Enum.PartType.Cylinder})
    ring.CFrame = CFrame.new(cx,cy-0.5,cz) * CFrame.Angles(0,0,math.rad(90))
    
    -- Main orb (visible, non-collidable)
    local orb = P({n="DataOrb",s=Vector3.new(4,4,4),p=Vector3.new(cx,cy,cz),c=col,m=Enum.Material.Neon,a=0.15,sh=Enum.PartType.Ball,co=false})
    
    -- Inner bright core
    P({n="DataCore",s=Vector3.new(2,2,2),p=Vector3.new(cx,cy,cz),c=BrickColor.new("Institutional white"),m=Enum.Material.Neon,a=0.1,sh=Enum.PartType.Ball,co=false})
    
    -- Point light (bright glow)
    local a = P({n="DataLight",s=Vector3.new(0.1,0.1,0.1),p=Vector3.new(cx,cy+2,cz),a=1,co=false})
    local l = Instance.new("PointLight") l.Color=col l.Brightness=3 l.Range=20 l.Parent=a
    
    -- Star spikes (4, glowing)
    for i=1,4 do
        local a2=(i/4)*math.pi*2
        P({n="Spike",s=Vector3.new(0.4,5,0.4),p=Vector3.new(cx+math.cos(a2)*3.5,cy,cz+math.sin(a2)*3.5),c=col,m=Enum.Material.Neon,a=0.25,r=math.deg(-a2),co=false})
    end
    
    -- Billboard (always visible)
    local bb = Instance.new("BillboardGui") bb.Size=UDim2.new(0,140,0,40) bb.StudsOffset=Vector3.new(0,5,0) bb.AlwaysOnTop=true bb.Parent=orb
    local lbl = Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0.6,0) lbl.BackgroundTransparency=1 lbl.Text="✦ +5 Data" lbl.TextColor3=col lbl.TextSize=16 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.1 lbl.TextStrokeColor3=Color3.fromRGB(0,0,0) lbl.Parent=bb
    local lbl2 = Instance.new("TextLabel") lbl2.Size=UDim2.new(1,0,0.4,0) lbl2.Position=UDim2.new(0,0,0.6,0) lbl2.BackgroundTransparency=1 lbl2.Text="Walk to collect" lbl2.TextColor3=Color3.fromRGB(255,255,255) lbl2.TextSize=11 lbl2.Font=Enum.Font.GothamBold lbl2.TextStrokeTransparency=0.3 lbl2.Parent=bb
end

-- Butterfly (floating, decorative)
local function Butterfly(x,z,col)
    local b = P({n="Butterfly",s=Vector3.new(1,0.3,1.5),p=Vector3.new(x,4+R()*3,z),c=col,m=Enum.Material.SmoothPlastic,sh=Enum.PartType.Ball,a=0.3,co=false})
    local a = P({n="BFLight",s=Vector3.new(0.1,0.1,0.1),p=Vector3.new(x,4+R()*3,z),a=1,co=false})
    local l = Instance.new("PointLight") l.Color=col l.Brightness=0.5 l.Range=6 l.Parent=a
end

-- ============================================================
-- CONFIG
-- ============================================================
local PLOTS = {{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
local PLOT_SIZE = 120
local PLOT_SPACING = 170

-- ============================================================
-- BASEPLATE
-- ============================================================
P({n="Baseplate",s=Vector3.new(512,4,512),p=Vector3.new(0,-2,0),c=BrickColor.new("Dark green"),m=Enum.Material.Grass})
P({n="Spawn",s=Vector3.new(14,3,14),p=Vector3.new(0,1.5,0),c=BrickColor.new("Bright green"),m=Enum.Material.SmoothPlastic})

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation" spawn.Size=Vector3.new(10,1,10) spawn.Position=Vector3.new(0,3.5,0)
spawn.Anchored=true spawn.CanCollide=false spawn.Transparency=1 spawn.Parent=workspace

print("Baseplate done")

-- ============================================================
-- CENTER: DATA HUB
-- ============================================================
local hub=Instance.new("Folder") hub.Name="DataHub" hub.Parent=workspace

P({n="Platform",s=Vector3.new(80,3,80),p=Vector3.new(0,1.5,0),c=BrickColor.new("Dark stone grey"),m=Enum.Material.SmoothPlastic,pa=hub})
P({n="Ring",s=Vector3.new(50,0.3,50),p=Vector3.new(0,3.0,0),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=hub})

for f=0,4 do
    local y=4+f*8 local sz=22-f*2
    P({n="TF"..f,s=Vector3.new(sz,7,sz),p=Vector3.new(0,y,0),c=BrickColor.new(f%2==0 and "Dark stone grey" or "Medium stone grey"),m=Enum.Material.Metal,pa=hub})
    P({n="TL"..f,s=Vector3.new(sz+0.5,0.15,sz+0.5),p=Vector3.new(0,y-3.3,0),c=BrickColor.new("Cyan"),m=Enum.Material.SmoothPlastic,pa=hub})
end

for i=1,8 do
    local a=(i/8)*math.pi*2 local x,z=math.cos(a)*28,math.sin(a)*28
    P({n="R"..i,s=Vector3.new(6,12,3),p=Vector3.new(x,7,z),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Metal,pa=hub})
    for l=0,3 do P({n="LED"..i..l,s=Vector3.new(0.4,0.25,0.4),p=Vector3.new(x,3+l*2.5,z+1.6),c=BrickColor.new(l%2==0 and "Lime green" or "Forest green"),m=Enum.Material.SmoothPlastic,pa=hub}) end
end

for i=1,6 do
    local a=(i/6)*math.pi*2 local px,pz=math.cos(a)*18,math.sin(a)*18
    P({n="P"..i,s=Vector3.new(3,22,3),p=Vector3.new(px,12,pz),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=hub})
    P({n="PT"..i,s=Vector3.new(3.5,0.4,3.5),p=Vector3.new(px,1.2,pz),c=BrickColor.new("Cyan"),m=Enum.Material.SmoothPlastic,pa=hub})
end

for i=1,10 do
    local a=(i/10)*math.pi*2 local r=12+(i%3)*4
    P({n="O"..i,s=Vector3.new(2,2,2),p=Vector3.new(math.cos(a)*r,26+math.sin(i)*2,math.sin(a)*r),c=BrickColor.new(i%2==0 and "Cyan" or "Bright blue"),m=Enum.Material.SmoothPlastic,sh=Enum.PartType.Ball,pa=hub})
end

for i=1,4 do
    local a=(i/4)*math.pi*2 local x,z=math.cos(a)*42,math.sin(a)*42
    P({n="AP"..i,s=Vector3.new(3,16,3),p=Vector3.new(x,9,z),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=hub})
    P({n="AT"..i,s=Vector3.new(3,2,10),p=Vector3.new(x,18,z),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=hub})
    P({n="AA"..i,s=Vector3.new(3.2,0.2,10.2),p=Vector3.new(x,19.1,z),c=BrickColor.new("Cyan"),m=Enum.Material.SmoothPlastic,pa=hub})
end

for i=1,8 do local a=(i/8)*math.pi*2 Lamp(math.cos(a)*35,math.sin(a)*35,Color3.fromRGB(100,200,255)) end

print("Hub done")

-- ============================================================
-- WALKWAYS (4 cardinal, lush)
-- ============================================================
local walks=Instance.new("Folder") walks.Name="Walkways" walks.Parent=workspace
local wC=BrickColor.new("Medium stone grey") local wM=Enum.Material.Concrete local wW=8

for _,d in ipairs{{0,1},{0,-1},{1,0},{-1,0}} do
    local dx,dz=d[1],d[2] local mx,mz=dx*157.5,dz*157.5
    if dx~=0 then P({n="W",s=Vector3.new(230,0.3,wW),p=Vector3.new(mx,0.15,mz),c=wC,m=wM,pa=walks})
    else P({n="W",s=Vector3.new(wW,0.3,230),p=Vector3.new(mx,0.15,mz),c=wC,m=wM,pa=walks}) end
    
    for dist=50,260,15 do
        local tx,tz=dx*dist,dz*dist
        if dx==0 then Tree(tx+10,tz,0.5+R()*0.3) Tree(tx-10,tz,0.5+R()*0.3)
        else Tree(tx,tz+10,0.5+R()*0.3) Tree(tx,tz-10,0.5+R()*0.3) end
        if dist%30==0 then Bush(tx+(dx==0 and 15 or 0),tz+(dz==0 and 15 or 0),0.5) end
        if dist%45==0 then Flower(tx+(dx==0 and 12 or R(-5,5)),tz+(dz==0 and 12 or R(-5,5))) end
    end
    
    for dist=60,260,25 do
        local lx,lz=dx*dist,dz*dist
        if dx==0 then Lamp(lx+9,lz) Lamp(lx-9,lz)
        else Lamp(lx,lz+9) Lamp(lx,lz-9) end
    end
    
    for dist=90,220,50 do
        local bx,bz=dx*dist,dz*dist
        if dx==0 then Bench(bx+12,bz,0) Bench(bx-12,bz,0)
        else Bench(bx,bz+12,90) Bench(bx,bz-12,90) end
    end
end

print("Walkways done")

-- ============================================================
-- PLAYER PLOTS (8 big)
-- ============================================================
local plots=Instance.new("Folder") plots.Name="PlotMarkers" plots.Parent=workspace
local plotCount=0

for _,pp in ipairs(PLOTS) do
    local x,z=pp[1],pp[2]
    local dist=math.max(math.abs(x),math.abs(z))
    local cx,cz=x*PLOT_SPACING,z*PLOT_SPACING
    local price=math.floor(50*(2^dist))
    
    P({n="Plot_"..x.."_"..z,s=Vector3.new(PLOT_SIZE-4,0.6,PLOT_SIZE-4),p=Vector3.new(cx,0.3,cz),c=BrickColor.new("Dark green"),m=Enum.Material.SmoothPlastic,pa=plots})
    
    for _,c in ipairs({{55,55},{-55,55},{55,-55},{-55,-55}}) do
        P({n="Post",s=Vector3.new(1.2,5,1.2),p=Vector3.new(cx+c[1],3,cz+c[2]),c=BrickColor.new("Dark stone grey"),m=Enum.Material.SmoothPlastic,pa=plots})
    end
    
    local edge=PLOT_SIZE/2
    if math.abs(x)>=3 then P({n="Fence",s=Vector3.new(0.5,3,PLOT_SIZE-6),p=Vector3.new(cx+(x>0 and edge or -edge),2,cz),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Wood,pa=plots}) end
    if math.abs(z)>=3 then P({n="Fence",s=Vector3.new(PLOT_SIZE-6,3,0.5),p=Vector3.new(cx,2,cz+(z>0 and edge or -edge)),c=BrickColor.new("Dark stone grey"),m=Enum.Material.Wood,pa=plots}) end
    
    local angle=math.atan2(cz,cx) local roadR=265
    local nx,nz=math.cos(angle)*roadR,math.sin(angle)*roadR
    local mx,mz=(nx+cx)/2,(nz+cz)/2
    local ddx,ddz=cx-nx,cz-nz
    local len=math.sqrt(ddx*ddx+ddz*ddz)
    local rot=math.deg(math.atan2(ddz,ddx))
    P({n="PW_"..x.."_"..z,s=Vector3.new(len,0.3,wW),p=Vector3.new(mx,0.15,mz),c=wC,m=wM,r=rot,pa=walks})
    
    P({n="Sign",s=Vector3.new(0.6,6,0.6),p=Vector3.new(cx,3.5,cz),c=BrickColor.new("Dark stone grey"),m=Enum.Material.SmoothPlastic,pa=plots})
    P({n="SignB",s=Vector3.new(8,4,0.3),p=Vector3.new(cx,7.5,cz),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=plots})
    
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,150,0,80) bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=false
    bb.Parent=P({n="SD",s=Vector3.new(0.1,0.1,0.1),p=Vector3.new(cx,9.5,cz),a=1,co=false,pa=plots})
    local t1=Instance.new("TextLabel") t1.Size=UDim2.new(1,0,0.22,0) t1.BackgroundTransparency=1 t1.Text="("..x..", "..z..")" t1.TextColor3=Color3.fromRGB(200,200,200) t1.TextSize=12 t1.Font=Enum.Font.GothamBold t1.TextStrokeTransparency=0.5 t1.Parent=bb
    local t2=Instance.new("TextLabel") t2.Size=UDim2.new(1,0,0.35,0) t2.Position=UDim2.new(0,0,0.22,0) t2.BackgroundTransparency=1 t2.Text="💰 "..price t2.TextColor3=Color3.fromRGB(255,220,100) t2.TextSize=15 t2.Font=Enum.Font.GothamBold t2.TextStrokeTransparency=0.4 t2.Parent=bb
    local t3=Instance.new("TextLabel") t3.Size=UDim2.new(1,0,0.23,0) t3.Position=UDim2.new(0,0,0.57,0) t3.BackgroundTransparency=1 t3.Text="🌿 PRIVATE" t3.TextColor3=Color3.fromRGB(100,255,150) t3.TextSize=11 t3.Font=Enum.Font.GothamBold t3.TextStrokeTransparency=0.5 t3.Parent=bb
    
    Bush(cx+35,cz+35,0.9) Bush(cx-30,cz-30,0.7) Bush(cx+20,cz-40,0.6) Bush(cx-40,cz+20,0.5)
    Tree(cx+40,cz-35,0.8) Tree(cx-35,cz+30,0.6)
    if (x+z)%2==0 then Tree(cx+20,cz+40,0.5) end
    Rock(cx-40,cz-40,0.7) Rock(cx+35,cz-10,0.4)
    for i=1,20 do Flower(cx+R(-50,50),cz+R(-50,50)) end
    
    plotCount=plotCount+1
end

print(plotCount.." plots done")

-- ============================================================
-- DATA ORBS (touch to collect, very visible)
-- ============================================================
local blocks=Instance.new("Folder") blocks.Name="CollectibleBlocks" blocks.Parent=workspace

-- Ring 1: Cyan (near hub)
for i=1,10 do local a=(i/10)*math.pi*2 DataOrb(math.cos(a)*55,6,math.sin(a)*55,BrickColor.new("Cyan")) end
-- Ring 2: Blue
for i=1,12 do local a=(i/12)*math.pi*2+0.3 DataOrb(math.cos(a)*90,8,math.sin(a)*90,BrickColor.new("Bright blue")) end
-- Ring 3: Purple
for i=1,14 do local a=(i/14)*math.pi*2+0.15 DataOrb(math.cos(a)*130,10,math.sin(a)*130,BrickColor.new("Bright violet")) end
-- Ring 4: Gold (far)
for i=1,12 do local a=(i/12)*math.pi*2 DataOrb(math.cos(a)*175,12,math.sin(a)*175,BrickColor.new("Bright yellow")) end

print("Data orbs done")

-- ============================================================
-- NATURE (abundant, spread throughout)
-- ============================================================
local nature=Instance.new("Folder") nature.Name="Nature" nature.Parent=workspace

-- Forest clusters at far corners
for _,fc in ipairs({{-220,-220},{220,-220},{-220,220},{220,220}}) do
    for i=1,10 do Tree(fc[1]+R(-30,30),fc[2]+R(-30,30),0.6+R()*0.5) end
    for i=1,5 do Bush(fc[1]+R(-35,35),fc[2]+R(-35,35),0.7+R()*0.5) end
    for i=1,4 do Rock(fc[1]+R(-25,25),fc[2]+R(-25,25),0.5+R()*0.8) end
    for i=1,8 do Flower(fc[1]+R(-35,35),fc[2]+R(-35,35)) end
end

-- Scattered trees throughout the world
for i=1,50 do
    local tx,tz=R(-250,250),R(-250,250)
    if math.abs(tx)>40 or math.abs(tz)>40 then Tree(tx,tz,0.5+R()*0.6) end
end

-- Bushes everywhere
for i=1,80 do Bush(R(-250,250),R(-250,250),0.4+R()*0.6) end

-- Flowers everywhere
for i=1,200 do Flower(R(-250,250),R(-250,250)) end

-- Rocks scattered
for i=1,35 do Rock(R(-240,240),R(-240,240),0.4+R()*1.0) end

-- Butterflies (fauna!)
local bflyColors = {BrickColor.new("Bright yellow"),BrickColor.new("Bright blue"),BrickColor.new("Bright violet"),BrickColor.new("Bright orange"),BrickColor.new("Pink"),BrickColor.new("Cyan")}
for i=1,30 do
    local bx,bz=R(-230,230),R(-230,230)
    Butterfly(bx,bz,bflyColors[R(#bflyColors)])
end

print("Nature + fauna done")

-- ============================================================
-- WATER
-- ============================================================
local water=Instance.new("Folder") water.Name="Water" water.Parent=workspace
local pond=P({n="Pond",s=Vector3.new(28,0.5,18),p=Vector3.new(58,0.2,58),c=BrickColor.new("Bright blue"),m=Enum.Material.Glass,sh=Enum.PartType.Cylinder})
pond.CFrame=CFrame.new(58,0.2,58)*CFrame.Angles(0,0,math.rad(90))
for i=1,10 do local a=(i/10)*math.pi*2 Rock(58+math.cos(a)*15,58+math.sin(a)*10,0.3+R()*0.3) end
for i=1,6 do P({n="Stream",s=Vector3.new(4,0.3,4),p=Vector3.new(58+i*7,0.15,58+i*5),c=BrickColor.new("Bright blue"),m=Enum.Material.Glass,pa=water}) end

local pond2=P({n="Pond2",s=Vector3.new(16,0.5,12),p=Vector3.new(-55,0.2,-55),c=BrickColor.new("Bright blue"),m=Enum.Material.Glass,sh=Enum.PartType.Cylinder})
pond2.CFrame=CFrame.new(-55,0.2,-55)*CFrame.Angles(0,0,math.rad(90))
for i=1,6 do Rock(-55+math.cos((i/6)*math.pi*2)*9,-55+math.sin((i/6)*math.pi*2)*7,0.3) end

print("Water done")

-- ============================================================
-- BUILDINGS
-- ============================================================
local builds=Instance.new("Folder") builds.Name="Buildings" builds.Parent=workspace
for _,bp in ipairs({{62,-62,"Data Store"},{-62,62,"Tech Shop"},{-62,-62,"Server Farm"},{62,62,"Mining Co"}}) do
    P({n="B_"..bp[3],s=Vector3.new(14,11,14),p=Vector3.new(bp[1],6,bp[2]),c=BrickColor.new("Medium stone grey"),m=Enum.Material.SmoothPlastic,pa=builds})
    P({n="R_"..bp[3],s=Vector3.new(16,1,16),p=Vector3.new(bp[1],12,bp[2]),c=BrickColor.new("Dark stone grey"),m=Enum.Material.SmoothPlastic,pa=builds})
    local sb=P({n="S_"..bp[3],s=Vector3.new(10,2,0.3),p=Vector3.new(bp[1],10,bp[2]+7.2),c=BrickColor.new("Bright blue"),m=Enum.Material.SmoothPlastic,pa=builds})
    local bb=Instance.new("BillboardGui") bb.Size=UDim2.new(0,100,0,25) bb.StudsOffset=Vector3.new(0,1.5,0) bb.AlwaysOnTop=true bb.Parent=sb
    local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1 lbl.Text="🏪 "..bp[3] lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.TextSize=13 lbl.Font=Enum.Font.GothamBold lbl.TextStrokeTransparency=0.3 lbl.Parent=bb
end

print("Buildings done")

-- ============================================================
-- LIGHTING
-- ============================================================
local lt=game:GetService("Lighting")
lt.Ambient=Color3.fromRGB(90,90,110)
lt.OutdoorAmbient=Color3.fromRGB(110,110,130)
lt.Brightness=2.5
lt.ClockTime=14
lt.FogEnd=1000
lt.FogColor=Color3.fromRGB(170,190,220)
lt.GlobalShadows=true
lt.ShadowSoftness=0.3

local bloom=Instance.new("BloomEffect") bloom.Intensity=0.5 bloom.Size=35 bloom.Threshold=0.7 bloom.Parent=lt
local cc=Instance.new("ColorCorrectionEffect") cc.Brightness=0.03 cc.Contrast=0.08 cc.Saturation=0.2 cc.TintColor=Color3.fromRGB(210,225,255) cc.Parent=lt
local sunrays=Instance.new("SunRaysEffect") sunrays.Intensity=0.2 sunrays.Spread=0.9 sunrays.Parent=lt
local atmos=Instance.new("Atmosphere") atmos.Density=0.25 atmos.Offset=0.1 atmos.Color=Color3.fromRGB(180,200,230) atmos.Decay=0.95 atmos.Glare=0.3 atmos.Haze=1.5 atmos.Parent=lt

local sky=Instance.new("Sky")
sky.SkyboxBk="rbxassetid://1007059817" sky.SkyboxDn="rbxassetid://1007060023"
sky.SkyboxFt="rbxassetid://1007059817" sky.SkyboxLf="rbxassetid://1007059817"
sky.SkyboxRt="rbxassetid://1007059817" sky.SkyboxUp="rbxassetid://1007060023"
sky.Parent=lt

print("Lighting done")

workspace.Gravity=196.2
workspace.FallenPartsDestroyHeight=-500

print("WORLD COMPLETE!")
