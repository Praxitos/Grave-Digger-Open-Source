--!strict
--!native
--!optimize 2
local terrain_service = workspace.Terrain
local TerrainChunkClass = {}
TerrainChunkClass.__index = TerrainChunkClass

export type TerrainChunkClass = typeof(setmetatable({} :: {
	className: string,
	edits: {string},
	entities: {any},
	reference_part: Part,
	loaded: boolean,
}, TerrainChunkClass))

function TerrainChunkClass.new(info)
	local self = setmetatable({}, TerrainChunkClass)
	self.className = "TerrainChunkClass"
	self.name      = info.name
	self.edits     = info.edits    or {}
	self.entities  = info.entities or {}
	return self
end

function TerrainChunkClass:Load()
	terrain_service:FillBlock(self.reference_part.CFrame, self.reference_part.Size, Enum.Material.Rock)
	for _, edit in ipairs(self.edits) do
		local v    = edit:split(",")
		local x    = tonumber(v[1])
		local y    = tonumber(v[2])
		local z    = tonumber(v[3])
		local sx   = tonumber(v[4])
		local sy   = tonumber(v[5])
		local sz   = tonumber(v[6])
		local mat  = Enum.Material[v[7]]
		local shape = v[8]
		if not (x and y and z and sx and mat) then continue end
		if shape == "ball" then
			terrain_service:FillBall(Vector3.new(x, y, z), sx, mat)
		else
			if not (sy and sz) then continue end
			terrain_service:FillBlock(CFrame.new(x, y, z), Vector3.new(sx, sy, sz), mat)
		end
	end
	self.loaded = true
end

function TerrainChunkClass:Unload()
	terrain_service:FillBlock(self.reference_part.CFrame, self.reference_part.Size, Enum.Material.Air)
	self.loaded = false
end

return TerrainChunkClass