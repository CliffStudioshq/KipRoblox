--[[
    WorldBuilder.server.lua — DataTycoon v0.22
    Golden hour lighting, terrain grass floor, mountain backdrop,
    Clouds, ShadowMap technology, toned bloom.
    Research applied:
      - ShadowMap for tycoon (best balance)
      - ClockTime 17.5 (golden hour)
      - Warm Atmosphere + Bloom 0.7 + SunRays 0.15
      - Terrain FillBlock for grass ground (replaces flat Part)
      - FillBall/FillCylinder for mountain ring
      - Terrain.Decoration + GrassLength for animated grass

    Changelog v0.21 → v0.22:
      - Synced version with Main.server.lua (v0.22)
      - No functional world-building changes in this release
      - Version bump only; gameplay changes (anti-cheat, DataStore
        versioning, offline income cooldown) are in Main.server.lua
]]

print("[WORLD] WorldBuilder v0.22 starting...")

local PI = math.pi
local R  = math.random
local terrain = workspace:WaitForChild("Terrain")

-- ============================================================
-- PART FACTORY
-- ============================================================
local function P(props)
    local p = Instance.new("Part")
    p.Anchored     = true
    p.Name         = props.name   or "Part"
    p.Size         = props.size   or Vector3.new(4,4,4)
    p.Position     = props.pos    or Vector3.new(0,0,0)
    p.BrickColor   = props.color  or BrickColor.new("Medium stone grey")
    p.Material     = props.mat    or Enum.Material.SmoothPlastic
    p.Transparency = props.alpha  or 0
    p.Shape        = props.shape  or Enum.PartType.Block
    p.CastShadow   = props.shadow ~= false
    if props.collide ~= nil then p.CanCollide = props.collide
    else p.CanCollide = true end
    p.Parent = props.parent or workspace
    if props.rot then
        p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(props.rot), 0)
    end
    return p
end

