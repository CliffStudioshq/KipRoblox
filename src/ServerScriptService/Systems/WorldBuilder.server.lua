--[[
    WorldBuilder.server.lua — DataTycoon v0.30
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

print("[WORLD] WorldBuilder v0.30 starting...")
print("[PERF] Estimated part count reduction: 3581 -> 2029")

local Players = game:GetService("Players")
local PI = math.pi
local R  = math.random
local terrain = workspace:WaitForChild("Terrain")

-- Decorative optimization defaults (applied to foliage + similar)
local function markDecor(p, collide)
    if not p then return end
    p.CanQuery = false
    p.CanTouch = false
    if collide ~= nil then
        p.CanCollide = collide
    end
end

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

    -- Decorative parts should not participate in queries/touches.
    -- Keep collision behavior as configured by caller.
    if props.decor == true then
        p.CanQuery = false
        p.CanTouch = false
    end

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
-- v0.30: PLOT BUILDINGS / DECORATIONS / BUTTONS
-- ============================================================

local WORLD_COUNTS = {
    plots = 0,
    buildings = 0,
    decorations = 0,
}

local function setNoTouchQuery(part)
    if not part then return end
    part.CanQuery = false
    part.CanTouch = false
end

local function markModelParts(model, opts)
    -- opts:
    --   collide: bool? (default false)
    --   decor: bool? (default false)
    --   terminal: bool? (shop terminal, collide true)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            if opts and opts.terminal then
                d.CanCollide = true
            else
                d.CanCollide = (opts and opts.collide) or false
            end
            if opts and opts.decor then
                d.CanQuery = false
                d.CanTouch = false
            end
        end
    end
end

local function CreateUpgradeButton(position, label, color)
    local btn = P({
        name = "UpgradeButton",
        size = Vector3.new(8, 0.5, 8),
        pos = position,
        color = BrickColor.new(color or Color3.fromRGB(0, 170, 255)),
        mat = Enum.Material.SmoothPlastic,
        collide = true,
    })
    btn.CanTouch = true
    btn.CanQuery = true
    btn.TopSurface = Enum.SurfaceType.Smooth
    btn.BottomSurface = Enum.SurfaceType.Smooth

    local bbg = Instance.new("BillboardGui")
    bbg.Name = "UpgradeBillboard"
    bbg.Size = UDim2.new(0, 160, 0, 60)
    bbg.StudsOffset = Vector3.new(0, 3, 0)
    bbg.AlwaysOnTop = true
    bbg.LightInfluence = 0
    bbg.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label or "⬆️ Upgrade"
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextWrapped = true
    lbl.TextStrokeTransparency = 0.35
    lbl.Parent = bbg

    return btn
end

-- ----------------------------
-- Decorations (small)
-- ----------------------------
function BuildDecoration_FlowerGarden(position)
    local model = Instance.new("Model")
    model.Name = "Decor_FlowerGarden"

    local base = P({name="GardenBase", size=Vector3.new(7,0.3,7), pos=position + Vector3.new(0,0.15,0), color=BrickColor.new("Earth green"), mat=Enum.Material.Grass, collide=false, decor=true})
    base.Parent = model
    local pond = P({name="Pond", size=Vector3.new(3.2,0.35,3.2), pos=position + Vector3.new(0,0.22,0), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, alpha=0.45, collide=false, decor=true})
    pond.Shape = Enum.PartType.Cylinder
    pond.CFrame = CFrame.new(pond.Position) * CFrame.Angles(0,0,math.rad(90))
    pond.Parent = model
    for i=1,14 do
        local fx = position.X + R(-28,28)*0.1
        local fz = position.Z + R(-28,28)*0.1
        local stem = P({name="FStem", size=Vector3.new(0.15,0.8,0.15), pos=Vector3.new(fx, position.Y+0.4, fz), color=BrickColor.new("Bright green"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
        stem.Parent = model
        local pet = P({name="FPetal", size=Vector3.new(0.35,0.2,0.35), pos=Vector3.new(fx, position.Y+0.9, fz), color=BrickColor.new("Hot pink"), mat=Enum.Material.Neon, collide=false, decor=true})
        pet.Shape = Enum.PartType.Ball
        pet.Parent = model
    end

    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_Fountain(position)
    local model = Instance.new("Model")
    model.Name = "Decor_Fountain"
    local bowl = P({name="Bowl", size=Vector3.new(6,1.4,6), pos=position + Vector3.new(0,0.7,0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    bowl.Shape = Enum.PartType.Cylinder
    bowl.CFrame = CFrame.new(bowl.Position) * CFrame.Angles(0,0,math.rad(90))
    bowl.Parent = model
    local water = P({name="Water", size=Vector3.new(5.4,0.6,5.4), pos=position + Vector3.new(0,1.05,0), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, alpha=0.55, collide=false, decor=true})
    water.Shape = Enum.PartType.Cylinder
    water.CFrame = CFrame.new(water.Position) * CFrame.Angles(0,0,math.rad(90))
    water.Parent = model
    local pillar = P({name="Pillar", size=Vector3.new(1.2,2.8,1.2), pos=position + Vector3.new(0,2.1,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    pillar.Parent = model
    local top = P({name="Top", size=Vector3.new(2.2,0.6,2.2), pos=position + Vector3.new(0,3.7,0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    top.Shape = Enum.PartType.Cylinder
    top.CFrame = CFrame.new(top.Position) * CFrame.Angles(0,0,math.rad(90))
    top.Parent = model
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_NeonSign(position)
    local model = Instance.new("Model")
    model.Name = "Decor_NeonSign"
    local post = P({name="Post", size=Vector3.new(0.35,4.5,0.35), pos=position + Vector3.new(0,2.25,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    post.Parent = model
    local sign = P({name="Sign", size=Vector3.new(5.5,1.6,0.25), pos=position + Vector3.new(0,4.2,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
    sign.Parent = model
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = sign
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,1,0)
    t.BackgroundTransparency = 1
    t.Text = "DATA"
    t.TextColor3 = Color3.fromRGB(255,255,255)
    t.TextStrokeTransparency = 0.25
    t.Font = Enum.Font.GothamBold
    t.TextSize = 32
    t.Parent = gui
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_HologramTree(position)
    local model = Instance.new("Model")
    model.Name = "Decor_HologramTree"
    local trunk = P({name="Trunk", size=Vector3.new(0.7,3.6,0.7), pos=position + Vector3.new(0,1.8,0), color=BrickColor.new("Really black"), mat=Enum.Material.Metal, collide=false, decor=true})
    trunk.Parent = model
    for i=1,5 do
        local r = 2.2 - (i*0.25)
        local canopy = P({name="Canopy", size=Vector3.new(r*2,0.35,r*2), pos=position + Vector3.new(0,3.2 + i*0.45,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, alpha=0.55, collide=false, decor=true})
        canopy.Shape = Enum.PartType.Cylinder
        canopy.CFrame = CFrame.new(canopy.Position) * CFrame.Angles(0,0,math.rad(90))
        canopy.Parent = model
    end
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_DragonStatue(position)
    local model = Instance.new("Model")
    model.Name = "Decor_DragonStatue"
    local base = P({name="Base", size=Vector3.new(6,0.8,6), pos=position + Vector3.new(0,0.4,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    base.Parent = model
    local body = P({name="Body", size=Vector3.new(3.8,2,2), pos=position + Vector3.new(0,1.8,0), color=BrickColor.new("Black"), mat=Enum.Material.Metal, collide=false, decor=true})
    body.Shape = Enum.PartType.Block
    body.Parent = model
    local head = P({name="Head", size=Vector3.new(1.4,1.2,1.6), pos=position + Vector3.new(1.9,2.5,0), color=BrickColor.new("Really black"), mat=Enum.Material.Metal, collide=false, decor=true})
    head.Parent = model
    local eyeL = P({name="Eye", size=Vector3.new(0.2,0.2,0.2), pos=position + Vector3.new(2.55,2.65,0.35), color=BrickColor.new("Lime green"), mat=Enum.Material.Neon, collide=false, decor=true})
    eyeL.Shape = Enum.PartType.Ball
    eyeL.Parent = model
    local eyeR = P({name="Eye", size=Vector3.new(0.2,0.2,0.2), pos=position + Vector3.new(2.55,2.65,-0.35), color=BrickColor.new("Lime green"), mat=Enum.Material.Neon, collide=false, decor=true})
    eyeR.Shape = Enum.PartType.Ball
    eyeR.Parent = model
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_ParticleFountain(position)
    local model = Instance.new("Model")
    model.Name = "Decor_ParticleFountain"
    local base = P({name="Base", size=Vector3.new(5.5,0.6,5.5), pos=position + Vector3.new(0,0.3,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    base.Parent = model
    local nozzle = P({name="Nozzle", size=Vector3.new(0.6,0.8,0.6), pos=position + Vector3.new(0,0.9,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
    nozzle.Parent = model
    local att = Instance.new("Attachment")
    att.Parent = nozzle
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 25
    emitter.Lifetime = NumberRange.new(0.9,1.4)
    emitter.Speed = NumberRange.new(7,10)
    emitter.SpreadAngle = Vector2.new(8,8)
    emitter.Acceleration = Vector3.new(0,-20,0)
    emitter.Color = ColorSequence.new(Color3.fromRGB(0,200,255), Color3.fromRGB(180,240,255))
    emitter.LightEmission = 0.6
    emitter.Parent = att
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_MiningDrones(position)
    local model = Instance.new("Model")
    model.Name = "Decor_MiningDrones"
    for i=1,3 do
        local off = Vector3.new(R(-20,20)*0.1, 2.2 + i*0.4, R(-20,20)*0.1)
        local core = P({name="DroneCore", size=Vector3.new(0.9,0.9,0.9), pos=position + off, color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
        core.Shape = Enum.PartType.Ball
        core.Parent = model
        local glow = P({name="DroneGlow", size=Vector3.new(1.2,1.2,1.2), pos=position + off, color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, alpha=0.45, collide=false, decor=true})
        glow.Shape = Enum.PartType.Ball
        glow.Parent = model
    end
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildDecoration_SatelliteDish(position)
    local model = Instance.new("Model")
    model.Name = "Decor_SatelliteDish"
    local base = P({name="Base", size=Vector3.new(2.2,1.2,2.2), pos=position + Vector3.new(0,0.6,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    base.Parent = model
    local pole = P({name="Pole", size=Vector3.new(0.35,3.4,0.35), pos=position + Vector3.new(0,2.4,0), color=BrickColor.new("Black"), mat=Enum.Material.Metal, collide=false, decor=true})
    pole.Parent = model
    local dish = P({name="Dish", size=Vector3.new(4.8,0.4,4.8), pos=position + Vector3.new(0,4.3,0), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
    dish.Shape = Enum.PartType.Cylinder
    dish.CFrame = CFrame.new(dish.Position) * CFrame.Angles(math.rad(20),0,math.rad(90))
    dish.Parent = model
    local recv = P({name="Receiver", size=Vector3.new(0.4,0.4,0.4), pos=position + Vector3.new(1.2,4.1,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
    recv.Shape = Enum.PartType.Ball
    recv.Parent = model
    WORLD_COUNTS.decorations += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

-- ----------------------------
-- Plot buildings (tiered)
-- ----------------------------
function Build_Tier1_Empty(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier1"
    local post = P({name="UpgradePost", size=Vector3.new(0.4,3.5,0.4), pos=position + Vector3.new(0,1.75, -10), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    post.Parent = model
    local board = P({name="UpgradeBoard", size=Vector3.new(6,2,0.25), pos=position + Vector3.new(0,3.2,-10), color=BrickColor.new("Black"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
    board.Parent = model
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 180, 0, 60)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Parent = board
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Text = "⬆️ UPGRADE HERE"
    txt.TextColor3 = Color3.fromRGB(255,255,255)
    txt.TextStrokeTransparency = 0.25
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 18
    txt.Parent = bb
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier2_Outpost(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier2"
    local base = P({name="Shack", size=Vector3.new(10,6,10), pos=position + Vector3.new(0,3,0), color=BrickColor.new("Reddish brown"), mat=Enum.Material.Wood, collide=false, decor=true})
    base.Parent = model
    local roof = P({name="Roof", size=Vector3.new(12,1,12), pos=position + Vector3.new(0,6.5,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate, collide=false, decor=true})
    roof.Parent = model
    local door = P({name="Door", size=Vector3.new(2.5,4,0.2), pos=position + Vector3.new(0,2,5.1), color=BrickColor.new("Brown"), mat=Enum.Material.Wood, collide=false, decor=true})
    door.Parent = model
    local antenna = P({name="Antenna", size=Vector3.new(0.2,4.5,0.2), pos=position + Vector3.new(3,9,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    antenna.Parent = model
    local dish = P({name="Dish", size=Vector3.new(1.6,0.2,1.6), pos=position + Vector3.new(3,11.1,0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    dish.Shape = Enum.PartType.Cylinder
    dish.CFrame = CFrame.new(dish.Position) * CFrame.Angles(math.rad(25),0,math.rad(90))
    dish.Parent = model
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier3_ServerRoom(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier3"
    local shell = P({name="Shell", size=Vector3.new(15,9,15), pos=position + Vector3.new(0,4.5,0), color=BrickColor.new("Medium stone grey"), mat=Enum.Material.Concrete, collide=false, decor=true})
    shell.Parent = model
    local roof = P({name="Roof", size=Vector3.new(16,1,16), pos=position + Vector3.new(0,9.5,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    roof.Parent = model
    for i=-1,1,2 do
        local win = P({name="Window", size=Vector3.new(4,3,0.25), pos=position + Vector3.new(i*4,5,7.65), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, alpha=0.45, collide=false, decor=true})
        win.Parent = model
    end
    for i=1,4 do
        local rack = P({name="Rack", size=Vector3.new(2,5.5,1.2), pos=position + Vector3.new(-5 + (i-1)*3.4,3, -2), color=BrickColor.new("Really black"), mat=Enum.Material.Metal, collide=false, decor=true})
        rack.Parent = model
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0,170,255)
        light.Brightness = 1.2
        light.Range = 10
        light.Parent = rack
    end
    local strip = P({name="BlueStrip", size=Vector3.new(15.6,0.25,0.35), pos=position + Vector3.new(0,8.2,7.7), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
    strip.Parent = model
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier4_DataCenter(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier4"
    local core = P({name="Core", size=Vector3.new(20,12,20), pos=position + Vector3.new(0,6,0), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
    core.Parent = model
    local glass = P({name="GlassBand", size=Vector3.new(20.4,3.2,0.3), pos=position + Vector3.new(0,6,10.15), color=BrickColor.new("Bright blue"), mat=Enum.Material.Glass, alpha=0.5, collide=false, decor=true})
    glass.Parent = model
    local rim = P({name="Rim", size=Vector3.new(21,0.4,21), pos=position + Vector3.new(0,12.4,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
    rim.Parent = model
    for i=1,3 do
        local tpos = position + Vector3.new(-6 + (i-1)*6, 7, -7)
        local tower = P({name="ServerTower", size=Vector3.new(3,10,3), pos=tpos, color=BrickColor.new("Really black"), mat=Enum.Material.Metal, collide=false, decor=true})
        tower.Parent = model
        local glow = P({name="TowerGlow", size=Vector3.new(3.2,0.25,3.2), pos=tpos + Vector3.new(0,4,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, collide=false, decor=true})
        glow.Parent = model
        local l = Instance.new("PointLight")
        l.Color = Color3.fromRGB(0,220,255)
        l.Brightness = 1.6
        l.Range = 14
        l.Parent = glow
    end
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier5_TechCampus(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier5"
    for i=1,3 do
        local ox = (i==2) and 10 or ((i==3) and -10 or 0)
        local oz = (i==1) and -8 or 8
        local b = P({name="CampusBldg", size=Vector3.new(10,9,8), pos=position + Vector3.new(ox,4.5,oz), color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
        b.Parent = model
        local cap = P({name="Cap", size=Vector3.new(10.4,0.35,8.4), pos=position + Vector3.new(ox,9.2,oz), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, alpha=0.15, collide=false, decor=true})
        cap.Parent = model
    end
    local walk = P({name="SkyWalk", size=Vector3.new(22,0.35,3), pos=position + Vector3.new(0,5.5,0), color=BrickColor.new("Light stone grey"), mat=Enum.Material.Metal, collide=false, decor=true})
    walk.Parent = model
    local holo = P({name="HoloPanel", size=Vector3.new(4,2.5,0.2), pos=position + Vector3.new(0,4.2,-4), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, alpha=0.35, collide=false, decor=true})
    holo.Parent = model
    local pl = Instance.new("PointLight")
    pl.Color = Color3.fromRGB(0,240,255)
    pl.Range = 18
    pl.Brightness = 1.8
    pl.Parent = holo
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier6_QuantumLabs(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier6"
    local dome = P({name="Dome", size=Vector3.new(22,11,22), pos=position + Vector3.new(0,5.5,0), color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Glass, alpha=0.35, collide=false, decor=true})
    dome.Shape = Enum.PartType.Ball
    dome.Parent = model
    local tower = P({name="Tower", size=Vector3.new(7,18,7), pos=position + Vector3.new(12,9,0), color=BrickColor.new("Really black"), mat=Enum.Material.Metal, collide=false, decor=true})
    tower.Parent = model
    local core = P({name="EnergyCore", size=Vector3.new(3.5,3.5,3.5), pos=position + Vector3.new(0,6.2,0), color=BrickColor.new("Bright violet"), mat=Enum.Material.Neon, alpha=0.15, collide=false, decor=true})
    core.Shape = Enum.PartType.Ball
    core.Parent = model
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(180, 80, 255)
    light.Range = 26
    light.Brightness = 2.2
    light.Parent = core
    for i=1,3 do
        local ring = P({name="Ring", size=Vector3.new(10 + i*2,0.3,10 + i*2), pos=position + Vector3.new(12,8 + i*2.2,0), color=BrickColor.new("Bright blue"), mat=Enum.Material.Neon, alpha=0.25, collide=false, decor=true})
        ring.Shape = Enum.PartType.Cylinder
        ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, math.rad(20*i), math.rad(90))
        ring.Parent = model
    end
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier7_NeuralNexus(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier7"
    local mass = P({name="Mass", size=Vector3.new(30,18,30), pos=position + Vector3.new(0,9,0), color=BrickColor.new("Really black"), mat=Enum.Material.SmoothPlastic, collide=false, decor=true})
    mass.Shape = Enum.PartType.Ball
    mass.Parent = model
    for i=1,18 do
        local a = (i/18)*PI*2
        local r = 12 + (i%3)*2
        local nodePos = position + Vector3.new(math.cos(a)*r, 8 + math.sin(a*2)*2, math.sin(a)*r)
        local node = P({name="Node", size=Vector3.new(1.1,1.1,1.1), pos=nodePos, color=BrickColor.new("Lime green"), mat=Enum.Material.Neon, collide=false, decor=true})
        node.Shape = Enum.PartType.Ball
        node.Parent = model
        local beam = Instance.new("Beam")
        local a0 = Instance.new("Attachment"); a0.Parent = node
        local a1 = Instance.new("Attachment"); a1.Parent = mass
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.08
        beam.Width1 = 0.02
        beam.Color = ColorSequence.new(Color3.fromRGB(100,255,120))
        beam.LightEmission = 0.8
        beam.Parent = node
    end
    local pulse = Instance.new("ParticleEmitter")
    local att = Instance.new("Attachment")
    att.Parent = mass
    pulse.Rate = 10
    pulse.Lifetime = NumberRange.new(1.0,1.8)
    pulse.Speed = NumberRange.new(1,2)
    pulse.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.6), NumberSequenceKeypoint.new(1,0)})
    pulse.Color = ColorSequence.new(Color3.fromRGB(0,255,120))
    pulse.LightEmission = 0.7
    pulse.Parent = att
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function Build_Tier8_SingularityCore(position)
    local model = Instance.new("Model")
    model.Name = "Building_Tier8"
    local frame = P({name="Frame", size=Vector3.new(38,22,38), pos=position + Vector3.new(0,11,0), color=BrickColor.new("Black"), mat=Enum.Material.Metal, collide=false, decor=true})
    frame.Parent = model
    local ring1 = P({name="Halo", size=Vector3.new(34,0.6,34), pos=position + Vector3.new(0,12,0), color=BrickColor.new("New Yeller"), mat=Enum.Material.Neon, alpha=0.15, collide=false, decor=true})
    ring1.Shape = Enum.PartType.Cylinder
    ring1.CFrame = CFrame.new(ring1.Position) * CFrame.Angles(0,0,math.rad(90))
    ring1.Parent = model
    local ring2 = P({name="Halo2", size=Vector3.new(28,0.5,28), pos=position + Vector3.new(0,12,0), color=BrickColor.new("Cyan"), mat=Enum.Material.Neon, alpha=0.25, collide=false, decor=true})
    ring2.Shape = Enum.PartType.Cylinder
    ring2.CFrame = CFrame.new(ring2.Position) * CFrame.Angles(math.rad(35),0,math.rad(90))
    ring2.Parent = model
    local void = P({name="BlackHole", size=Vector3.new(10,10,10), pos=position + Vector3.new(0,12,0), color=BrickColor.new("Really black"), mat=Enum.Material.Neon, collide=false, decor=true})
    void.Shape = Enum.PartType.Ball
    void.Parent = model
    local vl = Instance.new("PointLight")
    vl.Color = Color3.fromRGB(0, 220, 255)
    vl.Brightness = 2.8
    vl.Range = 40
    vl.Parent = void
    local warpAtt = Instance.new("Attachment")
    warpAtt.Parent = void
    local warp = Instance.new("ParticleEmitter")
    warp.Rate = 35
    warp.Lifetime = NumberRange.new(1.2,2.0)
    warp.Speed = NumberRange.new(8,14)
    warp.SpreadAngle = Vector2.new(180,180)
    warp.Acceleration = Vector3.new(0, 10, 0)
    warp.Color = ColorSequence.new(Color3.fromRGB(0,200,255), Color3.fromRGB(255,200,0))
    warp.LightEmission = 0.9
    warp.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.4), NumberSequenceKeypoint.new(1,0)})
    warp.Parent = warpAtt
    WORLD_COUNTS.buildings += 1
    markModelParts(model, {decor=true, collide=false})
    return model
end

function BuildShopTerminal(position)
    local model = Instance.new("Model")
    model.Name = "ShopTerminal"

    local ped = P({name="Pedestal", size=Vector3.new(4, 3, 4), pos=position + Vector3.new(0,1.5,0), color=BrickColor.new("Really black"), mat=Enum.Material.SmoothPlastic, collide=true})
    ped.Parent = model

    local holo = P({
        name="Holo",
        size = Vector3.new(3, 4, 0.2),
        pos = position + Vector3.new(0, 3.5, 0),
        color = BrickColor.new(Color3.fromRGB(0, 200, 255)),
        mat = Enum.Material.Neon,
        alpha = 0.3,
        collide = false,
    })
    holo.Parent = model

    local sign = P({
        name="SHOP",
        size = Vector3.new(6, 1, 0.3),
        pos = position + Vector3.new(0, 6, 0),
        color = BrickColor.new(Color3.fromRGB(255, 200, 0)),
        mat = Enum.Material.Neon,
        collide = false,
    })
    sign.Parent = model

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 200, 255)
    light.Brightness = 2
    light.Range = 20
    light.Parent = holo

    markModelParts(model, {terminal=true})
    return model
end

-- ============================================================
-- BRIDGES (server-built, per plot)
-- ============================================================
local Bridges = {} -- plotId -> Model

local function findPlotPart(plotId)
    local pf = workspace:FindFirstChild("PlotMarkers")
    if not pf then return nil end

    local x, z = plotId:match("[Pp]lot_(-?%d+)_(-?%d+)")
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

function BuildBridge(plotId, tier, ownerName, ownerUserId)
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

    tier = tonumber(tier) or 1
    local walkwayMat, walkwayCol = Enum.Material.WoodPlanks, BrickColor.new("Reddish brown")
    local railMat, railCol = Enum.Material.Wood, BrickColor.new("Reddish brown")
    local glow = false
    if tier >= 3 and tier <= 4 then
        walkwayMat, walkwayCol = Enum.Material.DiamondPlate, BrickColor.new("Dark stone grey")
        railMat, railCol = Enum.Material.Metal, BrickColor.new("Black")
    elseif tier >= 5 and tier <= 6 then
        walkwayMat, walkwayCol = Enum.Material.Metal, BrickColor.new("Medium stone grey")
        railMat, railCol = Enum.Material.Metal, BrickColor.new("Really black")
        glow = true
    elseif tier >= 7 then
        walkwayMat, walkwayCol = Enum.Material.Neon, BrickColor.new("Cyan")
        railMat, railCol = Enum.Material.Neon, BrickColor.new("Lime green")
        glow = true
    end

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
            local w = makePart(partsFolder, "Walkway", Vector3.new(walkwayWidth, walkwayThick, len + 0.05), cf, walkwayMat, walkwayCol)
            w.CanCollide = true
            if glow and walkwayMat ~= Enum.Material.Neon then
                local strip = makePart(partsFolder, "GlowStrip", Vector3.new(walkwayWidth-1.2, 0.08, len + 0.05), cf * CFrame.new(0, (walkwayThick/2)+0.08, 0), Enum.Material.Neon, Color3.fromRGB(0,200,255), 0.15)
                strip.CanCollide = false
            end
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
            local post = makePart(railFolder, "Post", Vector3.new(0.4, 3, 0.4), cf, railMat, railCol)
            post.CanCollide = false
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
                local beam = makePart(railFolder, "Beam", Vector3.new(0.35, 0.25, len + 0.05), cf, railMat, railCol)
                beam.CanCollide = false
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
    s = s or 1
    local t = R(1, 3)  -- only 3 archetypes, each 2 parts

    local trunkCol = BrickColor.new("Reddish brown")
    local function canopy(pos, size, col)
        local c = P({name="Canopy", size=size, pos=pos, color=col,
            mat=Enum.Material.LeafyGrass, shape=Enum.PartType.Ball,
            collide=false, decor=true, parent=folder})
        return c
    end

    if t == 1 then
        -- Oak: trunk + single wide canopy (2 parts)
        local h = (8 + R(-1, 2)) * s
        P({name="Trunk", size=Vector3.new(1.8*s, h, 1.8*s),
            pos=Vector3.new(x, h/2, z), color=trunkCol, mat=Enum.Material.Wood, parent=folder})
        canopy(Vector3.new(x, h + 3*s, z),
            Vector3.new(12*s, 8*s, 12*s),
            BrickColor.new("Forest green"))

    elseif t == 2 then
        -- Pine: trunk + conical canopy (2 parts)
        local h = (12 + R(-1, 3)) * s
        P({name="Trunk", size=Vector3.new(1.4*s, h, 1.4*s),
            pos=Vector3.new(x, h/2, z), color=BrickColor.new("Brown"), mat=Enum.Material.Wood, parent=folder})
        canopy(Vector3.new(x, h + 2*s, z),
            Vector3.new(8*s, 10*s, 8*s),
            BrickColor.new("Dark green"))

    else
        -- Birch: trunk + light canopy (2 parts)
        local h = (10 + R(-1, 2)) * s
        P({name="Trunk", size=Vector3.new(1.2*s, h, 1.2*s),
            pos=Vector3.new(x, h/2, z), color=BrickColor.new("Institutional white"), mat=Enum.Material.Wood, parent=folder})
        canopy(Vector3.new(x, h + 2.5*s, z),
            Vector3.new(7*s, 5*s, 7*s),
            BrickColor.new("Lime green"))
    end
end

local function Bush(x, z, s, folder)
    s = s or 1
    P({name="Bush", size=Vector3.new(4.2*s,3.2*s,4.2*s),
        pos=Vector3.new(x, 1.55*s, z),
        color=BrickColor.new("Dark green"), mat=Enum.Material.LeafyGrass,
        shape=Enum.PartType.Ball, collide=false, decor=true, parent=folder})
end

local function Flower(x, z, folder)
    -- Single-part flower accent
    local col = ({
        BrickColor.new("Bright red"),
        BrickColor.new("New Yeller"),
        BrickColor.new("Hot pink"),
        BrickColor.new("Bright violet"),
        BrickColor.new("Cyan"),
    })[R(1,5)]
    P({name="Flower", size=Vector3.new(0.7, 0.7, 0.7), pos=Vector3.new(x, 0.45, z),
        color=col, mat=Enum.Material.LeafyGrass, shape=Enum.PartType.Ball,
        collide=false, decor=true, parent=folder})
end

local function Rock(x, z, s, folder)
    s = s or 1
    local r = P({name="Rock", size=Vector3.new(3*s,2*s,3*s), pos=Vector3.new(x,s,z),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Slate,
       shape=Enum.PartType.Ball, parent=folder})
    markDecor(r, true)
end

local function Lamp(x, z, folder)
    local pole = P({name="LPole", size=Vector3.new(0.4,8,0.4),   pos=Vector3.new(x,4,z),
       color=BrickColor.new("Dark stone grey"), mat=Enum.Material.Metal, parent=folder})
    local head = P({name="LHead", size=Vector3.new(1.4,0.5,1.4), pos=Vector3.new(x,8.2,z),
       color=BrickColor.new("Institutional white"), mat=Enum.Material.SmoothPlastic, parent=folder})
    markDecor(pole, true)
    markDecor(head, true)
end

local function Orb(cx, cy, cz, brickCol, folder)
    local ring = P({name="OrbRing", size=Vector3.new(9,3,9),
        pos=Vector3.new(cx,1.5,cz), color=brickCol,
        mat=Enum.Material.SmoothPlastic,
        shape=Enum.PartType.Cylinder, collide=true, parent=folder})
    ring.CFrame = CFrame.new(cx,1.5,cz) * CFrame.Angles(0,0,math.rad(90))
    markDecor(ring, true)
    P({name="OrbSphere", size=Vector3.new(3,3,3), pos=Vector3.new(cx,cy,cz),
       color=brickCol, mat=Enum.Material.Neon,
       shape=Enum.PartType.Ball, collide=false, decor=true, parent=folder})
    P({name="OrbCore", size=Vector3.new(1.2,1.2,1.2), pos=Vector3.new(cx,cy,cz),
       color=BrickColor.new("Institutional white"), mat=Enum.Material.Neon,
       shape=Enum.PartType.Ball, collide=false, decor=true, parent=folder})
    local anchor = P({name="OrbBB", size=Vector3.new(0.1,0.1,0.1),
        pos=Vector3.new(cx,cy+3,cz), alpha=1, collide=false, decor=true, parent=folder})
    local bb=Instance.new("BillboardGui"); bb.Size=UDim2.new(0,120,0,30)
    bb.StudsOffset=Vector3.new(0,4,0); bb.AlwaysOnTop=true; bb.Parent=anchor
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text="✦ +5 Data"
    lbl.TextColor3=brickCol.Color; lbl.TextSize=14; lbl.Font=Enum.Font.GothamBold
    lbl.TextStrokeTransparency=0.15; lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.Parent=bb

    return ring
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
        local hh = R(4, 12)  -- hill height (gentler rolling hills)
        terrain:FillBall(Vector3.new(hx, hh/2, hz), hr, Enum.Material.Grass)
    end
    task.wait()

    -- Gentle rolling hills around the perimeter (no boulder mountains)
    for i = 1, 8 do
        local a = (i/16)*PI*2 + 0.2
        local r = 185 + R(-15, 15)
        local mx, mz = math.cos(a)*r, math.sin(a)*r
        terrain:FillBall(Vector3.new(mx, R(5, 14), mz), R(12, 22), Enum.Material.Grass)
    end

    -- Enable built-in terrain grass decoration (animated blades)
    terrain.Decoration = true
    terrain.GrassLength = 0.18  -- short, neat, natural

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

    -- Shop terminal near the fountain
    local term = BuildShopTerminal(Vector3.new(0, 3.1, -12))
    term.Parent = hub

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

    -- Ring of trees around the hub perimeter (6 trees, evenly spaced)
    for i = 1, 6 do
        local a = (i/6) * PI * 2
        Tree(math.cos(a) * 65, math.sin(a) * 65, 0.7 + R()*0.25, hub)
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

        for dist = 80, 240, 40 do  -- fewer, more spaced out
            local tx, tz = dx*dist, dz*dist
            local s = 0.5 + R()*0.2
            if dx == 0 then Tree(tx+15, tz, s, walk); Tree(tx-15, tz, s, walk)
            else Tree(tx, tz+15, s, walk); Tree(tx, tz-15, s, walk) end
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
    local MAX_PLOTS = 8
    local PLOT_RADIUS = 280  -- studs from center, outside walkways (walkways end at ~260)

    local function buildPlotAt(cx, cz)
        local plotPos = Vector3.new(cx, 0.5, cz)

        local plot = P({name=string.format("Plot_%d_%d", math.floor(cx+0.5), math.floor(cz+0.5)), size=Vector3.new(116,0.6,116), pos=Vector3.new(cx,0.3,cz),
           color=BrickColor.new("Dark green"), mat=Enum.Material.SmoothPlastic, parent=pf})
        plot.CanCollide = true
        WORLD_COUNTS.plots += 1

        -- borders/posts keep collision off
        local bdrCol = BrickColor.new("Dark stone grey")
        local bdrMat = Enum.Material.Concrete
        for _, b in ipairs({
            {"BdrN", Vector3.new(116,2,0.8), Vector3.new(cx,1.6,cz+58)},
            {"BdrS", Vector3.new(116,2,0.8), Vector3.new(cx,1.6,cz-58)},
            {"BdrE", Vector3.new(0.8,2,116), Vector3.new(cx+58,1.6,cz)},
            {"BdrW", Vector3.new(0.8,2,116), Vector3.new(cx-58,1.6,cz)},
        }) do
            local p = P({name=b[1], size=b[2], pos=b[3], color=bdrCol, mat=bdrMat, parent=pf, collide=false})
            setNoTouchQuery(p)
        end
        for _, c in ipairs({{57,57},{-57,57},{57,-57},{-57,-57}}) do
            local post = P({name="Post",size=Vector3.new(1.5,6,1.5),pos=Vector3.new(cx+c[1],3,cz+c[2]),color=BrickColor.new("Medium stone grey"),mat=Enum.Material.SmoothPlastic,parent=pf, collide=false, decor=true})
            setNoTouchQuery(post)
        end

        -- Tier-1 marker building (upgrade here sign) but keep collisions off
        local tier1 = Build_Tier1_Empty(plotPos)
        tier1.Parent = pf

        -- Upgrade buttons
        local b1 = CreateUpgradeButton(plotPos + Vector3.new(0, 0.35, 0),
            "⬆️ Upgrade Building\nWalk here to upgrade", Color3.fromRGB(0,170,255))
        b1.Name = "Btn_UpgradeBuilding"
        b1.Parent = pf
        local b2 = CreateUpgradeButton(plotPos + Vector3.new(36, 0.35, 36),
            "✨ Add Decoration\nWalk here to decorate", Color3.fromRGB(255, 200, 0))
        b2.Name = "Btn_UpgradeDecor"
        b2.Parent = pf

        -- ensure building/marker parts are non-colliding and non touch/query
        markModelParts(tier1, {decor=true, collide=false})

        return plot
    end

    for i = 1, MAX_PLOTS do
        local angle = ((i-1) / MAX_PLOTS) * math.pi * 2
        local px = math.cos(angle) * PLOT_RADIUS
        local pz = math.sin(angle) * PLOT_RADIUS
        buildPlotAt(px, pz)
        if i % 4 == 0 then task.wait() end
    end

    -- Build bridges from hub to each plot
    local hubPlatform = getHubPlatform()
    if not hubPlatform then
        -- Fallback: search workspace for hub part
        local dataHub = workspace:FindFirstChild("DataHub")
        if dataHub then hubPlatform = dataHub:FindFirstChild("HubPlatform") end
    end
    if not hubPlatform then
        -- Last resort: search all workspace children
        for _, p in ipairs(workspace:GetDescendants()) do
            if p.Name == "HubPlatform" then hubPlatform = p; break end
        end
    end

    if hubPlatform and typeof(BuildBridge) == "function" then
        for _, plot in ipairs(pf:GetChildren()) do
            if plot:IsA("BasePart") and plot.Name:match("^Plot_") then
                local success, err = pcall(function()
                    BuildBridge(plot.Name, 1, "Server", 0)
                end)
                if not success then
                    warn("[WORLD] Bridge build failed for " .. plot.Name .. ": " .. tostring(err))
                end
            end
        end
        print("[WORLD] Built bridges to " .. WORLD_COUNTS.plots .. " plots")
    else
        warn("[WORLD] Could not find hub platform for bridge building")
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
    local orbIndex = 0
    for ri, ring in ipairs(rings) do
        for i=1,ring.count do
            local a=(i/ring.count)*PI*2+(ri*0.2)
            orbIndex = orbIndex + 1
            local createdRing = Orb(math.cos(a)*ring.radius, ring.y, math.sin(a)*ring.radius, ring.col, orbs)
            if createdRing and createdRing:IsA("BasePart") then
                createdRing.Name = "OrbRing_" .. orbIndex
                createdRing:SetAttribute("OrbId", orbIndex)
            end
        end
        task.wait()
    end
end)

-- ============================================================
-- SECTION: NATURE
-- ============================================================
section("Nature", function()
    local nature = Instance.new("Folder")
    nature.Name = "Nature"
    nature.Parent = workspace

    -- Four sparse clusters around the map perimeter
    local clusterCenters = {
        {R(180, 240), R(180, 240)},
        {R(-240, -180), R(180, 240)},
        {R(-240, -180), R(-240, -180)},
        {R(180, 240), R(-240, -180)},
    }

    for _, center in ipairs(clusterCenters) do
        local cx, cz = center[1], center[2]
        -- 3-5 trees per cluster
        for i = 1, 3 + R(0, 2) do
            local tx = cx + R(-25, 25)
            local tz = cz + R(-25, 25)
            Tree(tx, tz, 0.7 + R()*0.4, nature)
        end
        -- 2-3 bushes per cluster
        for i = 1, 2 + R(0, 1) do
            Bush(cx + R(-15, 15), cz + R(-15, 15), 0.5 + R()*0.3, nature)
        end
        task.wait()
    end

    -- 4 rock accent pieces near the hub
    for i = 1, 4 do
        local a = (i/4) * math.pi * 2 + R(-0.3, 0.3)
        Rock(math.cos(a) * 75, math.sin(a) * 75, 0.4 + R()*0.3, nature)
    end

    -- Small flower patches near walkway entrances (3 patches)
    for i = 1, 3 do
        local a = (i/3) * math.pi * 2
        local fx = math.cos(a) * 100
        local fz = math.sin(a) * 100
        for j = 1, 3 do
            Flower(fx + R(-5, 5), fz + R(-5, 5), nature)
        end
    end

    print("[WORLD] Nature done — sparse clusters, clean look")
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

print(string.format("[WORLD] Built: %d plots, %d buildings, %d decorations", WORLD_COUNTS.plots, WORLD_COUNTS.buildings, WORLD_COUNTS.decorations))
print("[WORLD] Map: 8 perimeter plots, 6 hub trees, 4 nature clusters, sparse flora")
print("[WORLD] ✅ World build complete!")
