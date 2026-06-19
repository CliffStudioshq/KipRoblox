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

local Players = game:GetService("Players")
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
-- BRIDGES (server-built, per plot)
-- ============================================================
local Bridges = {} -- plotId -> Model

local function findPlotPart(plotId)
    local pf = workspace:FindFirstChild("PlotMarkers")
    if not pf then return nil end

    local x, z = plotId:match("plot_(-?%d+)_(-?%d+)")
    if not x or not z then return nil end
    return pf:FindFirstChild("Plot_" .. x .. "_" .. z)
end

local function getHubPlatform()
    local hub = workspace:FindFirstChild("DataHub")
    if not hub then return nil end
    return hub:FindFirstChild("HubPlatform")
end

local function makePart(parent, name, size, cframe, material, color, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = true
    p.Size = size
    p.CFrame = cframe
    p.Material = material or Enum.Material.SmoothPlastic
    if typeof(color) == "BrickColor" then
        p.BrickColor = color
    elseif typeof(color) == "Color3" then
        p.Color = color
    end
    p.Transparency = transparency or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function makeLight(name, attachmentPart, range, brightness)
    local a = Instance.new("Attachment")
    a.Name = name .. "Att"
    a.Parent = attachmentPart

    local l = Instance.new("PointLight")
    l.Name = name
    l.Range = range or 18
    l.Brightness = brightness or 2
    l.Color = Color3.fromRGB(235, 245, 255)
    l.Parent = a
    return l
end

local function buildOwnerSign(parentModel, baseCFrame, ownerName, ownerUserId)
    local post = makePart(parentModel, "OwnerSignPost", Vector3.new(0.5, 7, 0.5), baseCFrame * CFrame.new(0, 3.5, 0), Enum.Material.Wood, BrickColor.new("Reddish brown"))
    post.CanCollide = true

    local board = makePart(parentModel, "OwnerSignBoard", Vector3.new(6, 4, 0.35), baseCFrame * CFrame.new(0, 7.6, 0), Enum.Material.SmoothPlastic, BrickColor.new("Dark stone grey"))
    board.CanCollide = false

    local gui = Instance.new("BillboardGui")
    gui.Name = "OwnerBillboard"
    gui.Size = UDim2.new(0, 220, 0, 160)
    gui.StudsOffset = Vector3.new(0, 1.5, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = board

    local owned = Instance.new("TextLabel")
    owned.Name = "OwnedBy"
    owned.Size = UDim2.new(1, 0, 0, 26)
    owned.BackgroundTransparency = 1
    owned.Text = "OWNED BY"
    owned.TextColor3 = Color3.fromRGB(255, 255, 255)
    owned.TextStrokeTransparency = 0.35
    owned.Font = Enum.Font.GothamBold
    owned.TextSize = 18
    owned.Parent = gui

    local img = Instance.new("ImageLabel")
    img.Name = "Head"
    img.Size = UDim2.new(0, 84, 0, 84)
    img.Position = UDim2.new(0.5, -42, 0, 30)
    img.BackgroundTransparency = 1
    img.Parent = gui

    local uname = Instance.new("TextLabel")
    uname.Name = "Username"
    uname.Size = UDim2.new(1, 0, 0, 30)
    uname.Position = UDim2.new(0, 0, 1, -32)
    uname.BackgroundTransparency = 1
    uname.Text = ownerName or "Unknown"
    uname.TextColor3 = Color3.fromRGB(255, 255, 255)
    uname.TextStrokeTransparency = 0.25
    uname.Font = Enum.Font.GothamBold
    uname.TextSize = 20
    uname.Parent = gui

    if ownerUserId then
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(ownerUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content then
                img.Image = content
            end
        end)
    end

    return post, board
end

function BuildBridge(plotId, ownerName, ownerUserId)
    if type(plotId) ~= "string" then return nil end

    if Bridges[plotId] and Bridges[plotId].Parent then
        Bridges[plotId]:Destroy()
        Bridges[plotId] = nil
    end

    local hubPlatform = getHubPlatform()
    local plotPart = findPlotPart(plotId)
    if not hubPlatform or not plotPart then
        warn("[WORLD] BuildBridge failed; missing HubPlatform or plot marker for " .. tostring(plotId))
        return nil
    end

    local hubPos = hubPlatform.Position
    local plotPos = plotPart.Position
    local dir = Vector3.new(plotPos.X - hubPos.X, 0, plotPos.Z - hubPos.Z)
    if dir.Magnitude < 1 then
        warn("[WORLD] BuildBridge failed; invalid direction for " .. tostring(plotId))
        return nil
    end
    local unit = dir.Unit
    local right = unit:Cross(Vector3.new(0,1,0)).Unit

    local hubHalf = Vector3.new(hubPlatform.Size.X/2, hubPlatform.Size.Y/2, hubPlatform.Size.Z/2)
    local plotHalf = Vector3.new(plotPart.Size.X/2, plotPart.Size.Y/2, plotPart.Size.Z/2)
    local start = hubPos + unit * (math.max(hubHalf.X, hubHalf.Z) + 2)
    local finish = plotPos - unit * (math.max(plotHalf.X, plotHalf.Z) + 2)

    local span = finish - start
    local dist = span.Magnitude
    local segLen = 8
    local segCount = math.max(6, math.ceil(dist / segLen))
    local baseY = 0.2
    local arcHeight = math.clamp(dist * 0.03, 1.2, 6)

    local model = Instance.new("Model")
    model.Name = "Bridge_" .. plotId
    model.Parent = workspace

    local partsFolder = Instance.new("Folder")
    partsFolder.Name = "BridgeParts"
    partsFolder.Parent = model

    -- Stone pillars at ends
    local function pillar(at)
        makePart(partsFolder, "Pillar", Vector3.new(4, 6, 4), CFrame.new(at.X, baseY + 3, at.Z), Enum.Material.Slate, BrickColor.new("Dark stone grey"))
    end
    pillar(start)
    pillar(finish)

    -- Walkway
    local walkwayWidth = 8
    local walkwayThick = 0.3
    for i = 0, segCount-1 do
        local t0 = i/segCount
        local t1 = (i+1)/segCount
        local p0 = start:Lerp(finish, t0)
        local p1 = start:Lerp(finish, t1)
        local mid = (p0 + p1) * 0.5

        local y0 = baseY + math.sin(t0 * PI) * arcHeight
        local y1 = baseY + math.sin(t1 * PI) * arcHeight
        local midY = (y0 + y1) * 0.5

        local len = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z).Magnitude
        if len > 0.05 then
            local cf = CFrame.lookAt(Vector3.new(mid.X, midY, mid.Z), Vector3.new(mid.X, midY, mid.Z) + unit)
            makePart(partsFolder, "Walkway", Vector3.new(walkwayWidth, walkwayThick, len + 0.05), cf, Enum.Material.Concrete, BrickColor.new("Medium stone grey"))
        end
    end

    -- Railings
    local railFolder = Instance.new("Folder")
    railFolder.Name = "Railings"
    railFolder.Parent = model

    local nPosts = math.max(2, math.floor(dist / 8) + 1)
    for i = 0, nPosts-1 do
        local t = (nPosts == 1) and 0 or (i/(nPosts-1))
        local pos = start:Lerp(finish, t)
        local y = baseY + math.sin(t * PI) * arcHeight
        local base = Vector3.new(pos.X, y + 1.5, pos.Z)

        for side = -1, 1, 2 do
            local offset = right * (side * (walkwayWidth/2 - 0.25))
            local cf = CFrame.lookAt(base + offset, base + offset + unit)
            makePart(railFolder, "Post", Vector3.new(0.4, 3, 0.4), cf, Enum.Material.Wood, BrickColor.new("Reddish brown"))
        end
    end

    local nBeams = math.max(1, math.floor(dist / 8))
    for i = 0, nBeams-1 do
        local t0 = i/nBeams
        local t1 = (i+1)/nBeams
        local p0 = start:Lerp(finish, t0)
        local p1 = start:Lerp(finish, t1)
        local mid = (p0 + p1) * 0.5
        local y0 = baseY + math.sin(t0 * PI) * arcHeight
        local y1 = baseY + math.sin(t1 * PI) * arcHeight
        local midY = (y0 + y1) * 0.5
        local len = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z).Magnitude
        if len > 0.05 then
            for side = -1, 1, 2 do
                local offset = right * (side * (walkwayWidth/2 - 0.25))
                local cf = CFrame.lookAt(Vector3.new(mid.X, midY + 2.2, mid.Z) + offset, Vector3.new(mid.X, midY + 2.2, mid.Z) + offset + unit)
                makePart(railFolder, "Beam", Vector3.new(0.35, 0.25, len + 0.05), cf, Enum.Material.Wood, BrickColor.new("Reddish brown"))
            end
        end
    end

    -- Lamps
    local lampFolder = Instance.new("Folder")
    lampFolder.Name = "Lamps"
    lampFolder.Parent = model

    local nLamps = math.max(0, math.floor(dist / 16))
    for i = 1, nLamps do
        local t = i / (nLamps + 1)
        local pos = start:Lerp(finish, t)
        local y = baseY + math.sin(t * PI) * arcHeight
        local side = (i % 2 == 0) and -1 or 1
        local base = Vector3.new(pos.X, y, pos.Z) + right * (side * (walkwayWidth/2 + 0.8))

        local pole = makePart(lampFolder, "LampPole", Vector3.new(0.25, 8, 0.25), CFrame.new(base + Vector3.new(0, 4, 0)), Enum.Material.Metal, BrickColor.new("Dark stone grey"))
        pole.CanCollide = false

        local head = makePart(lampFolder, "LampHead", Vector3.new(0.9, 0.5, 0.9), CFrame.new(base + Vector3.new(0, 8.3, 0)), Enum.Material.Neon, Color3.fromRGB(210, 245, 255))
        head.CanCollide = false
        makeLight("LampLight", head, 22, 2.2)
    end

    -- Owner sign near hub end (offset to the side), facing outward toward plot
    local signPos = start - unit * 6 + right * 10
    local signCF = CFrame.lookAt(Vector3.new(signPos.X, 0, signPos.Z), Vector3.new(signPos.X, 0, signPos.Z) + unit)
    buildOwnerSign(model, signCF, ownerName, ownerUserId)

    Bridges[plotId] = model
    return model
