--[[
    WorldBuilder.server.lua — DataTycoon
    Dedicated world builder — runs in its own script context, own budget.
    Each section wrapped in pcall so errors print instead of silently dying.
]]

print("[WORLD] WorldBuilder starting...")

local PI = math.pi
local R  = math.random

-- ============================================================
-- PART FACTORY
-- ============================================================
local function P(props)
    local p = Instance.new("Part")
    p.Anchored    = true
    p.Name        = props.name   or "Part"
    p.Size        = props.size   or Vector3.new(4, 4, 4)
    p.Position    = props.pos    or Vector3.new(0, 0, 0)
    p.BrickColor  = props.color  or BrickColor.new("Medium stone grey")
    p.Material    = props.mat    or Enum.Material.SmoothPlastic
    p.Transparency = props.alpha or 0
    p.Shape       = props.shape  or Enum.PartType.Block
    if props.collide ~= nil then
        p.CanCollide = props.collide
    else
        p.CanCollide = true
    end
    p.Parent = props.parent or workspace
    if props.rot then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.rot), 0)
    end
    return p
end

local function Light(pos, color3, brightness, range, parent)
    local l = Instance.new("PointLight")
    l.Color      = color3
    l.Brightness = brightness
    l.Range      = range
    l.Parent     = parent or workspace
end

-- ============================================================
-- HELPERS
-- ============================================================
local function Tree(x, z, s, folder)
    s = s or 1
    P({name="Trunk",    size=Vector3.new(2.5*s,10*s,2.5*s), pos=Vector3.new(x,5*s,z),       color=BrickColor.new("Brown"),        mat=Enum.Material.Wood,  parent=folder})
    P({name="Canopy1",  size=Vector3.new(14*s,10*s,14*s),   pos=Vector3.new(x,13*s,z),       color=BrickColor.new("Dark green"),   mat=Enum.Material.Grass, shape=Enum.PartType.Ball, collide=false, parent=folder})
    P({name="Canopy2",  size=Vector3.new(10*s,7*s,10*s),    pos=Vector3.new(x+2*s,17*s,z+s), color=BrickColor.new("Earth green"),  mat=Enum.Material.Grass, shape=Enum.PartType.Ball, collide=false, parent=folder})
end

local function Bush(x, z, s, folder)
    s = s or 1
    for i = 1, 3 do
        P({name="Bush", size=Vector3.new(3*s,2.5*s,3*s), pos=Vector3.new(x+R(-2,2),1.2*s,z+R(-2,2)), color=BrickColor.new("Dark green"), mat=Enum.Material.Grass, shape=Enum.PartType.Ball, collide=false, parent=folder})
    end
end

