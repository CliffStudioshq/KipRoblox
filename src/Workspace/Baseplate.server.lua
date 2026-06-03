--[[
    Baseplate.server.lua
    Creates a baseplate in the Workspace so players don't fall to their death
]]

local Workspace = game:GetService("Workspace")

-- Check if a baseplate already exists
if not Workspace:FindFirstChild("Baseplate") then
    local baseplate = Instance.new("Part")
    baseplate.Name = "Baseplate"
    baseplate.Size = Vector3.new(512, 1, 512)
    baseplate.Position = Vector3.new(0, -0.5, 0)
    baseplate.Anchored = true
    baseplate.BrickColor = BrickColor.new("Dark green")
    baseplate.Material = Enum.Material.Grass
    baseplate.Parent = Workspace
    
    -- Set spawn location
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "SpawnLocation"
    spawn.Size = Vector3.new(6, 1, 6)
    spawn.Position = Vector3.new(0, 0.5, 0)
    spawn.Anchored = true
    spawn.CanCollide = false
    spawn.Transparency = 1
    spawn.Parent = Workspace
    
    print("DataTycoon: Baseplate created!")
end
