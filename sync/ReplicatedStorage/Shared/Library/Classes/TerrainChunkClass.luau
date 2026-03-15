-- This file is a part of the ... library. ... is licensed under the terms of the MIT License. For more information, see LICENSE.md
--!strict
--!native
--!optimize 2
local terrain_service = game:GetService("Workspace").Terrain
-- Class Definition
--[=[
	@class TerrainChunkClass
	The TerrainChunkClass class is Used for defining terrain Classes
]=]
local TerrainChunkClass = {};
TerrainChunkClass.__index = TerrainChunkClass;
-- Type Definition
export type TerrainChunkClass = typeof(setmetatable({} :: {
	className : "TerrainChunkClass";
	edits: {
		Position: Vector3; -- // Stores edits done within the chunk, this is used for saving and loading
	},
	entities: {
		instance: Instance;
	},
	reference_part: Part;
	loaded: boolean;

}, {} :: typeof(TerrainChunkClass)))
--[=[
	@within TerrainChunkClass
	The TerrainChunkClass class is Used for defining terrain Classes
	@param TerrainChunkClassCreateInfo heraTypes.TerrainChunkClassCreateInfo
	@return TerrainChunkClass
]=]
function TerrainChunkClass.new(TerrainChunkClassCreateInfo : TerrainChunkClass) : TerrainChunkClass
	local class = setmetatable({}, TerrainChunkClass);
	class.className = "TerrainChunkClass";
	class.name = TerrainChunkClassCreateInfo.name;
	class.edits = TerrainChunkClassCreateInfo.edits or {}
	class.entities = TerrainChunkClassCreateInfo.entities or {}
	return class;
end
--[=[
	@within TerrainChunkClass
]=]
function TerrainChunkClass:Load()
	terrain_service:FillBlock(
		self.reference_part.CFrame,
		self.reference_part.Size,
		Enum.Material.Rock
	)
	-- Parse each edit string "x,y,z" and carve a ball hole
	for _, edit in pairs(self.edits) do
		local values = edit:split(",")
		local x, y, z = tonumber(values[1]), tonumber(values[2]), tonumber(values[3])
		if x and y and z then
			terrain_service:FillBall(
				Vector3.new(x, y, z),
				4,
				Enum.Material.Air
			)
		else
			warn("TerrainChunkClass:Load() - Failed to parse edit string:", edit)
		end
	end
	self.loaded = true
end
function TerrainChunkClass:Unload()
	terrain_service:FillBlock(
		self.reference_part.CFrame,
		self.reference_part.Size,
		Enum.Material.Air
	)
	self.loaded = false
end
-- // Restarts from the beginning chunk
function TerrainChunkClass:Redo()
	self:Unload()
	for _, child in pairs(self.entities) do
		if child.instance and child.instance.Parent then
			child.instance:Destroy()
		end
	end
	self.edits = {}
	self.entities = {}
end
-- // Cleans up the chunk, this is used for when the chunk is no longer needed and can be removed from memory
function TerrainChunkClass:CleanUp()
	self:Unload()
	for _, child in pairs(self.entities) do
		if child.instance and child.instance.Parent then
			child.instance:Destroy()
		end
	end
	self.edits = {}
	self.entities = {}
end
return TerrainChunkClass;