local function Flower(x, z, folder)
    local palette = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Hot pink"}
    local col = BrickColor.new(palette[R(#palette)])
    P({name="FStem",   size=Vector3.new(0.3,1.2,0.3), pos=Vector3.new(x,0.6,z),   color=BrickColor.new("Dark green"), mat=Enum.Material.Grass, collide=false, parent=folder})
    P({name="FCenter", size=Vector3.new(0.8,0.8,0.8), pos=Vector3.new(x,1.5,z),   color=col, mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=folder})
    for i = 1, 5 do
        local a = (i/5)*PI*2
        P({name="FPetal", size=Vector3.new(0.5,0.4,0.5), pos=Vector3.new(x+math.cos(a)*0.55,1.4,z+math.sin(a)*0.55), color=col, mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=folder})
    end
end

local function Rock(x, z, s, folder)
    s = s or 1
    P({name="Rock", size=Vector3.new(3*s,2*s,3*s), pos=Vector3.new(x,s,z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, shape=Enum.PartType.Ball, collide=true, parent=folder})
end

local function Lamp(x, z, folder)
    P({name="LPole", size=Vector3.new(0.5,8,0.5),   pos=Vector3.new(x,4,z),   color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal,         parent=folder})
    P({name="LHead", size=Vector3.new(1.5,0.5,1.5), pos=Vector3.new(x,8.2,z), color=BrickColor.new("Institutional white"), mat=Enum.Material.Neon, parent=folder})
end

local function Orb(cx, cy, cz, brickCol, folder)
    -- Ring on ground (collidable — triggers Touched)
    local ring = P({name="OrbRing", size=Vector3.new(10,4,10), pos=Vector3.new(cx,2,cz), color=brickCol, mat=Enum.Material.Neon, shape=Enum.PartType.Cylinder, collide=true, parent=folder})
    ring.CFrame = CFrame.new(cx, 1.5, cz) * CFrame.Angles(0, 0, math.rad(90))
    -- Sphere (visual, Neon = glows without PointLight)
    P({name="OrbSphere", size=Vector3.new(4,4,4), pos=Vector3.new(cx,cy,cz), color=brickCol, mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
    P({name="OrbCore",   size=Vector3.new(2,2,2), pos=Vector3.new(cx,cy,cz), color=BrickColor.new("Institutional white"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
    -- Billboard label
    local anchor = P({name="OrbBB", size=Vector3.new(0.1,0.1,0.1), pos=Vector3.new(cx,cy+3,cz), alpha=1, collide=false, parent=folder})
    local bb = Instance.new("BillboardGui"); bb.Size=UDim2.new(0,130,0,36); bb.StudsOffset=Vector3.new(0,4,0); bb.AlwaysOnTop=true; bb.Parent=anchor
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text="✦ +5 Data"; lbl.TextColor3=brickCol.Color; lbl.TextSize=15; lbl.Font=Enum.Font.GothamBold
    lbl.TextStrokeTransparency=0.1; lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.Parent=bb
end

-- ============================================================
-- SECTION: LIGHTING  (no instances created, just service props)
-- ============================================================
local ok, err = pcall(function()
    local lt = game:GetService("Lighting")
    lt.Ambient        = Color3.fromRGB(90,90,110)
    lt.OutdoorAmbient = Color3.fromRGB(110,110,130)
    lt.Brightness     = 2.5
    lt.ClockTime      = 14
    lt.FogEnd         = 1000
    lt.FogColor       = Color3.fromRGB(170,190,220)
    lt.GlobalShadows  = true
    local bloom=Instance.new("BloomEffect"); bloom.Intensity=0.5; bloom.Size=35; bloom.Threshold=0.7; bloom.Parent=lt
    local cc=Instance.new("ColorCorrectionEffect"); cc.Brightness=0.03; cc.Contrast=0.08; cc.Saturation=0.2; cc.TintColor=Color3.fromRGB(210,225,255); cc.Parent=lt
    local sr=Instance.new("SunRaysEffect"); sr.Intensity=0.2; sr.Spread=0.9; sr.Parent=lt
    local atm=Instance.new("Atmosphere"); atm.Density=0.25; atm.Offset=0.1; atm.Color=Color3.fromRGB(180,200,230); atm.Decay=0.95; atm.Glare=0.3; atm.Haze=1.5; atm.Parent=lt
end)
if not ok then warn("[WORLD] Lighting error: "..tostring(err)) end
print("[WORLD] Lighting done")
task.wait()

-- ============================================================
-- SECTION: HUB
-- ============================================================
ok, err = pcall(function()
    local hub = Instance.new("Folder"); hub.Name="DataHub"; hub.Parent=workspace
    P({name="HubPlatform", size=Vector3.new(80,3,80),   pos=Vector3.new(0,1.5,0), color=BrickColor.new("Dark stone grey"),   mat=Enum.Material.SmoothPlastic, parent=hub})
    P({name="HubRing",     size=Vector3.new(50,0.3,50), pos=Vector3.new(0,3,0),   color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    for f=0,4 do
        local y=4+f*8; local sz=22-f*2
        local col = f%2==0 and BrickColor.new("Dark stone grey") or BrickColor.new("Medium stone grey")
        P({name="TowerFloor"..f, size=Vector3.new(sz,7,sz),        pos=Vector3.new(0,y,0),      color=col,                           mat=Enum.Material.Metal,         parent=hub})
        P({name="TowerTrim"..f,  size=Vector3.new(sz+0.5,0.15,sz+0.5), pos=Vector3.new(0,y-3.3,0), color=BrickColor.new("Cyan"),    mat=Enum.Material.Neon,          parent=hub})
    end
    for i=1,8 do
        local a=(i/8)*PI*2; local x,z=math.cos(a)*28,math.sin(a)*28
        P({name="Rack"..i, size=Vector3.new(6,12,3), pos=Vector3.new(x,7,z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, parent=hub})
    end
    for i=1,4 do
        local a=(i/4)*PI*2; local x,z=math.cos(a)*42,math.sin(a)*42
        P({name="ArchPost"..i, size=Vector3.new(3,16,3),    pos=Vector3.new(x,9,z),    color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
        P({name="ArchTop"..i,  size=Vector3.new(3,2,10),    pos=Vector3.new(x,18,z),   color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
        P({name="ArchGlow"..i, size=Vector3.new(3.2,0.2,10.2), pos=Vector3.new(x,19.1,z), color=BrickColor.new("Cyan"),          mat=Enum.Material.Neon,          parent=hub})
    end
    for i=1,8 do
        local a=(i/8)*PI*2
        Lamp(math.cos(a)*35, math.sin(a)*35, hub)
    end
end)
if not ok then warn("[WORLD] Hub error: "..tostring(err)) end
print("[WORLD] Hub done")
task.wait()

-- ============================================================
-- SECTION: WALKWAYS
-- ============================================================
ok, err = pcall(function()
    local walk = Instance.new("Folder"); walk.Name="Walkways"; walk.Parent=workspace
    local wC=BrickColor.new("Medium stone grey"); local wM=Enum.Material.Concrete
    for di,d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
        local dx,dz=d[1],d[2]; local mx,mz=dx*157.5,dz*157.5
        if dx~=0 then P({name="Walk"..di, size=Vector3.new(230,0.3,8), pos=Vector3.new(mx,0.15,mz), color=wC, mat=wM, parent=walk})
        else           P({name="Walk"..di, size=Vector3.new(8,0.3,230), pos=Vector3.new(mx,0.15,mz), color=wC, mat=wM, parent=walk}) end
        -- Trees lining walkways
        for dist=50,260,20 do
            local tx,tz=dx*dist,dz*dist
            if dx==0 then Tree(tx+12,tz,0.5,walk); Tree(tx-12,tz,0.5,walk)
            else           Tree(tx,tz+12,0.5,walk); Tree(tx,tz-12,0.5,walk) end
        end
        -- Lamps
        for dist=60,260,30 do
            local lx,lz=dx*dist,dz*dist
            if dx==0 then Lamp(lx+9,lz,walk); Lamp(lx-9,lz,walk)
            else           Lamp(lx,lz+9,walk); Lamp(lx,lz-9,walk) end
        end
        -- Benches
        for dist=90,220,60 do
            local bx,bz=dx*dist,dz*dist
            if dx==0 then
                P({name="Bench",size=Vector3.new(6,0.5,2),pos=Vector3.new(bx+12,2.5,bz),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="Bench",size=Vector3.new(6,0.5,2),pos=Vector3.new(bx-12,2.5,bz),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
            else
                P({name="Bench",size=Vector3.new(6,0.5,2),pos=Vector3.new(bx,2.5,bz+12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="Bench",size=Vector3.new(6,0.5,2),pos=Vector3.new(bx,2.5,bz-12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
            end
        end
    end
end)
if not ok then warn("[WORLD] Walkways error: "..tostring(err)) end
print("[WORLD] Walkways done")
task.wait()

-- ============================================================
-- SECTION: PLOTS
-- ============================================================
ok, err = pcall(function()
    local pf = Instance.new("Folder"); pf.Name="PlotMarkers"; pf.Parent=workspace
    local coords={{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
    for _,pp in ipairs(coords) do
        local x,z=pp[1],pp[2]; local cx,cz=x*170,z*170
        local dist=math.max(math.abs(x),math.abs(z))
        local price=math.floor(50*(2^dist))
        P({name="Plot_"..x.."_"..z, size=Vector3.new(116,0.6,116), pos=Vector3.new(cx,0.3,cz), color=BrickColor.new("Dark green"), mat=Enum.Material.SmoothPlastic, parent=pf})
        -- Corner posts
        for _,c in ipairs({{55,55},{-55,55},{55,-55},{-55,-55}}) do
            P({name="Post",size=Vector3.new(1.2,5,1.2),pos=Vector3.new(cx+c[1],3,cz+c[2]),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=pf})
        end
        -- Sign post + board
        P({name="SignPost",  size=Vector3.new(0.6,6,0.6), pos=Vector3.new(cx,3.5,cz), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=pf})
        P({name="SignBoard",  size=Vector3.new(8,4,0.3),   pos=Vector3.new(cx,7.5,cz), color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic, parent=pf})
        -- Billboard
        local anchor=P({name="SignBB",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,9.5,cz),alpha=1,collide=false,parent=pf})
        local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,150,0,60); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=false; bb.Parent=anchor
        local t1=Instance.new("TextLabel"); t1.Size=UDim2.new(1,0,0.4,0); t1.BackgroundTransparency=1; t1.Text="💰 "..price; t1.TextColor3=Color3.fromRGB(255,220,100); t1.TextSize=15; t1.Font=Enum.Font.GothamBold; t1.TextStrokeTransparency=0.4; t1.Parent=bb
        local t2=Instance.new("TextLabel"); t2.Size=UDim2.new(1,0,0.4,0); t2.Position=UDim2.new(0,0,0.5,0); t2.BackgroundTransparency=1; t2.Text="🌿 AVAILABLE"; t2.TextColor3=Color3.fromRGB(100,255,150); t2.TextSize=12; t2.Font=Enum.Font.GothamBold; t2.TextStrokeTransparency=0.5; t2.Parent=bb
        -- A few flowers per plot
        for i=1,8 do Flower(cx+R(-50,50), cz+R(-50,50), pf) end
        Bush(cx+35, cz+35, 0.8, pf)
        Bush(cx-35, cz-35, 0.7, pf)
    end
end)
if not ok then warn("[WORLD] Plots error: "..tostring(err)) end
print("[WORLD] Plots done")
task.wait()

-- ============================================================
-- SECTION: DATA ORBS
-- ============================================================
ok, err = pcall(function()
    local orbs = Instance.new("Folder"); orbs.Name="DataOrbs"; orbs.Parent=workspace
    -- Ring 1: Cyan
    for i=1,10 do
        local a=(i/10)*PI*2
        Orb(math.cos(a)*55, 6, math.sin(a)*55, BrickColor.new("Cyan"), orbs)
    end
    task.wait()
    -- Ring 2: Blue
    for i=1,12 do
        local a=(i/12)*PI*2+0.3
        Orb(math.cos(a)*90, 8, math.sin(a)*90, BrickColor.new("Bright blue"), orbs)
    end
    task.wait()
    -- Ring 3: Purple
    for i=1,14 do
        local a=(i/14)*PI*2+0.15
        Orb(math.cos(a)*130, 10, math.sin(a)*130, BrickColor.new("Bright violet"), orbs)
    end
    task.wait()
    -- Ring 4: Gold
    for i=1,12 do
        local a=(i/12)*PI*2
        Orb(math.cos(a)*175, 12, math.sin(a)*175, BrickColor.new("Bright yellow"), orbs)
    end
end)
if not ok then warn("[WORLD] Orbs error: "..tostring(err)) end
print("[WORLD] Orbs done")
task.wait()

-- ============================================================
-- SECTION: NATURE
-- ============================================================
ok, err = pcall(function()
    local nat = Instance.new("Folder"); nat.Name="Nature"; nat.Parent=workspace
    -- Corner forests
    for _,fc in ipairs({{-220,-220},{220,-220},{-220,220},{220,220}}) do
        for i=1,8 do Tree(fc[1]+R(-30,30),fc[2]+R(-30,30),0.6+R()*0.4,nat) end
        for i=1,4 do Bush(fc[1]+R(-35,35),fc[2]+R(-35,35),0.7,nat) end
        for i=1,6 do Flower(fc[1]+R(-35,35),fc[2]+R(-35,35),nat) end
    end
    task.wait()
    -- Scattered trees
    for i=1,40 do
        local tx,tz=R(-240,240),R(-240,240)
        if math.abs(tx)>45 or math.abs(tz)>45 then Tree(tx,tz,0.5+R()*0.5,nat) end
    end
    task.wait()
    -- Bushes
    for i=1,50 do Bush(R(-240,240),R(-240,240),0.4+R()*0.5,nat) end
    task.wait()
    -- Flowers
    for i=1,80 do Flower(R(-240,240),R(-240,240),nat) end
    task.wait()
    -- Rocks
    for i=1,25 do Rock(R(-230,230),R(-230,230),0.4+R()*0.8,nat) end
end)
if not ok then warn("[WORLD] Nature error: "..tostring(err)) end
print("[WORLD] Nature done")
task.wait()

-- ============================================================
-- SECTION: BUILDINGS
-- ============================================================
ok, err = pcall(function()
    local bf = Instance.new("Folder"); bf.Name="Buildings"; bf.Parent=workspace
    for _,b in ipairs({{62,-62,"Data Store"},{-62,62,"Tech Shop"},{-62,-62,"Server Farm"},{62,62,"Mining Co"}}) do
        P({name="Bldg",     size=Vector3.new(14,11,14), pos=Vector3.new(b[1],6,b[2]),  color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=bf})
        P({name="Roof",     size=Vector3.new(16,1,16),  pos=Vector3.new(b[1],12,b[2]), color=BrickColor.new("Dark stone grey"),   mat=Enum.Material.SmoothPlastic, parent=bf})
        local sign=P({name="Sign", size=Vector3.new(10,2,0.3), pos=Vector3.new(b[1],10,b[2]+7.2), color=BrickColor.new("Bright blue"), mat=Enum.Material.SmoothPlastic, parent=bf})
        local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,110,0,28); bb.StudsOffset=Vector3.new(0,1.5,0); bb.AlwaysOnTop=true; bb.Parent=sign
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text="🏪 "..b[3]; lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.TextSize=13; lbl.Font=Enum.Font.GothamBold; lbl.TextStrokeTransparency=0.3; lbl.Parent=bb
    end
end)
if not ok then warn("[WORLD] Buildings error: "..tostring(err)) end
print("[WORLD] Buildings done")

print("[WORLD] ✅ World build complete!")
