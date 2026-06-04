--[[
    Baseplate.server.lua
    Creates the baseplate and spawn location for DataTycoon
]]

-- Create the baseplate
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = Vector3.new(512, 1, 512)
baseplate.Position = Vector3.new(0, -0.5, 0)
baseplate.Anchored = true
baseplate.BrickColor = BrickColor.new("Dark green")
baseplate.Material = Enum.Material.Grass
baseplate.Parent = workspace

-- Create a spawn location
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Parent = workspace

-- Set the workspace properties
workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500

print("DataTycoon: Baseplate and spawn created!")