local function section(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[WORLD] ERROR in "..name..": "..tostring(err))
    else print("[WORLD] "..name.." done") end
    task.wait()
end

-- ============================================================
-- HELPERS
-- ============================================================
local function Tree(x, z, s, folder)
    s = s or 1
    P({name="Trunk",   size=Vector3.new(2*s,9*s,2*s),     pos=Vector3.new(x,4.5*s,z),      color=BrickColor.new("Brown"),        mat=Enum.Material.Wood,  parent=folder})
    P({name="Canopy1", size=Vector3.new(13*s,9*s,13*s),   pos=Vector3.new(x,12*s,z),        color=BrickColor.new("Dark green"),   mat=Enum.Material.Grass, shape=Enum.PartType.Ball, collide=false, parent=folder})
    P({name="Canopy2", size=Vector3.new(9*s,6*s,9*s),     pos=Vector3.new(x+1.5*s,16*s,z), color=BrickColor.new("Earth green"),  mat=Enum.Material.Grass, shape=Enum.PartType.Ball, collide=false, parent=folder})
end

local function Bush(x, z, s, folder)
    s = s or 1
    for i = 1, 3 do
        P({name="Bush", size=Vector3.new(3*s,2.5*s,3*s),
           pos=Vector3.new(x+R(-2,2), 1.2*s, z+R(-2,2)),
           color=BrickColor.new("Dark green"), mat=Enum.Material.Grass,
           shape=Enum.PartType.Ball, collide=false, parent=folder})
    end
end

local function Flower(x, z, folder)
    local palette = {"Bright red","Bright yellow","Bright violet","Bright orange","Pink","Cyan","Hot pink","Lavender","Lime green"}
    local col = BrickColor.new(palette[R(#palette)])
    P({name="FStem",   size=Vector3.new(0.3,1.2,0.3), pos=Vector3.new(x,0.6,z), color=BrickColor.new("Dark green"), mat=Enum.Material.Grass, collide=false, parent=folder})
    P({name="FCenter", size=Vector3.new(0.8,0.8,0.8), pos=Vector3.new(x,1.5,z), color=col, mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=folder})
    for i = 1, 5 do
        local a = (i/5)*PI*2
        P({name="FPetal", size=Vector3.new(0.5,0.4,0.5),
           pos=Vector3.new(x+math.cos(a)*0.55, 1.4, z+math.sin(a)*0.55),
           color=col, mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=folder})
    end
end

local function Rock(x, z, s, folder)
    s = s or 1
    P({name="Rock", size=Vector3.new(3*s,2*s,3*s), pos=Vector3.new(x,s,z),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate,
       shape=Enum.PartType.Ball, parent=folder})
end

local function Lamp(x, z, folder)
    P({name="LPole", size=Vector3.new(0.4,8,0.4),   pos=Vector3.new(x,4,z),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, parent=folder})
    P({name="LHead", size=Vector3.new(1.4,0.5,1.4), pos=Vector3.new(x,8.2,z),
       color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic, parent=folder})
end

local function Orb(cx, cy, cz, brickCol, folder)
    local ring = P({name="OrbRing", size=Vector3.new(9,3,9),
        pos=Vector3.new(cx,1.5,cz), color=brickCol,
        mat=Enum.Material.SmoothPlastic,
        shape=Enum.PartType.Cylinder, collide=true, parent=folder})
    ring.CFrame = CFrame.new(cx,1.5,cz) * CFrame.Angles(0,0,math.rad(90))
    P({name="OrbSphere", size=Vector3.new(3,3,3), pos=Vector3.new(cx,cy,cz),
       color=brickCol, mat=Enum.Material.Neon,
       shape=Enum.PartType.Ball, collide=false, parent=folder})
    P({name="OrbCore", size=Vector3.new(1.2,1.2,1.2), pos=Vector3.new(cx,cy,cz),
       color=BrickColor.new("Institutional white"), mat=Enum.Material.Neon,
       shape=Enum.PartType.Ball, collide=false, parent=folder})
    local anchor = P({name="OrbBB", size=Vector3.new(0.1,0.1,0.1),
        pos=Vector3.new(cx,cy+3,cz), alpha=1, collide=false, parent=folder})
    local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,120,0,30)
    bb.StudsOffset=Vector3.new(0,4,0); bb.AlwaysOnTop=true; bb.Parent=anchor
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text="✦ +5 Data"
    lbl.TextColor3=brickCol.Color; lbl.TextSize=14; lbl.Font=Enum.Font.GothamBold
    lbl.TextStrokeTransparency=0.15; lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.Parent=bb
end

-- ============================================================
-- SECTION: TERRAIN — Grass floor + rolling hills + mountains
-- ============================================================
section("Terrain", function()
    -- Clear any existing terrain first
    terrain:Clear()

    -- Fill entire play area (600x600) with Grass terrain at y=-2
    -- This replaces the flat Part baseplate with real terrain
    terrain:FillBlock(
        CFrame.new(0, -4, 0),
        Vector3.new(700, 8, 700),
        Enum.Material.Grass
    )

    -- Rolling hills scattered around mid-zone (avoid hub center)
    local hillSpots = {
        {100, 50}, {-120, 80}, {80, -110}, {-90, -70},
        {150, 150}, {-160, 130}, {140, -160}, {-130, -150},
        {200, 30}, {-190, -40}, {30, 200}, {-50, -190},
    }
    for _, hs in ipairs(hillSpots) do
        local hx, hz = hs[1], hs[2]
        local hr = R(15, 30) -- hill radius
        local hh = R(8, 20)  -- hill height
        terrain:FillBall(Vector3.new(hx, hh/2, hz), hr, Enum.Material.Grass)
    end
    task.wait()

    -- Gentle rolling hills around the perimeter (no boulder mountains)
    for i = 1, 16 do
        local a = (i/16)*PI*2 + 0.2
        local r = 185 + R(-15, 15)
        local mx, mz = math.cos(a)*r, math.sin(a)*r
        terrain:FillBall(Vector3.new(mx, R(5, 14), mz), R(12, 22), Enum.Material.Grass)
    end

    -- GrassLength is Studio-only, not scriptable — disable decoration
    -- so the default giant grass blades don't appear
    terrain.Decoration = false

    -- Terrain water: 4 small ponds using terrain (looks way better than Parts)
    for _, pc in ipairs({{75,75},{-75,-75},{75,-75},{-75,75}}) do
        terrain:FillCylinder(
            CFrame.new(pc[1], 0.1, pc[2]),
            1.5, 14,
            Enum.Material.Water
        )
    end
end)

-- ============================================================
-- SECTION: LIGHTING — Golden hour, ShadowMap, toned bloom
-- ============================================================
section("Lighting", function()
    local lt = game:GetService("Lighting")

    -- Prevent stacking duplicate post effects on script hot-reload (common in Studio).
    for _, child in ipairs(lt:GetChildren()) do
        if child:IsA("BloomEffect")
            or child:IsA("ColorCorrectionEffect")
            or child:IsA("SunRaysEffect")
            or child:IsA("Atmosphere") then
            child:Destroy()
        end
    end

    -- ShadowMap: best balance for tycoon (performance + looks)
    lt.Technology          = Enum.Technology.ShadowMap
    lt.ClockTime           = 17.5      -- golden hour
    lt.Brightness          = 2.2
    lt.Ambient             = Color3.fromRGB(105, 95, 85)   -- warm shadow
    lt.OutdoorAmbient      = Color3.fromRGB(135, 120, 105) -- warm sky bounce
    lt.FogEnd              = 1400
    lt.FogColor            = Color3.fromRGB(195, 178, 155) -- warm haze
    lt.GlobalShadows       = true
    lt.ShadowSoftness      = 0.2
    lt.EnvironmentDiffuseScale  = 0.6
    lt.EnvironmentSpecularScale = 0.4

    -- Bloom: research says 0.5-1.0 for cinematic, keep Size moderate
    local bloom = Instance.new("BloomEffect")
    bloom.Intensity = 0.65; bloom.Size = 22; bloom.Threshold = 0.82
    bloom.Parent = lt

    -- Color correction: warm tint, slight saturation boost
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Brightness  = 0.04
    cc.Contrast    = 0.12
    cc.Saturation  = 0.12
    cc.TintColor   = Color3.fromRGB(255, 240, 220)  -- warm golden tint
    cc.Parent = lt

    -- Sun rays: subtle god rays
    local sr = Instance.new("SunRaysEffect")
    sr.Intensity = 0.15; sr.Spread = 0.8; sr.Parent = lt

    -- Atmosphere: warm golden hour
    local atm = Instance.new("Atmosphere")
    atm.Density = 0.28
    atm.Offset  = 0.25
    atm.Color   = Color3.fromRGB(220, 175, 120)  -- warm orange horizon
    atm.Decay   = 0.92
    atm.Glare   = 0.35
    atm.Haze    = 0.8
    atm.Parent  = lt

    -- Dynamic clouds
    local existingClouds = terrain:FindFirstChildOfClass("Clouds")
    if existingClouds then
        existingClouds:Destroy()
    end

    local clouds = Instance.new("Clouds")
    clouds.Cover   = 0.45   -- not fully overcast, nice puffy look
    clouds.Density = 0.7
    clouds.Color   = Color3.fromRGB(235, 220, 200) -- warm-tinted clouds
    clouds.Parent  = terrain   -- Clouds must be parented to Terrain

    -- No sky asset (let the atmosphere + golden hour do the work)
end)

-- ============================================================
-- SECTION: HUB
-- ============================================================
section("Hub", function()
    local hub = Instance.new("Folder"); hub.Name="DataHub"; hub.Parent=workspace

    P({name="HubPlatform", size=Vector3.new(84,3,84), pos=Vector3.new(0,1.5,0),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    P({name="HubInlay1", size=Vector3.new(62,0.12,62), pos=Vector3.new(0,3.07,0),
       color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
    P({name="HubInlay2", size=Vector3.new(32,0.12,32), pos=Vector3.new(0,3.07,0),
       color=BrickColor.new("Smoky grey"), mat=Enum.Material.SmoothPlastic, parent=hub})

    -- Central tower
    for f=0,4 do
        local y=5+f*8; local sz=20-f*2
        local col = f%2==0 and BrickColor.new("Dark stone grey") or BrickColor.new("Medium stone grey")
        P({name="Tower"..f, size=Vector3.new(sz,7,sz), pos=Vector3.new(0,y,0), color=col, mat=Enum.Material.Metal, parent=hub})
        P({name="Trim"..f, size=Vector3.new(sz+0.6,0.3,sz+0.6), pos=Vector3.new(0,y-3.4,0), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, parent=hub})
    end

    -- Fountain
    local pool = P({name="FountainPool", size=Vector3.new(18,0.8,18), pos=Vector3.new(0,3.4,0),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.SmoothPlastic,
       shape=Enum.PartType.Cylinder, parent=hub})
    pool.CFrame = CFrame.new(0,3.4,0) * CFrame.Angles(0,0,math.rad(90))
    local wat = P({name="FountainWater", size=Vector3.new(16,0.4,16), pos=Vector3.new(0,3.95,0),
       color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass,
       shape=Enum.PartType.Cylinder, alpha=0.25, collide=false, parent=hub})
    wat.CFrame = CFrame.new(0,3.95,0) * CFrame.Angles(0,0,math.rad(90))
    P({name="FountainSpire", size=Vector3.new(1.5,8,1.5), pos=Vector3.new(0,7,0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Metal, parent=hub})
    P({name="FountainTop", size=Vector3.new(3.5,1,3.5), pos=Vector3.new(0,11.5,0), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=hub})
    for i=1,6 do
        local a=(i/6)*PI*2
        P({name="FBench",size=Vector3.new(4,0.5,1.5),pos=Vector3.new(math.cos(a)*10,3.3,math.sin(a)*10),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,rot=math.deg(a)+90,parent=hub})
    end

    -- Server racks
    for i=1,8 do
        local a=(i/8)*PI*2; local x,z=math.cos(a)*30,math.sin(a)*30
        P({name="Rack"..i, size=Vector3.new(5,11,3), pos=Vector3.new(x,7,z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, parent=hub})
        for l=0,2 do
            P({name="LED",size=Vector3.new(0.3,0.2,0.3),pos=Vector3.new(x,3+l*2.5,z+1.6),
               color=l%2==0 and BrickColor.new("Lime green") or BrickColor.new("Forest green"),
               mat=Enum.Material.SmoothPlastic,parent=hub})
        end
    end

    -- Entrance arches
    for i=1,4 do
        local a=(i/4)*PI*2; local x,z=math.cos(a)*44,math.sin(a)*44
        P({name="ArchL"..i, size=Vector3.new(2.5,16,2.5), pos=Vector3.new(x-2,9,z), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
        P({name="ArchR"..i, size=Vector3.new(2.5,16,2.5), pos=Vector3.new(x+2,9,z), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
        P({name="ArchTop"..i, size=Vector3.new(9,2,2.5), pos=Vector3.new(x,18,z), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=hub})
        P({name="ArchAcc"..i, size=Vector3.new(9.2,0.4,2.7), pos=Vector3.new(x,19.2,z), color=BrickColor.new("Cyan"), mat=Enum.Material.SmoothPlastic, parent=hub})
    end

    -- Hub lamps
    for i=1,8 do
        local a=(i/8)*PI*2
        Lamp(math.cos(a)*38, math.sin(a)*38, hub)
    end

    -- Plaza connectors
    for _, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
        local dx,dz=d[1],d[2]
        P({name="Plaza",size=Vector3.new(dx~=0 and 32 or 8, 0.3, dz~=0 and 32 or 8),
           pos=Vector3.new(dx*57,0.15,dz*57),
           color=BrickColor.new("Medium stone grey"),mat=Enum.Material.Concrete,parent=hub})
    end

    -- Flowers ringing hub edge
    for i=1,24 do
        local a=(i/24)*PI*2; local r=42+R(-2,2)
        Flower(math.cos(a)*r, math.sin(a)*r, hub)
    end
end)

-- ============================================================
-- SECTION: WALKWAYS
-- ============================================================
section("Walkways", function()
    local walk = Instance.new("Folder"); walk.Name="Walkways"; walk.Parent=workspace
    local wC=BrickColor.new("Medium stone grey"); local wM=Enum.Material.Concrete

    for di, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
        local dx,dz=d[1],d[2]; local mx,mz=dx*157.5,dz*157.5
        if dx~=0 then
            P({name="Walk"..di, size=Vector3.new(230,0.3,8), pos=Vector3.new(mx,0.15,mz), color=wC, mat=wM, parent=walk})
            P({name="WalkStrL"..di, size=Vector3.new(230,0.32,0.4), pos=Vector3.new(mx,0.15,mz+3.8), color=BrickColor.new("Smoky grey"), mat=wM, parent=walk})
            P({name="WalkStrR"..di, size=Vector3.new(230,0.32,0.4), pos=Vector3.new(mx,0.15,mz-3.8), color=BrickColor.new("Smoky grey"), mat=wM, parent=walk})
        else
            P({name="Walk"..di, size=Vector3.new(8,0.3,230), pos=Vector3.new(mx,0.15,mz), color=wC, mat=wM, parent=walk})
            P({name="WalkStrL"..di, size=Vector3.new(0.4,0.32,230), pos=Vector3.new(mx+3.8,0.15,mz), color=BrickColor.new("Smoky grey"), mat=wM, parent=walk})
            P({name="WalkStrR"..di, size=Vector3.new(0.4,0.32,230), pos=Vector3.new(mx-3.8,0.15,mz), color=BrickColor.new("Smoky grey"), mat=wM, parent=walk})
        end

        for dist=55,260,22 do
            local tx,tz=dx*dist,dz*dist; local s=0.55+R()*0.25
            if dx==0 then Tree(tx+13,tz,s,walk); Tree(tx-13,tz,s,walk)
            else           Tree(tx,tz+13,s,walk); Tree(tx,tz-13,s,walk) end
        end

        for dist=65,260,30 do
            local lx,lz=dx*dist,dz*dist
            if dx==0 then Lamp(lx+9,lz,walk); Lamp(lx-9,lz,walk)
            else           Lamp(lx,lz+9,walk); Lamp(lx,lz-9,walk) end
        end

        for dist=90,230,55 do
            local bx,bz=dx*dist,dz*dist
            if dx==0 then
                P({name="Bench",size=Vector3.new(5,0.5,1.8),pos=Vector3.new(bx+12,2,bz),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="BenchB",size=Vector3.new(5,2.5,0.4),pos=Vector3.new(bx+12,3.5,bz+0.7),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="Bench",size=Vector3.new(5,0.5,1.8),pos=Vector3.new(bx-12,2,bz),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="BenchB",size=Vector3.new(5,2.5,0.4),pos=Vector3.new(bx-12,3.5,bz+0.7),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
            else
                P({name="Bench",size=Vector3.new(1.8,0.5,5),pos=Vector3.new(bx,2,bz+12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="BenchB",size=Vector3.new(0.4,2.5,5),pos=Vector3.new(bx+0.7,3.5,bz+12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="Bench",size=Vector3.new(1.8,0.5,5),pos=Vector3.new(bx,2,bz-12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
                P({name="BenchB",size=Vector3.new(0.4,2.5,5),pos=Vector3.new(bx+0.7,3.5,bz-12),color=BrickColor.new("Brown"),mat=Enum.Material.Wood,parent=walk})
            end
        end

        -- Kiosks
        for dist=80,220,80 do
            local kx,kz=dx*dist,dz*dist
            local ox=dx==0 and 14 or 0; local oz=dz==0 and 14 or 0
            P({name="Kiosk",size=Vector3.new(3,5,3),pos=Vector3.new(kx+ox,2.5,kz+oz),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=walk})
            P({name="KioskTop",size=Vector3.new(3.5,0.4,3.5),pos=Vector3.new(kx+ox,5.2,kz+oz),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=walk})
        end

        -- Flowers along edges
        for dist=50,250,35 do
            local fx,fz=dx*dist,dz*dist
            if dx==0 then
                Flower(fx+11+R(-1,1),fz+R(-3,3),walk); Flower(fx-11+R(-1,1),fz+R(-3,3),walk)
            else
                Flower(fx+R(-3,3),fz+11+R(-1,1),walk); Flower(fx+R(-3,3),fz-11+R(-1,1),walk)
            end
        end
    end
end)

-- ============================================================
-- SECTION: PLOTS
-- ============================================================
section("Plots", function()
    local pf = Instance.new("Folder"); pf.Name="PlotMarkers"; pf.Parent=workspace
    local coords = {{-3,-3},{-3,3},{3,-3},{3,3},{0,-3},{0,3},{-3,0},{3,0}}
    for _, pp in ipairs(coords) do
        local x,z   = pp[1],pp[2]; local cx,cz=x*170,z*170
        local dist  = math.max(math.abs(x),math.abs(z))
        local price = math.floor(50*(2^dist))

        P({name="Plot_"..x.."_"..z, size=Vector3.new(116,0.6,116), pos=Vector3.new(cx,0.3,cz),
           color=BrickColor.new("Dark green"), mat=Enum.Material.SmoothPlastic, parent=pf})
        P({name="BdrN",size=Vector3.new(116,2,0.8),pos=Vector3.new(cx,1.6,cz+58),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Concrete,parent=pf})
        P({name="BdrS",size=Vector3.new(116,2,0.8),pos=Vector3.new(cx,1.6,cz-58),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Concrete,parent=pf})
        P({name="BdrE",size=Vector3.new(0.8,2,116),pos=Vector3.new(cx+58,1.6,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Concrete,parent=pf})
        P({name="BdrW",size=Vector3.new(0.8,2,116),pos=Vector3.new(cx-58,1.6,cz),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.Concrete,parent=pf})
        for _, c in ipairs({{57,57},{-57,57},{57,-57},{-57,-57}}) do
            P({name="Post",size=Vector3.new(1.5,6,1.5),pos=Vector3.new(cx+c[1],3,cz+c[2]),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=pf})
        end
        P({name="SignPost", size=Vector3.new(0.6,7,0.6),  pos=Vector3.new(cx,4,cz),   color=BrickColor.new("Dark stone grey"),   mat=Enum.Material.Metal,         parent=pf})
        P({name="SignBoard", size=Vector3.new(9,4,0.4),    pos=Vector3.new(cx,8,cz),   color=BrickColor.new("Medium stone grey"), mat=Enum.Material.SmoothPlastic, parent=pf})
        local anchor=P({name="SignBB",size=Vector3.new(0.1,0.1,0.1),pos=Vector3.new(cx,9.5,cz),alpha=1,collide=false,parent=pf})
        local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,160,0,70); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=false; bb.Parent=anchor
        local t1=Instance.new("TextLabel"); t1.Size=UDim2.new(1,0,0.45,0); t1.BackgroundTransparency=1; t1.Text="💰 "..price.." Data"; t1.TextColor3=Color3.fromRGB(255,220,100); t1.TextSize=15; t1.Font=Enum.Font.GothamBold; t1.TextStrokeTransparency=0.35; t1.Parent=bb
        local t2=Instance.new("TextLabel"); t2.Size=UDim2.new(1,0,0.4,0); t2.Position=UDim2.new(0,0,0.5,0); t2.BackgroundTransparency=1; t2.Text="🌿 AVAILABLE"; t2.TextColor3=Color3.fromRGB(100,255,150); t2.TextSize=12; t2.Font=Enum.Font.GothamBold; t2.TextStrokeTransparency=0.5; t2.Parent=bb
        Tree(cx+38,cz+38,0.7,pf); Tree(cx-38,cz-38,0.6,pf); Tree(cx+38,cz-38,0.5,pf)
        Bush(cx-30,cz+30,0.8,pf); Bush(cx+20,cz-30,0.7,pf)
        Rock(cx-45,cz-45,0.5,pf); Rock(cx+40,cz+10,0.4,pf)
        for i=1,10 do Flower(cx+R(-52,52),cz+R(-52,52),pf) end
        P({name="Entry",size=Vector3.new(8,0.3,20),pos=Vector3.new(cx,0.5,cz+48),color=BrickColor.new("Light stone grey"),mat=Enum.Material.Concrete,parent=pf})
    end
end)

-- ============================================================
-- SECTION: DATA ORBS
-- ============================================================
section("Orbs", function()
    local orbs = Instance.new("Folder"); orbs.Name="DataOrbs"; orbs.Parent=workspace
    local rings = {
        {count=10, radius=55,  y=6,  col=BrickColor.new("Cyan")},
        {count=12, radius=90,  y=8,  col=BrickColor.new("Bright blue")},
        {count=14, radius=130, y=10, col=BrickColor.new("Bright violet")},
        {count=12, radius=175, y=12, col=BrickColor.new("Bright yellow")},
    }
    for ri, ring in ipairs(rings) do
        for i=1,ring.count do
            local a=(i/ring.count)*PI*2+(ri*0.2)
            Orb(math.cos(a)*ring.radius, ring.y, math.sin(a)*ring.radius, ring.col, orbs)
        end
        task.wait()
    end
end)

-- ============================================================
-- SECTION: NATURE
-- ============================================================
section("Nature", function()
    local nat = Instance.new("Folder"); nat.Name="Nature"; nat.Parent=workspace
    for _, fc in ipairs({{-200,-200},{200,-200},{-200,200},{200,200}}) do
        for i=1,8 do Tree(fc[1]+R(-28,28),fc[2]+R(-28,28),0.6+R()*0.4,nat) end
        for i=1,5 do Bush(fc[1]+R(-30,30),fc[2]+R(-30,30),0.7+R()*0.3,nat) end
        for i=1,4 do Rock(fc[1]+R(-22,22),fc[2]+R(-22,22),0.4+R()*0.6,nat) end
        for i=1,8 do Flower(fc[1]+R(-30,30),fc[2]+R(-30,30),nat) end
    end
    task.wait()
    for i=1,45 do
        local tx,tz=R(-230,230),R(-230,230)
        if math.abs(tx)>50 or math.abs(tz)>50 then Tree(tx,tz,0.5+R()*0.4,nat) end
    end
    task.wait()
    for i=1,55 do Bush(R(-230,230),R(-230,230),0.4+R()*0.5,nat) end
    task.wait()
    for i=1,90 do Flower(R(-230,230),R(-230,230),nat) end
    task.wait()
    for i=1,30 do Rock(R(-220,220),R(-220,220),0.3+R()*0.8,nat) end
end)

-- ============================================================
-- SECTION: BUILDINGS
-- ============================================================
section("Buildings", function()
    local bf = Instance.new("Folder"); bf.Name="Buildings"; bf.Parent=workspace
    for _, b in ipairs({
        {70,-70,"Data Store",BrickColor.new("Medium stone grey")},
        {-70,70,"Tech Shop",BrickColor.new("Sand blue")},
        {-70,-70,"Server Farm",BrickColor.new("Dark stone grey")},
        {70,70,"Mining Co",BrickColor.new("Sand green")},
    }) do
        P({name="Bldg",size=Vector3.new(16,12,16),pos=Vector3.new(b[1],7,b[2]),color=b[4],mat=Enum.Material.SmoothPlastic,parent=bf})
        P({name="Roof",size=Vector3.new(18,1.2,18),pos=Vector3.new(b[1],13.6,b[2]),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=bf})
        P({name="RoofAcc",size=Vector3.new(18.2,0.3,18.2),pos=Vector3.new(b[1],14.3,b[2]),color=BrickColor.new("Cyan"),mat=Enum.Material.SmoothPlastic,parent=bf})
        P({name="Door",size=Vector3.new(3,5,0.3),pos=Vector3.new(b[1],4,b[2]+8.15),color=BrickColor.new("Bright blue"),mat=Enum.Material.SmoothPlastic,parent=bf})
        for w=-1,1,2 do
            P({name="Win",size=Vector3.new(3,3,0.3),pos=Vector3.new(b[1]+w*4,8,b[2]+8.15),color=BrickColor.new("Bright blue"),mat=Enum.Material.Glass,alpha=0.35,parent=bf})
        end
        local sign=P({name="Sign",size=Vector3.new(12,2,0.3),pos=Vector3.new(b[1],12,b[2]+8.2),color=BrickColor.new("Dark stone grey"),mat=Enum.Material.SmoothPlastic,parent=bf})
        local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,120,0,28); bb.StudsOffset=Vector3.new(0,1.5,0); bb.AlwaysOnTop=true; bb.Parent=sign
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text="🏪 "..b[3]; lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.TextSize=13; lbl.Font=Enum.Font.GothamBold; lbl.TextStrokeTransparency=0.3; lbl.Parent=bb
        Lamp(b[1]+10,b[2]+9,bf); Lamp(b[1]-10,b[2]+9,bf)
    end
end)

print("[WORLD] ✅ World build complete!")