end

function RemoveBridge(plotId)
    if type(plotId) ~= "string" then return end
    local m = Bridges[plotId]
    if m and m.Parent then
        m:Destroy()
    end
    Bridges[plotId] = nil
end

-- ============================================================
-- HELPERS
-- ============================================================
local function Tree(x, z, s, folder)
    -- 4 tree archetypes for variety: oak, pine, birch, tropical
    s = s or 1
    local t = R(1,4)
    local yaw = math.rad(R(-180, 180))

    local function canopyBall(name, pos, size, brick)
        local c = P({
            name=name,
            size=size,
            pos=pos,
            color=brick,
            mat=Enum.Material.LeafyGrass,
            shape=Enum.PartType.Ball,
            collide=false,
            parent=folder,
        })
        c.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
        return c
    end

    local trunkCol = BrickColor.new("Reddish brown")
    local greens = {
        BrickColor.new("Forest green"),
        BrickColor.new("Earth green"),
        BrickColor.new("Dark green"),
        BrickColor.new("Sea green"),
        BrickColor.new("Camo"),
    }

    if t == 1 then
        -- Oak: wide canopy, 3 layers
        local h = (10 + R(-2,3)) * s
        P({name="Trunk", size=Vector3.new(2.3*s, h, 2.3*s), pos=Vector3.new(x, h/2, z), color=trunkCol, mat=Enum.Material.Wood, parent=folder})
        local topY = h + (4.5*s)
        canopyBall("Canopy1", Vector3.new(x, topY, z), Vector3.new(15*s, 10*s, 15*s), greens[R(#greens)])
        canopyBall("Canopy2", Vector3.new(x+1.2*s, topY+3.5*s, z-0.7*s), Vector3.new(12*s, 8*s, 12*s), greens[R(#greens)])
        canopyBall("Canopy3", Vector3.new(x-1.0*s, topY+6.0*s, z+0.9*s), Vector3.new(9*s, 6*s, 9*s), greens[R(#greens)])

    elseif t == 2 then
        -- Pine: tall trunk, conical canopy stack
        local h = (14 + R(-2,6)) * s
        P({name="Trunk", size=Vector3.new(1.8*s, h, 1.8*s), pos=Vector3.new(x, h/2, z), color=BrickColor.new("Brown"), mat=Enum.Material.Wood, parent=folder})
        local baseY = h*0.75
        local pineCols = {BrickColor.new("Dark green"), BrickColor.new("Camo"), BrickColor.new("Forest green")}
        for i=1,4 do
            local layer = 1 - (i-1)*0.18
            local rad = (10*s) * layer
            local y = baseY + (i-1) * (3.2*s)
            canopyBall("Needles"..i, Vector3.new(x, y, z), Vector3.new(rad, 7*s*layer, rad), pineCols[R(#pineCols)])
        end

    elseif t == 3 then
        -- Birch: thin trunk, small light canopy
        local h = (11 + R(-1,4)) * s
        P({name="Trunk", size=Vector3.new(1.3*s, h, 1.3*s), pos=Vector3.new(x, h/2, z), color=BrickColor.new("Institutional white"), mat=Enum.Material.Wood, parent=folder})
        P({name="BirchStripe", size=Vector3.new(1.35*s, h*0.7, 1.35*s), pos=Vector3.new(x, h*0.55, z), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Wood, parent=folder, alpha=0.35})
        local col = (R() < 0.35) and BrickColor.new("New Yeller") or BrickColor.new("Light green")
        local y = h + (3.5*s)
        canopyBall("Canopy1", Vector3.new(x, y, z), Vector3.new(9*s, 6*s, 9*s), col)
        canopyBall("Canopy2", Vector3.new(x+0.8*s, y+2.2*s, z-0.6*s), Vector3.new(6.5*s, 4.2*s, 6.5*s), BrickColor.new("Light green"))

    else
        -- Tropical: palm-like, slight curved trunk + fronds
        local h = (12 + R(-1,5)) * s
        local bend = (R(-6,6)) * 0.12 * s
        local trunk = P({name="Trunk", size=Vector3.new(1.9*s, h, 1.9*s), pos=Vector3.new(x, h/2, z), color=BrickColor.new("Dark orange"), mat=Enum.Material.Wood, parent=folder})
        trunk.CFrame = CFrame.new(x, h/2, z) * CFrame.Angles(0, yaw, math.rad(bend*10))

        local top = Vector3.new(x, h + (1.5*s), z)
        local palmCols = {BrickColor.new("Lime green"), BrickColor.new("Bright green"), BrickColor.new("Sea green")}
        canopyBall("PalmCore", top, Vector3.new(4.2*s, 2.6*s, 4.2*s), palmCols[R(#palmCols)])
        for i=1,6 do
            local a = (i/6)*PI*2 + (yaw*0.35)
            local fx = x + math.cos(a) * (5.5*s)
            local fz = z + math.sin(a) * (5.5*s)
            local frond = P({name="Frond"..i, size=Vector3.new(8.5*s, 0.35*s, 2.2*s), pos=Vector3.new(fx, top.Y, fz),
                color=palmCols[R(#palmCols)], mat=Enum.Material.LeafyGrass, parent=folder, collide=false})
            frond.CFrame = CFrame.new(fx, top.Y, fz) * CFrame.Angles(math.rad(R(-18, 10)), a, 0)
        end
    end
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
    -- 6 flower archetypes: rose, daisy, tulip, lavender, sunflower, wildflower
    local ftype = R(1,6)

    local function tuft(tx, tz)
        local h = 0.25 + R()*0.25
        local w = 0.25 + R()*0.25
        local g = P({name="GrassTuft", size=Vector3.new(w, h, w), pos=Vector3.new(tx, h/2, tz),
            color=BrickColor.new("Dark green"), mat=Enum.Material.LeafyGrass, shape=Enum.PartType.Ball, collide=false, parent=folder})
        g.Transparency = 0.15
    end

    -- subtle base tufts
    for i=1, R(2,4) do
        tuft(x + R(-6,6)*0.12, z + R(-6,6)*0.12)
    end

    local stemH = 1.0 + R()*0.8
    local stem = P({name="FStem", size=Vector3.new(0.25, stemH, 0.25), pos=Vector3.new(x, stemH/2, z),
        color=BrickColor.new("Earth green"), mat=Enum.Material.LeafyGrass, collide=false, parent=folder})

    local function petal(pos, size, brick)
        P({name="FPetal", size=size, pos=pos, color=brick, mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
    end

    if ftype == 1 then
        -- Rose: tight layered petals (red/pink)
        local roseCols = {"Crimson","Bright red","Hot pink","Pink"}
        local col = BrickColor.new(roseCols[R(#roseCols)])
        P({name="FCenter", size=Vector3.new(0.45,0.45,0.45), pos=Vector3.new(x, stemH+0.2, z), color=BrickColor.new("New Yeller"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
        for ring=1,3 do
            local petals = 6 + ring*2
            local rad = 0.25 + ring*0.15
            for i=1,petals do
                local a=(i/petals)*PI*2
                petal(Vector3.new(x+math.cos(a)*rad, stemH+0.25+ring*0.08, z+math.sin(a)*rad), Vector3.new(0.35,0.28,0.35), col)
            end
        end

    elseif ftype == 2 then
        -- Daisy: white petals + yellow center
        local petals = 10 + R(-2,2)
        local col = BrickColor.new("Institutional white")
        P({name="FCenter", size=Vector3.new(0.45,0.45,0.45), pos=Vector3.new(x, stemH+0.2, z), color=BrickColor.new("New Yeller"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
        for i=1,petals do
            local a=(i/petals)*PI*2
            petal(Vector3.new(x+math.cos(a)*0.55, stemH+0.15, z+math.sin(a)*0.55), Vector3.new(0.45,0.18,0.45), col)
        end

    elseif ftype == 3 then
        -- Tulip: 3 big petals + 3 small inner petals
        local tulipCols = {"Bright red","Bright orange","Hot pink","Magenta","Lavender"}
        local col = BrickColor.new(tulipCols[R(#tulipCols)])
        for i=1,3 do
            local a=(i/3)*PI*2
            petal(Vector3.new(x+math.cos(a)*0.22, stemH+0.25, z+math.sin(a)*0.22), Vector3.new(0.55,0.65,0.35), col)
        end
        for i=1,3 do
            local a=(i/3)*PI*2 + 0.45
            petal(Vector3.new(x+math.cos(a)*0.12, stemH+0.35, z+math.sin(a)*0.12), Vector3.new(0.4,0.5,0.25), col)
        end

    elseif ftype == 4 then
        -- Lavender: tall stalk with many tiny purple blooms
        local col = BrickColor.new("Lavender")
        for i=1, R(5,8) do
            local y = stemH*0.55 + i*0.22
            petal(Vector3.new(x+R(-4,4)*0.06, y, z+R(-4,4)*0.06), Vector3.new(0.22,0.22,0.22), col)
        end

    elseif ftype == 5 then
        -- Sunflower: big yellow ring + brown center
        local petals = 12 + R(-2,3)
        P({name="FCenter", size=Vector3.new(0.55,0.55,0.55), pos=Vector3.new(x, stemH+0.2, z), color=BrickColor.new("Reddish brown"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
        local col = BrickColor.new("Bright yellow")
        for i=1,petals do
            local a=(i/petals)*PI*2
            petal(Vector3.new(x+math.cos(a)*0.75, stemH+0.15, z+math.sin(a)*0.75), Vector3.new(0.55,0.2,0.55), col)
        end

    else
        -- Wildflower: random palette, variable petal count and radius
        local palette = {"Bright violet","Cyan","Lime green","Bright blue","Pink","Hot pink","Bright orange"}
        local col = BrickColor.new(palette[R(#palette)])
        local petals = R(5,9)
        local rad = 0.45 + R()*0.35
        P({name="FCenter", size=Vector3.new(0.35,0.35,0.35), pos=Vector3.new(x, stemH+0.2, z), color=BrickColor.new("New Yeller"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
        for i=1,petals do
            local a=(i/petals)*PI*2
            petal(Vector3.new(x+math.cos(a)*rad, stemH+0.12, z+math.sin(a)*rad), Vector3.new(0.4,0.22,0.4), col)
        end
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

    -- Enable built-in terrain grass decoration (animated blades)
    terrain.Decoration = true
    terrain.GrassLength = 0.8 -- short, natural blades

    -- Terrain water: 6 small ponds using terrain (looks way better than Parts)
    local ponds = {
        {75,75}, {-75,-75}, {75,-75}, {-75,75},
        {185, -25}, {-185, 25},
    }
    for _, pc in ipairs(ponds) do
        terrain:FillCylinder(
            CFrame.new(pc[1], 0.1, pc[2]),
            1.5, 14,
            Enum.Material.Water
        )
    end

    -- Stream connecting the two extra ponds
    for i=0, 1, 0.1 do
        local x = 185 + (-370)*i
        local z = -25 + (50)*i
        terrain:FillBlock(CFrame.new(x, 0.05, z), Vector3.new(10, 1.2, 6), Enum.Material.Water)
    end

    -- Lily pads & reeds
    local waterDecor = Instance.new("Folder")
    waterDecor.Name = "WaterDecor"
    waterDecor.Parent = workspace

    local function LilyPad(px, pz)
        local pad = P({name="LilyPad", size=Vector3.new(3.5, 0.15, 3.5), pos=Vector3.new(px, 0.7, pz),
            color=BrickColor.new("Earth green"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Cylinder, collide=false, parent=waterDecor})
        pad.CFrame = CFrame.new(px, 0.7, pz) * CFrame.Angles(0, math.rad(R(-180,180)), math.rad(90))
    end

    local function Reed(px, pz)
        local h = 3.5 + R()*2.5
        local reed = P({name="Reed", size=Vector3.new(0.18, h, 0.18), pos=Vector3.new(px, h/2, pz),
            color=BrickColor.new("Dark green"), mat=Enum.Material.LeafyGrass, parent=waterDecor, collide=false})
        reed.CFrame = reed.CFrame * CFrame.Angles(0, math.rad(R(-180,180)), math.rad(R(-6,6)))
    end

    for _, pc in ipairs(ponds) do
        for i=1, R(5,9) do
            LilyPad(pc[1] + R(-10,10), pc[2] + R(-10,10))
        end
        for i=1, R(10,16) do
            local a = (i/16)*PI*2
            Reed(pc[1] + math.cos(a)*16 + R(-2,2), pc[2] + math.sin(a)*16 + R(-2,2))
        end
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
    for i=1,40 do
        local a=(i/40)*PI*2; local r=42+R(-2,2)
        Flower(math.cos(a)*r, math.sin(a)*r, hub)
    end

    -- Decorative rocks around the fountain
    for i=1,14 do
        local a=(i/14)*PI*2
        Rock(math.cos(a)*12 + R(-1,1), math.sin(a)*12 + R(-1,1), 0.35+R()*0.35, hub)
    end

    -- Small bushes around the tower base
    for i=1,18 do
        local a=(i/18)*PI*2
        Bush(math.cos(a)*16 + R(-2,2), math.sin(a)*16 + R(-2,2), 0.45+R()*0.35, hub)
    end

    -- Ring of trees around the hub perimeter (8 trees)
    for i=1,8 do
        local a=(i/8)*PI*2
        Tree(math.cos(a)*58, math.sin(a)*58, 0.8+R()*0.35, hub)
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

    -- Extra props
    local function FallenLog(x, z, len, folder)
        local log = P({name="FallenLog", size=Vector3.new(len, 1.3, 1.3), pos=Vector3.new(x, 0.85, z),
            color=BrickColor.new("Reddish brown"), mat=Enum.Material.Wood, shape=Enum.PartType.Cylinder, parent=folder})
        log.CFrame = CFrame.new(x, 0.85, z) * CFrame.Angles(0, math.rad(R(-180,180)), math.rad(90))
    end

    local function SmallRock(x, z, s, folder)
        s = s or 1
        local r = P({name="Rock", size=Vector3.new(2.2*s, 1.4*s, 2.2*s), pos=Vector3.new(x, 0.7*s, z),
            color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Slate, shape=Enum.PartType.Ball, parent=folder})
        r.CFrame = CFrame.new(x, 0.7*s, z) * CFrame.Angles(0, math.rad(R(-180,180)), math.rad(R(-8,8)))
    end

    local function MushroomCluster(x, z, folder)
        for i=1, R(3,6) do
            local mx = x + R(-10,10)*0.2
            local mz = z + R(-10,10)*0.2
            local h = 0.6 + R()*0.6
            P({name="MStem", size=Vector3.new(0.18, h, 0.18), pos=Vector3.new(mx, h/2, mz),
                color=BrickColor.new("Sand red"), mat=Enum.Material.SmoothPlastic, collide=false, parent=folder})
            local cap = P({name="MCap", size=Vector3.new(0.55, 0.25, 0.55), pos=Vector3.new(mx, h+0.15, mz),
                color=BrickColor.new("Bright red"), mat=Enum.Material.SmoothPlastic, shape=Enum.PartType.Ball, collide=false, parent=folder})
            cap.CFrame = cap.CFrame * CFrame.new(0, -0.05, 0)
            for s=1, R(2,4) do
                P({name="MSpot", size=Vector3.new(0.12,0.12,0.12), pos=Vector3.new(mx+R(-4,4)*0.07, h+0.25, mz+R(-4,4)*0.07),
                    color=BrickColor.new("Institutional white"), mat=Enum.Material.Neon, shape=Enum.PartType.Ball, collide=false, parent=folder})
            end
        end
    end

    local function NatureCluster(cx, cz, radius)
        for i=1, R(3,6) do
            Tree(cx+R(-radius,radius), cz+R(-radius,radius), 0.55+R()*0.65, nat)
        end
        for i=1, R(4,10) do
            Bush(cx+R(-radius,radius), cz+R(-radius,radius), 0.45+R()*0.7, nat)
        end
        for i=1, R(10,20) do
            Flower(cx+R(-radius,radius), cz+R(-radius,radius), nat)
        end
        if R() < 0.5 then FallenLog(cx+R(-radius,radius), cz+R(-radius,radius), R(7,14), nat) end
        for i=1, R(2,5) do SmallRock(cx+R(-radius,radius), cz+R(-radius,radius), 0.6+R()*0.6, nat) end
    end

    -- Corner groves (keep, but denser)
    for _, fc in ipairs({{-200,-200},{200,-200},{-200,200},{200,200}}) do
        for i=1,14 do Tree(fc[1]+R(-34,34),fc[2]+R(-34,34),0.65+R()*0.55,nat) end
        for i=1,18 do Bush(fc[1]+R(-40,40),fc[2]+R(-40,40),0.6+R()*0.55,nat) end
        for i=1,10 do SmallRock(fc[1]+R(-36,36),fc[2]+R(-36,36),0.5+R()*0.7,nat) end
        for i=1,20 do Flower(fc[1]+R(-42,42),fc[2]+R(-42,42),nat) end
        if R() < 0.8 then FallenLog(fc[1]+R(-22,22), fc[2]+R(-22,22), R(8,16), nat) end
    end

    task.wait()

    -- Nature clusters between walkways and plots (mid-fields)
    local clusterSpots = {
        {110, 110}, {110, -110}, {-110, 110}, {-110, -110},
        {150, 40}, {150, -40}, {-150, 40}, {-150, -40},
        {40, 150}, {-40, 150}, {40, -150}, {-40, -150},
    }
    for _, cs in ipairs(clusterSpots) do
        NatureCluster(cs[1], cs[2], 18)
    end

    task.wait()

    -- Meadows: dense flowers in center of each quadrant
    for _, m in ipairs({{-120,-120},{120,-120},{-120,120},{120,120}}) do
        for i=1,60 do
            local x = m[1] + R(-22,22)
            local z = m[2] + R(-22,22)
            if R() < 0.85 then Flower(x, z, nat) else Bush(x, z, 0.4+R()*0.4, nat) end
        end
        for i=1,8 do SmallRock(m[1]+R(-25,25), m[2]+R(-25,25), 0.45+R()*0.6, nat) end
    end

    task.wait()

    -- Global scatter counts
    for i=1,120 do
        local tx,tz = R(-240,240), R(-240,240)
        if math.abs(tx) > 55 or math.abs(tz) > 55 then
            Tree(tx, tz, 0.55+R()*0.75, nat)
            if R() < 0.35 then MushroomCluster(tx+R(-6,6), tz+R(-6,6), nat) end
        end
    end

    task.wait()

    for i=1,150 do
        local bx,bz = R(-240,240), R(-240,240)
        Bush(bx, bz, 0.45+R()*0.75, nat)
    end

    task.wait()

    for i=1,250 do
        local fx,fz = R(-240,240), R(-240,240)
        Flower(fx + R(-10,10)*0.1, fz + R(-10,10)*0.1, nat)
    end

    task.wait()

    for i=1,45 do
        SmallRock(R(-235,235), R(-235,235), 0.35+R()*0.95, nat)
    end

    for i=1,14 do
        FallenLog(R(-220,220), R(-220,220), R(8,16), nat)
    end
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
